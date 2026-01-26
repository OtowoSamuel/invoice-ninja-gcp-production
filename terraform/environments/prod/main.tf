# Production Environment - Invoice Ninja on GCP

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
    prefix = "prod"
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
  env        = "prod"
}

# IAM Module - Service Accounts
module "iam" {
  source = "../../modules/iam"
  
  project_id = var.project_id
  env        = "prod"
}

# Secrets Module
module "secrets" {
  source = "../../modules/secrets"
  
  project_id = var.project_id
  env        = "prod"
  
  # Secrets will be created with placeholder values
  # Update manually via console or terraform after creation
}

# Cloud SQL Module
module "cloud_sql" {
  source = "../../modules/cloud-sql"
  
  project_id    = var.project_id
  region        = var.region
  env           = "prod"
  network_id    = module.networking.network_id
  database_name = var.database_name
  database_user = var.database_user
  
  # Production tier - high availability
  tier                   = "db-custom-2-7680"  # 2 vCPU, 7.5GB RAM
  availability_type      = "REGIONAL"          # Multi-zone HA
  backup_enabled         = true
  point_in_time_recovery = true                # 7-day PITR
}

# Cloud Run Module - Web Application
module "cloud_run_web" {
  source = "../../modules/cloud-run"
  
  project_id       = var.project_id
  region           = var.region
  env              = "prod"
  service_name     = "invoice-ninja-web"
  container_image  = var.web_container_image
  vpc_connector_id = module.networking.vpc_connector_id
  
  service_account_email = module.iam.cloud_run_sa_email
  
  # Production settings
  min_instances = 2    # Always have 2 instances running
  max_instances = 50   # Scale up to 50 under load
  cpu_limit     = "2"  # 2 vCPU per instance
  memory_limit  = "1Gi" # 1GB RAM per instance
  
  env_vars = {
    APP_ENV         = "production"
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
  env          = "prod"
  service_name = module.cloud_run_web.service_name
  alert_email  = var.alert_email
}
