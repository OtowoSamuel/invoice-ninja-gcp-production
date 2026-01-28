variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for Artifact Registry"
  type        = string
}

variable "env" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "repository_id" {
  description = "Artifact Registry repository ID"
  type        = string
  default     = "invoiceninja"
}

variable "description" {
  description = "Repository description"
  type        = string
  default     = "Docker images for Invoice Ninja application"
}

variable "deployer_service_account" {
  description = "Email of deployer service account (needs write access)"
  type        = string
}

variable "cloud_run_service_account" {
  description = "Email of Cloud Run service account (needs read access)"
  type        = string
}
