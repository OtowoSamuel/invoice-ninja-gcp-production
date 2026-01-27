# Development Environment - Invoice Ninja on GCP

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Backend configuration for state storage
  # Uncomment after creating GCS bucket for state
  # backend "gcs" {
  #   bucket = "invoice-ninja-terraform-state-dev"
  #   prefix = "dev"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Networking Module
module "networking" {
  source = "../../modules/networking"
  
  project_id = var.project_id
  region     = var.region
  env        = "dev"
}

# IAM Module - Service Accounts
module "iam" {
  source = "../../modules/iam"
  
  project_id = var.project_id
  env        = "dev"
}

# Secrets Module
module "secrets" {
  source = "../../modules/secrets"
  
  project_id = var.project_id
  env        = "dev"
  
  # Secrets will be created with placeholder values
  # Update manually via console or terraform after creation
}

# Cloud SQL Module
module "cloud_sql" {
  source = "../../modules/cloud-sql"
  
  project_id     = var.project_id
  region         = var.region
  env            = "dev"
  network_id     = module.networking.network_id
  vpc_connection = module.networking.vpc_connection
  database_name  = var.database_name
  database_user  = var.database_user
  
  # Dev tier - small instance
  tier                   = "db-f1-micro"
  availability_type      = "ZONAL"
  backup_enabled         = true
  point_in_time_recovery = false  # Save cost in dev
  deletion_protection    = false  # Easy to tear down dev
}

# Cloud Run Module - Web Application
module "cloud_run_web" {
  source = "../../modules/cloud-run"
  
  project_id       = var.project_id
  region           = var.region
  env              = "dev"
  service_name     = "invoice-ninja-web"
  container_image  = var.web_container_image
  vpc_connector_id = module.networking.vpc_connector_id
  
  service_account_email = module.iam.cloud_run_sa_email
  
  # Dev settings
  min_instances = 0  # Scale to zero
  max_instances = 5
  cpu_limit     = "1"
  memory_limit  = "512Mi"
  
  env_vars = {
    APP_ENV         = "development"
    APP_DEBUG       = "true"
    DB_CONNECTION   = "pgsql"
    DB_HOST         = module.cloud_sql.private_ip
    DB_PORT         = "5432"
    DB_DATABASE     = var.database_name
    CACHE_DRIVER    = "file"  # Use Redis in staging/prod
    QUEUE_CONNECTION = "database"
  }
  
  secrets = {
    DB_PASSWORD = "${module.cloud_sql.db_password_secret_id}:latest"
    APP_KEY     = "${module.secrets.app_key_secret_id}:latest"
  }
}

# Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"
  
  project_id   = var.project_id
  env          = "dev"
  service_name = module.cloud_run_web.service_name
  alert_email  = var.alert_email
}
