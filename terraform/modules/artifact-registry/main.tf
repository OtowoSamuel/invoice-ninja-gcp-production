# Artifact Registry Module
# Manages Docker container registry for application images

resource "google_artifact_registry_repository" "main" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  description   = var.description
  format        = "DOCKER"

  labels = {
    environment = var.env
    managed_by  = "terraform"
  }
}

# Grant deployer service account permission to push images
resource "google_artifact_registry_repository_iam_member" "deployer_writer" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.main.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.deployer_service_account}"
}

# Grant Cloud Run service account permission to pull images
resource "google_artifact_registry_repository_iam_member" "cloud_run_reader" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.main.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.cloud_run_service_account}"
}
