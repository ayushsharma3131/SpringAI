terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.30"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# -----------------------------------------------------------------------------
# 1. Enable Required GCP APIs
# -----------------------------------------------------------------------------
resource "google_project_service" "compute_api" {
  project                    = var.project_id
  service                    = "compute.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false
}

# -----------------------------------------------------------------------------
# 2. VPC Network & Subnet
# -----------------------------------------------------------------------------
resource "google_compute_network" "vpc" {
  name                    = "${var.app_name}-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.compute_api]
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.app_name}-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# -----------------------------------------------------------------------------
# 3. Firewall Rules
# -----------------------------------------------------------------------------
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.app_name}-allow-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["spring-ai-vm"]
}

resource "google_compute_firewall" "allow_http" {
  name    = "${var.app_name}-allow-http"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = [tostring(var.app_port), "80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["spring-ai-vm"]
}

# -----------------------------------------------------------------------------
# 4. Static External IP & Persistent Disk for PostgreSQL
# -----------------------------------------------------------------------------
resource "google_compute_address" "static_ip" {
  name       = "${var.app_name}-static-ip"
  region     = var.region
  depends_on = [google_project_service.compute_api]
}

resource "random_password" "db_password" {
  length  = 24
  special = false
}

locals {
  effective_db_password = var.db_password != "" ? var.db_password : random_password.db_password.result
}

resource "google_compute_disk" "postgres_data" {
  name       = "${var.app_name}-pgdata"
  type       = "pd-balanced"
  zone       = var.zone
  size       = var.postgres_disk_size_gb
  depends_on = [google_project_service.compute_api]
}

# -----------------------------------------------------------------------------
# 5. Service Account for VM
# -----------------------------------------------------------------------------
resource "google_service_account" "vm_sa" {
  account_id   = "${var.app_name}-vm-sa"
  display_name = "Service Account for Spring AI VM"
}

# -----------------------------------------------------------------------------
# 6. GCE Virtual Machine Instance
# -----------------------------------------------------------------------------
resource "google_compute_instance" "vm" {
  name         = "${var.app_name}-vm"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["spring-ai-vm"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 30
      type  = "pd-balanced"
    }
  }

  attached_disk {
    source      = google_compute_disk.postgres_data.id
    device_name = "postgres-data"
    mode        = "READ_WRITE"
  }

  network_interface {
    network    = google_compute_network.vpc.id
    subnetwork = google_compute_subnetwork.subnet.id

    access_config {
      nat_ip = google_compute_address.static_ip.address
    }
  }

  service_account {
    email  = google_service_account.vm_sa.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = replace(<<-EOF
    #!/bin/bash
    set -euo pipefail

    echo "=== Starting Spring AI GCE VM Setup ==="

    # 1. Update packages & install Docker & Compose
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg lsb-release

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    systemctl enable docker
    systemctl start docker

    # 2. Format and mount persistent disk for PostgreSQL
    DISK_DEV="/dev/disk/by-id/google-postgres-data"
    MOUNT_DIR="/mnt/disks/postgres-data"
    mkdir -p "$MOUNT_DIR"

    # Wait for device to appear
    while [ ! -b "$DISK_DEV" ]; do
      echo "Waiting for disk device $DISK_DEV..."
      sleep 2
    done

    # Format disk if unformatted
    if ! blkid "$DISK_DEV"; then
      echo "Formatting persistent disk $DISK_DEV..."
      mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard "$DISK_DEV"
    fi

    # Mount and add to fstab if not present
    if ! grep -qs "$MOUNT_DIR" /proc/mounts; then
      mount -o discard,defaults "$DISK_DEV" "$MOUNT_DIR"
    fi

    UUID=$(blkid -s UUID -o value "$DISK_DEV")
    if ! grep -qs "$UUID" /etc/fstab; then
      echo "UUID=$UUID $MOUNT_DIR ext4 discard,defaults,nofail 0 2" >> /etc/fstab
    fi

    mkdir -p "$MOUNT_DIR/data"
    chmod -R 777 "$MOUNT_DIR"

    # 3. Create Application Directory & Compose files
    APP_DIR="/opt/spring-ai-rag"
    mkdir -p "$APP_DIR"
    cd "$APP_DIR"

    cat << 'ENVFILE' > "$APP_DIR/.env"
GEMINI_API_KEY=${var.gemini_api_key}
DB_NAME=${var.db_name}
DB_USER=${var.db_user}
DB_PASSWORD=${local.effective_db_password}
APP_PORT=${var.app_port}
ENVFILE

    cat << 'COMPOSEFILE' > "$APP_DIR/docker-compose.yml"
version: "3.8"

services:
  postgres:
    image: ${var.postgres_image}
    container_name: pg-rag
    restart: always
    environment:
      POSTGRES_USER: ${var.db_user}
      POSTGRES_PASSWORD: ${local.effective_db_password}
      POSTGRES_DB: ${var.db_name}
      PGDATA: /var/lib/postgresql/data/pgdata
    ports:
      - "127.0.0.1:5432:5432"
    volumes:
      - /mnt/disks/postgres-data/data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${var.db_user} -d ${var.db_name}"]
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 15s

  app:
    image: ${var.container_image}
    container_name: spring-ai-rag-app
    restart: always
    ports:
      - "${var.app_port}:8080"
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/${var.db_name}
      SPRING_DATASOURCE_USERNAME: ${var.db_user}
      SPRING_DATASOURCE_PASSWORD: ${local.effective_db_password}
      GEMINI_API_KEY: ${var.gemini_api_key}
      JAVA_TOOL_OPTIONS: "-XX:MaxRAMPercentage=75.0"
    depends_on:
      postgres:
        condition: service_healthy

volumes:
  pgdata:
COMPOSEFILE

    # 4. Create systemd service for auto-start on boot
    cat << 'SERVICEFILE' > /etc/systemd/system/spring-ai.service
[Unit]
Description=Spring AI RAG Docker Compose Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/spring-ai-rag
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
SERVICEFILE

    systemctl daemon-reload
    systemctl enable spring-ai.service

    # 5. Pull images and launch application
    docker compose pull
    docker compose up -d

    echo "=== Spring AI GCE VM Setup Completed Successfully ==="
  EOF
  , "\r", "")

  depends_on = [
    google_compute_disk.postgres_data,
    google_compute_subnetwork.subnet,
    google_compute_firewall.allow_http,
    google_compute_firewall.allow_ssh
  ]
}
