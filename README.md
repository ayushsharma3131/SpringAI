# Spring AI RAG Service

A Retrieval-Augmented Generation (RAG) service built with **Spring Boot**, **Spring AI**, **Google GenAI (Gemini)**, and **PostgreSQL (`pgvector`)**, with automated cloud provisioning and deployment via **Terraform** on **Google Cloud Platform (GCP)**.

---

## Architecture & Tech Stack

```
                     ┌──────────────────────────────────────────────┐
                     │               Google Cloud (GCE)             │
                     │                                              │
[ Client / Curl ] ──>│  [ Firewall: 8080 ] ──> [ Spring Boot App ]  │──> [ Google Gemini API ]
                     │                              │               │   (Chat & Embeddings)
                     │                              ▼               │
                     │                     [ pgvector / Postgres ]  │
                     │                              │               │
                     │                              ▼               │
                     │                  [ Persistent Disk (pd-ssd) ] │
                     └──────────────────────────────────────────────┘
```

- **Backend Framework:** Spring Boot 3.5 & Spring AI 1.1 (`ChatClient`, `QuestionAnswerAdvisor`, `PgVectorStore`)
- **LLM & Embeddings:** Google GenAI (Gemini)
- **Vector Database:** PostgreSQL 16 with the `pgvector` extension
- **Containerization:** Docker multi-stage build & Docker Compose
- **Infrastructure as Code (IaC):** Terraform (`>= 1.5.0`)
- **Cloud Platform:** Google Cloud Platform (GCP Compute Engine, Persistent Disk, VPC & Firewall rules, Static IP)

---

## Prerequisites

- **Java 21+** (for local development)
- **Docker & Docker Compose** (for containerized execution)
- **Google Gemini API Key** (`GEMINI_API_KEY`)
- **Terraform 1.5+** and **Google Cloud SDK (`gcloud`)** *(for GCP deployment)*

> [!NOTE]
> No local Maven installation is required. The repository includes the Maven Wrapper (`mvnw` / `mvnw.cmd`), which downloads and uses the required Maven version automatically.

---

## Local Development

### 1. Start Vector Database (PostgreSQL with pgvector)

```bash
docker compose up -d postgres
```

### 2. Export API Key

```bash
# macOS / Linux
export GEMINI_API_KEY="your-gemini-api-key"

# Windows (PowerShell)
$env:GEMINI_API_KEY="your-gemini-api-key"
```

### 3. Run the Application

```bash
# macOS / Linux
./mvnw spring-boot:run

# Windows
.\mvnw.cmd spring-boot:run
```

The service will start on `http://localhost:8080`. On first boot, Spring AI automatically initializes the schema and the `vector_store` table in Postgres.

---

## Docker & Container Execution

To run both the application and database as containers locally:

```bash
# Set your Gemini API key in environment or .env file
export GEMINI_API_KEY="your-gemini-api-key"

# Build and start all services
docker compose up -d --build
```

---

## GCP Infrastructure & Deployment with Terraform

The project includes production-ready Terraform scripts in [`terraform/gce`](file:///C:/Users/User/IdeaProjects/SpringAI/terraform/gce) to provision and run the full stack on Google Compute Engine (GCE).

### Infrastructure Highlights

- **Custom VPC & Subnet:** Isolated networking configuration.
- **Firewall Security:** Restricts ingress to application ports (8080/80) and SSH (22). PostgreSQL is bound to localhost internally.
- **Data Persistence:** Provisions a dedicated GCP Persistent Disk (`pd-balanced`), automatically mounts it at `/mnt/disks/postgres-data`, and maps PostgreSQL storage so data persists across VM restarts or recreations.
- **Static External IP:** Reserves a permanent public IP address.
- **Automated Bootstrapping:** VM startup script installs Docker & Docker Compose, pulls the application image, configures environment secrets, and registers a `systemd` service (`spring-ai.service`) for automatic restart on boot.

---

### Step-by-Step GCP Deployment

#### 1. Authenticate with GCP

Ensure `gcloud` CLI is installed and configured:

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

#### 2. Configure Terraform Variables

Navigate to the Terraform directory:

```bash
cd terraform/gce
```

Create or update `terraform.tfvars`:

```hcl
project_id      = "your-gcp-project-id"
region          = "us-central1"
zone            = "us-central1-a"
gemini_api_key  = "your-gemini-api-key"
container_image = "ayushsharma3131/spring-ai-rag:latest"
```

#### 3. Initialize & Deploy

```bash
# Initialize providers and modules
terraform init

# Review execution plan
terraform plan

# Provision infrastructure
terraform apply -auto-approve
```

#### 4. View Deployment Outputs

Once deployment completes, Terraform outputs the public IP and service URL:

```bash
terraform output app_url
```

---

### Remote VM Management & Logs

#### SSH into the VM:
```bash
gcloud compute ssh spring-ai-rag-vm --zone us-central1-a
```

#### Check Docker Containers:
```bash
cd /opt/spring-ai-rag
docker compose ps
docker compose logs -f
```

#### View Startup Script Execution Logs:
```bash
sudo journalctl -u google-startup-scripts.service -f
```

#### Destroy Infrastructure:
```bash
cd terraform/gce
terraform destroy
```

---

## API Reference

### 1. Ingest a Document

Upload a PDF or document into the RAG vector store for chunking and embedding:

```bash
curl -X POST http://localhost:8080/api/rag/ingest \
  -F "file=@/path/to/document.pdf"
```

**Response:**
```json
{
  "chunksIndexed": 12,
  "message": "Indexed document.pdf"
}
```

---

### 2. Query / Ask a Question

Ask questions based on indexed document context:

```bash
curl -X POST http://localhost:8080/api/rag/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "What are the key qualifications mentioned in the resume?"}'
```

**Response:**
```json
{
  "answer": "The candidate has experience in Java, Spring Boot, Spring AI, and Cloud deployments...",
  "metadata": [
    { "source": "document.pdf", "distance": 0.15 }
  ]
}
```

---

## Running Tests

Unit and integration tests mock external service dependencies (`DocumentIngestionService`, `RagQueryService`), so they can be run without live Postgres or Gemini connections:

```bash
# macOS / Linux
./mvnw test

# Windows
.\mvnw.cmd test
```
