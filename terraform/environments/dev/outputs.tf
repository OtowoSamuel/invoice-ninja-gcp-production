output "cloud_run_url" {
  description = "URL of the Cloud Run web service"
  value       = module.cloud_run_web.service_url
}

output "cloud_sql_instance_name" {
  description = "Cloud SQL instance name"
  value       = module.cloud_sql.instance_name
}

output "cloud_sql_connection_name" {
  description = "Cloud SQL connection string"
  value       = module.cloud_sql.connection_name
}

output "cloud_sql_private_ip" {
  description = "Cloud SQL private IP address"
  value       = module.cloud_sql.private_ip
  sensitive   = true
}

output "vpc_connector_id" {
  description = "Serverless VPC Connector ID"
  value       = module.networking.vpc_connector_id
}

output "service_account_email" {
  description = "Cloud Run service account email"
  value       = module.iam.cloud_run_sa_email
}

output "artifact_registry_url" {
  description = "Artifact Registry repository URL for docker push/pull"
  value       = module.artifact_registry.repository_url
}
