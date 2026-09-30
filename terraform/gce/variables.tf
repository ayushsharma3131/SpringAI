variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "app_name" {
  description = "Application name prefix"
  type        = string
  default     = "spring-ai-rag"
}

variable "machine_type" {
  description = "Compute Engine machine type"
  type        = string
  default     = "e2-standard-2"
}

variable "gemini_api_key" {
  description = "API key for Google Gemini GenAI"
  type        = string
  sensitive   = true
}

variable "container_image" {
  description = "Container image for the Spring AI application"
  type        = string
  default     = "ayushsharma3131/spring-ai-rag:latest"
}

variable "postgres_image" {
  description = "PostgreSQL pgvector container image"
  type        = string
  default     = "pgvector/pgvector:pg16"
}

variable "db_name" {
  description = "PostgreSQL Database Name"
  type        = string
  default     = "ragdb"
}

variable "db_user" {
  description = "PostgreSQL Username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "PostgreSQL Password (if empty, a random password is generated)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "postgres_disk_size_gb" {
  description = "Size of attached persistent disk for Postgres data in GB"
  type        = number
  default     = 20
}

variable "app_port" {
  description = "Host port to expose Spring AI app on"
  type        = number
  default     = 8080
}
