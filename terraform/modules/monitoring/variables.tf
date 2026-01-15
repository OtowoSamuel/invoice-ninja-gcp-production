variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "service_name" {
  description = "Cloud Run service name to monitor"
  type        = string
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
}
