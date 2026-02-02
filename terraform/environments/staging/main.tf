# Staging Environment - Invoice Ninja on GCP

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
  backend "gcs" {
    bucket = "invoice-ninja-prod-terraform-state"
    prefix = "staging"
  }
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
  env        = "staging"
}

# IAM Module - Service Accounts
module "iam" {
  source = "../../modules/iam"
  
  project_id = var.project_id
  env        = "staging"
}

# Artifact Registry for Docker Images
module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id                 = var.project_id
  region                     = var.region
  env                        = "staging"
  repository_id              = "invoiceninja"
  description                = "Invoice Ninja Docker images for staging environment"
  deployer_service_account   = module.iam.deployer_sa_email
  cloud_run_service_account  = module.iam.cloud_run_sa_email
}

# Secrets Module
module "secrets" {
  source = "../../modules/secrets"
  
  project_id = var.project_id
  env        = "staging"
  
  # Secrets will be created with placeholder values
  # Update manually via console or terraform after creation
}

# Cloud SQL Module
module "cloud_sql" {
  source = "../../modules/cloud-sql"
  
  project_id     = var.project_id
  region         = var.region
  env            = "staging"
  network_id     = module.networking.network_id
  vpc_connection = module.networking.vpc_connection
  database_name  = var.database_name
  database_user  = var.database_user
  
  # Staging tier - smaller than prod, bigger than dev
  tier                   = "db-custom-1-3840"  # 1 vCPU, 3.75GB RAM
  availability_type      = "ZONAL"             # Single zone (save cost)
  backup_enabled         = true
  point_in_time_recovery = false               # Save cost in staging
  deletion_protection    = false               # Allow easy teardown
}

# Cloud Run Module - Web Application
module "cloud_run_web" {
  source = "../../modules/cloud-run"
  
  project_id       = var.project_id
  region           = var.region
  env              = "staging"
  service_name     = "invoice-ninja-web"
  container_image  = var.web_container_image
  vpc_connector_id = module.networking.vpc_connector_id
  
  service_account_email = module.iam.cloud_run_sa_email
  
  # Staging settings - smaller than prod
  min_instances = 1    # Keep 1 instance warm
  max_instances = 10   # Scale up to 10 under load
  cpu_limit     = "1"  # 1 vCPU per instance
  memory_limit  = "512Mi" # 512MB RAM per instance
  
  env_vars = {
    APP_ENV         = "staging"
    APP_DEBUG       = "false"
    DB_CONNECTION   = "pgsql"
    DB_HOST         = module.cloud_sql.private_ip
    DB_PORT         = "5432"
    DB_DATABASE     = var.database_name
    CACHE_DRIVER    = "redis"
    QUEUE_CONNECTION = "redis"
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
  env          = "staging"
  service_name = module.cloud_run_web.service_name
  alert_email  = var.alert_email
}
