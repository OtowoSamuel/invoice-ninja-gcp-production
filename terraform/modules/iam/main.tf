# IAM Module - Service Accounts and Permissions

# Cloud Run service account (for web app)
resource "google_service_account" "cloud_run" {
  account_id   = "invoice-ninja-${var.env}-run-sa"
  display_name = "Invoice Ninja Cloud Run Service Account (${var.env})"
  project      = var.project_id
}

# Queue worker service account
resource "google_service_account" "worker" {
  account_id   = "invoice-ninja-${var.env}-worker-sa"
  display_name = "Invoice Ninja Worker Service Account (${var.env})"
  project      = var.project_id
}

# CI/CD deployer service account
resource "google_service_account" "deployer" {
  account_id   = "invoice-ninja-${var.env}-deployer-sa"
  display_name = "Invoice Ninja CI/CD Deployer (${var.env})"
  project      = var.project_id
}

# Grant Cloud Run SA access to Secret Manager
resource "google_project_iam_member" "cloud_run_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Grant Cloud Run SA access to Cloud SQL
resource "google_project_iam_member" "cloud_run_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Grant Cloud Run SA access to Cloud Storage
resource "google_project_iam_member" "cloud_run_storage_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Grant Worker SA same permissions as Cloud Run
resource "google_project_iam_member" "worker_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.worker.email}"
}

resource "google_project_iam_member" "worker_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.worker.email}"
}

resource "google_project_iam_member" "worker_storage_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.worker.email}"
}

# Grant Deployer SA ability to deploy to Cloud Run
resource "google_project_iam_member" "deployer_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

# Grant Deployer SA ability to act as Cloud Run service accounts
resource "google_service_account_iam_member" "deployer_act_as_cloud_run" {
  service_account_id = google_service_account.cloud_run.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_service_account_iam_member" "deployer_act_as_worker" {
  service_account_id = google_service_account.worker.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deployer.email}"
}

# Grant Deployer SA ability to push Docker images to Artifact Registry
resource "google_project_iam_member" "deployer_artifact_registry_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}
