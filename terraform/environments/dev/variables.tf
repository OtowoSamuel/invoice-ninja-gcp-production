variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "database_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "invoiceninja"
}

variable "database_user" {
  description = "PostgreSQL database user"
  type        = string
  default     = "invoiceninja"
}

variable "web_container_image" {
  description = "Container image for web application"
  type        = string
  default     = "gcr.io/cloudrun/hello"  # Placeholder, update after building image
}

variable "alert_email" {
  description = "Email address for monitoring alerts"
  type        = string
}
