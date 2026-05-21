output "app_key_secret_id" {
  value = google_secret_manager_secret.app_key.secret_id
}

output "smtp_password_secret_id" {
  value = google_secret_manager_secret.smtp_password.secret_id
}

output "stripe_key_secret_id" {
  value = google_secret_manager_secret.stripe_key.secret_id
}