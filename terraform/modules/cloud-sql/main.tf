# Cloud SQL Module - PostgreSQL with Private IP

# Generate random password for database
resource "random_password" "db_password" {
  length  = 32
  special = true
}

# Cloud SQL Instance
resource "google_sql_database_instance" "main" {
  name             = "invoice-ninja-${var.env}-db"
  database_version = "POSTGRES_15"
  region           = var.region
  project          = var.project_id

  # Depends on private VPC connection
  depends_on = [var.vpc_connection]

  settings {
    tier              = var.tier
    availability_type = var.availability_type
    disk_size         = var.disk_size
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    # Backup configuration
    backup_configuration {
      enabled                        = var.backup_enabled
      start_time                     = "02:00"  # 2 AM
      point_in_time_recovery_enabled = var.point_in_time_recovery
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 7
      }
    }

    # IP configuration - Private IP only
    ip_configuration {
      ipv4_enabled    = false  # No public IP
      private_network = var.network_id
      ssl_mode        = "ENCRYPTED_ONLY"  # Replaces deprecated require_ssl
    }

    # Maintenance window
    maintenance_window {
      day          = 7  # Sunday
      hour         = 3  # 3 AM
      update_track = "stable"
    }

    # Database flags for performance
    database_flags {
      name  = "max_connections"
      value = var.max_connections
    }

    database_flags {
      name  = "shared_buffers"
      value = "65536"  # 64MB in KB (suitable for db-f1-micro)
    }

    database_flags {
      name  = "effective_cache_size"
      value = "81920"  # 80MB in KB (max for db-f1-micro is ~90MB)
    }
  }

  deletion_protection = var.deletion_protection
}

# Create database
resource "google_sql_database" "database" {
  name     = var.database_name
  instance = google_sql_database_instance.main.name
  project  = var.project_id
}

# Create database user
resource "google_sql_user" "user" {
  name     = var.database_user
  instance = google_sql_database_instance.main.name
  password = random_password.db_password.result
  project  = var.project_id
}

# Store password in Secret Manager
resource "google_secret_manager_secret" "db_password" {
  secret_id = "invoice-ninja-${var.env}-db-password"
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}
