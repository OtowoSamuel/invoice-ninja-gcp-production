variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "env" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_connector_cidr" {
  description = "CIDR range for Serverless VPC Connector"
  type        = string
  default     = "10.8.0.0/28"
}
