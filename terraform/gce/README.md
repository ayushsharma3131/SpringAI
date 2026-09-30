# GCE Container Deployment for Spring AI RAG

This Terraform configuration provisions a production-ready **Google Compute Engine (GCE)** instance running your **Spring AI application** and **PostgreSQL (`pgvector`)** as Docker containers.

---

## Key Features

- **Automated Docker Provisioning:** Uses VM metadata startup script to install Docker, Docker Compose, and launch containers.
- **Data Persistence:** Provisions a dedicated GCP Persistent Disk (`pd-balanced`), formats, mounts it, and maps PostgreSQL data (`/var/lib/postgresql/data`) to it so database records survive VM restarts or recreations.
- **Static External IP:** Allocates a permanent public IP address so your API endpoints don't change.
- **Security & Networking:** Isolated VPC, Subnet, and Firewall rules opening only ports 8080 (or 80) and 22 (SSH). Postgres port 5432 is bound to localhost inside the VM for security.
- **Auto-restart:** Configures a `systemd` service (`spring-ai.service`) on the VM to ensure containers automatically restart on VM reboot.

---

## Deployment Steps

### 1. Prerequisites
- Google Cloud SDK (`gcloud`) installed and authenticated:
  ```bash
  gcloud auth application-default login
  ```
- Terraform CLI (v1.5+) installed.
- Docker image published to Docker Hub: `ayushsharma3131/spring-ai-rag:latest`.

### 2. Configure Variables
Navigate to the `terraform/gce` directory:
```bash
cd terraform/gce
```

Edit `terraform.tfvars`:
```hcl
project_id     = "your-gcp-project-id"
gemini_api_key = "AIzaSy..."
```

### 3. Deploy Infrastructure & Containers
```bash
terraform init
terraform plan
terraform apply
```

### 4. Verify & Test Endpoints
After `terraform apply` finishes, get the outputs:
```bash
terraform output app_url
```

#### Test Document Ingestion:
```bash
curl -X POST http://<PUBLIC_IP>:8080/api/rag/ingest
```

#### Test Query / Ask:
```bash
curl -X POST http://<PUBLIC_IP>:8080/api/rag/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "Summarize the resume"}'
```

---

## Management & Troubleshooting

### SSH into the VM:
```bash
gcloud compute ssh spring-ai-rag-vm --zone us-central1-a
```

### Check Container Status:
```bash
cd /opt/spring-ai-rag
docker compose ps
docker compose logs -f
```

### Check Startup Script Logs:
```bash
sudo journalctl -u google-startup-scripts.service -f
```
