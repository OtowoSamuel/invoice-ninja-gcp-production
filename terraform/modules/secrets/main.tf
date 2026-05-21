locals {
  secrets = [
    "invoice-ninja-${var.env}-app-key",
    "invoice-ninja-${var.env}-smtp-password",
    "invoice-ninja-${var.env}-stripe-key"
  ]
}

resource "google_secret_manager_secret" "app_key" {
  secret_id = "invoice-ninja-${var.env}-app-key"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "app_key_version" {
  secret      = google_secret_manager_secret.app_key.id
  secret_data = "PLACEHOLDER_VALUE_CHANGE_ME"
}

resource "google_secret_manager_secret" "smtp_password" {
  secret_id = "invoice-ninja-${var.env}-smtp-password"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "smtp_password_version" {
  secret      = google_secret_manager_secret.smtp_password.id
  secret_data = "PLACEHOLDER_VALUE_CHANGE_ME"
}

resource "google_secret_manager_secret" "stripe_key" {
  secret_id = "invoice-ninja-${var.env}-stripe-key"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "stripe_key_version" {
  secret      = google_secret_manager_secret.stripe_key.id
  secret_data = "PLACEHOLDER_VALUE_CHANGE_ME"
}