output "cloud_run_sa_email" {
  description = "Cloud Run service account email"
  value       = google_service_account.cloud_run.email
}

output "worker_sa_email" {
  description = "Worker service account email"
  value       = google_service_account.worker.email
}

output "deployer_sa_email" {
  description = "Deployer service account email"
  value       = google_service_account.deployer.email
}
