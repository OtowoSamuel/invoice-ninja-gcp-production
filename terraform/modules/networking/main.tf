# Networking Module - VPC, Subnets, Serverless VPC Connector

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "invoice-ninja-${var.env}-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

# Subnet for Serverless VPC Connector
resource "google_compute_subnetwork" "vpc_connector_subnet" {
  name          = "invoice-ninja-${var.env}-connector-subnet"
  ip_cidr_range = var.vpc_connector_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
  project       = var.project_id
}

# Serverless VPC Connector (for Cloud Run to access Cloud SQL via private IP)
resource "google_vpc_access_connector" "connector" {
  name    = "in-${var.env}-connector"  # Shortened to meet 25-char limit
  region  = var.region
  project = var.project_id
  
  subnet {
    name = google_compute_subnetwork.vpc_connector_subnet.name
  }
  
  min_instances = 2
  max_instances = 3
  
  machine_type = "e2-micro"  # Cost-optimized for dev
}

# Reserve IP range for Cloud SQL private connection
resource "google_compute_global_address" "private_ip_range" {
  name          = "invoice-ninja-${var.env}-sql-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
  project       = var.project_id
}

# Private VPC connection for Cloud SQL
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

# Firewall rule: Allow health checks from Google Load Balancers
resource "google_compute_firewall" "allow_health_checks" {
  name    = "invoice-ninja-${var.env}-allow-health-checks"
  network = google_compute_network.vpc.name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]  # GCP health check ranges
  target_tags   = ["invoice-ninja-${var.env}"]
}
