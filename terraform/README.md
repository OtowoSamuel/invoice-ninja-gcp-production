# Terraform Infrastructure for Invoice Ninja on GCP

This directory contains all Terraform configurations to deploy Invoice Ninja to Google Cloud Platform with production-grade security, monitoring, and reliability.

## 📁 Directory Structure

```
terraform/
├── environments/          # Environment-specific configurations
│   ├── dev/              # Development environment
│   ├── staging/          # Staging environment
│   └── prod/             # Production environment
├── modules/              # Reusable Terraform modules
│   ├── networking/       # VPC, subnets, firewall rules
│   ├── cloud-sql/        # Cloud SQL (PostgreSQL)
│   ├── cloud-run/        # Cloud Run services
│   ├── secrets/          # Secret Manager
│   ├── monitoring/       # Cloud Monitoring & Logging
│   └── iam/              # Service accounts & IAM policies
└── README.md            # This file
```

## 🚀 Quick Start

### Prerequisites

1. **Install Terraform** (v1.5+)
```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

2. **Install gcloud CLI**
```bash
# Follow: https://cloud.google.com/sdk/docs/install
gcloud init
gcloud auth application-default login
```

3. **Set up GCP project**
```bash
export PROJECT_ID="invoice-ninja-prod"
export REGION="us-central1"

gcloud config set project $PROJECT_ID
```

### Deploy Development Environment

```bash
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply changes
terraform apply

# Get outputs
terraform output
```

## 📦 Module Reference

### 1. Networking Module (`modules/networking/`)
Creates VPC, subnets, Serverless VPC connector for Cloud Run to access Cloud SQL privately.

**What it does:**
- VPC network with custom subnets
- Serverless VPC Access connector
- Private Service Connection for Cloud SQL
- Firewall rules

**Example usage:**
```hcl
module "networking" {
  source = "../../modules/networking"
  
  project_id = var.project_id
  region     = var.region
  env        = "dev"
}
```

### 2. Cloud SQL Module (`modules/cloud-sql/`)
PostgreSQL database with backups, high availability, and private IP.

**What it does:**
- Cloud SQL PostgreSQL instance
- Automated backups (PITR enabled)
- Private IP connection
- Database and user creation

**Example usage:**
```hcl
module "cloud_sql" {
  source = "../../modules/cloud-sql"
  
  project_id      = var.project_id
  region          = var.region
  network_id      = module.networking.network_id
  database_name   = "invoiceninja"
  database_user   = "invoiceninja"
  tier            = "db-f1-micro"  # dev
}
```

### 3. Cloud Run Module (`modules/cloud-run/`)
Serverless containers for web app and queue workers.

**What it does:**
- Cloud Run service for web application
- Cloud Run jobs for queue workers
- IAM bindings for public/private access
- Environment variable injection

**Example usage:**
```hcl
module "cloud_run" {
  source = "../../modules/cloud-run"
  
  project_id     = var.project_id
  region         = var.region
  service_name   = "invoice-ninja-web"
  image          = "gcr.io/${var.project_id}/invoice-ninja:latest"
  vpc_connector  = module.networking.vpc_connector_id
  secrets        = module.secrets.secret_ids
}
```

### 4. Secrets Module (`modules/secrets/`)
Secret Manager for secure credential storage.

**What it does:**
- Create secrets (DB password, app key, API keys)
- IAM bindings for service accounts
- Secret versioning

**Example usage:**
```hcl
module "secrets" {
  source = "../../modules/secrets"
  
  project_id = var.project_id
  secrets = {
    db_password = "random-generated-password"
    app_key     = "base64:random-key"
    stripe_key  = var.stripe_api_key
  }
}
```

### 5. Monitoring Module (`modules/monitoring/`)
Cloud Monitoring dashboards, alerts, and log sinks.

**What it does:**
- Custom dashboards
- Alert policies (error rate, latency, uptime)
- Log-based metrics
- Notification channels

**Example usage:**
```hcl
module "monitoring" {
  source = "../../modules/monitoring"
  
  project_id       = var.project_id
  service_name     = "invoice-ninja-web"
  alert_email      = var.ops_email
}
```

### 6. IAM Module (`modules/iam/`)
Service accounts and IAM policies with least privilege.

**What it does:**
- Service accounts for Cloud Run, workers, CI/CD
- Custom IAM roles
- Policy bindings

**Example usage:**
```hcl
module "iam" {
  source = "../../modules/iam"
  
  project_id = var.project_id
  service_accounts = {
    cloud_run = "invoice-ninja-run-sa"
    workers   = "invoice-ninja-worker-sa"
    deployer  = "ci-cd-deployer-sa"
  }
}
```

## 🔗 Reference Terraform Repositories

### Official GCP Examples
1. **Google Cloud Platform Examples**
   - Repo: https://github.com/terraform-google-modules
   - What to learn: Official Google-maintained modules
   - Key modules:
     - `terraform-google-sql-db` - Cloud SQL patterns
     - `terraform-google-network` - VPC networking
     - `terraform-google-cloud-run` - Cloud Run deployments

2. **GCP Foundation Fabric**
   - Repo: https://github.com/GoogleCloudPlatform/cloud-foundation-fabric
   - What to learn: Enterprise-grade patterns, best practices
   - Focus on: `modules/` directory for production patterns

### Real-World Production Examples
3. **Gruntwork Infrastructure as Code Library**
   - Repo: https://github.com/gruntwork-io/terraform-google-gcp (some modules are paid)
   - What to learn: Production-ready module design patterns

4. **Cloud Run with Cloud SQL Example**
   - Repo: https://github.com/GoogleCloudPlatform/terraform-google-cloud-run
   - What to learn: Serverless VPC connector, private IP connections

5. **Complete Laravel on GCP**
   - Search: "terraform laravel gcp cloud run" on GitHub
   - Example: https://github.com/antonioua/terraform-gcp-laravel (check if exists)

### Learning Resources
6. **Terraform GCP Provider Documentation**
   - Docs: https://registry.terraform.io/providers/hashicorp/google/latest/docs
   - What to learn: All resource types, arguments, attributes

7. **Terraform Best Practices**
   - Guide: https://www.terraform-best-practices.com/
   - What to learn: Module design, state management, CI/CD integration

### Specific Module Examples to Study
```bash
# Clone and study these modules locally
git clone https://github.com/terraform-google-modules/terraform-google-sql-db.git
git clone https://github.com/terraform-google-modules/terraform-google-network.git
git clone https://github.com/terraform-google-modules/terraform-google-cloud-run.git

# Study the examples/ directory in each
cd terraform-google-sql-db/examples/
```

## 🏗️ Module Development Workflow

### Step 1: Start with a module
Pick one module to build first (recommend: networking → cloud-sql → cloud-run → secrets → iam → monitoring)

### Step 2: Module structure
```
modules/networking/
├── main.tf          # Resource definitions
├── variables.tf     # Input variables
├── outputs.tf       # Output values
├── versions.tf      # Provider version constraints
└── README.md        # Module documentation
```

### Step 3: Environment configuration
```
environments/dev/
├── main.tf          # Calls modules
├── variables.tf     # Environment variables
├── terraform.tfvars # Actual values (gitignored)
├── outputs.tf       # Environment outputs
└── backend.tf       # State backend (GCS bucket)
```

### Step 4: Test workflow
```bash
# Format code
terraform fmt -recursive

# Validate syntax
terraform validate

# Plan changes
terraform plan

# Apply (dev first)
terraform apply

# Destroy when testing
terraform destroy
```

## 📋 Pre-Implementation Checklist

Before writing Terraform code, gather:

- [ ] GCP project ID
- [ ] Billing account ID
- [ ] Region and zone preferences
- [ ] Domain name (for Cloud Run custom domain)
- [ ] Email for alerts
- [ ] Database name, user, initial password
- [ ] Required GCP APIs (enable via gcloud or in code)

## 🔒 Security Best Practices

1. **Never commit secrets**
   - Add `*.tfvars` to `.gitignore` (except `terraform.tfvars.example`)
   - Use Secret Manager for sensitive values
   - Use `sensitive = true` for variable outputs

2. **State management**
   - Store state in GCS bucket with versioning
   - Enable state locking
   - Encrypt state at rest

3. **Service account permissions**
   - Follow least-privilege principle
   - Use separate service accounts for each workload
   - Regularly audit IAM policies

## 🎯 Implementation Order (Recommended)

1. **Day 1, Phase 1.3** - Start here:
   ```
   ├── 1. Create networking module
   ├── 2. Create cloud-sql module  
   ├── 3. Create secrets module
   ├── 4. Create iam module
   ├── 5. Wire up dev environment
   └── 6. Test: terraform apply
   ```

2. **Day 1, Phase 1.4-1.5** - Add application:
   ```
   ├── 7. Create cloud-run module
   └── 8. Deploy first version
   ```

3. **Day 2** - Complete infrastructure:
   ```
   ├── 9. Create monitoring module
   ├── 10. Set up staging environment
   └── 11. Set up prod environment
   ```

## 🆘 Troubleshooting

### Common Issues

**"Error 403: Forbidden"**
```bash
# Check authentication
gcloud auth application-default login

# Check project
gcloud config get-value project
```

**"API not enabled"**
```bash
# Enable required APIs
gcloud services enable \
  compute.googleapis.com \
  sqladmin.googleapis.com \
  run.googleapis.com \
  secretmanager.googleapis.com
```

**"Backend initialization required"**
```bash
terraform init -reconfigure
```

**State lock errors**
```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

## 📚 Next Steps

1. **Read the learning path**: `../LEARNING_PATH.md` (Day 1, Phase 1.3)
2. **Study reference repos**: Clone and explore the repos listed above
3. **Start with networking**: Build the networking module first
4. **Test incrementally**: Apply after each module to catch errors early
5. **Document decisions**: Create ADRs in `../docs/ADR/`

## 🤝 Getting Help

- **Terraform Registry**: https://registry.terraform.io/providers/hashicorp/google/latest/docs
- **GCP Documentation**: https://cloud.google.com/docs
- **Stack Overflow**: Tag questions with `terraform` + `google-cloud-platform`
- **Terraform Discord**: https://discord.gg/terraform

---

**Ready to start?** Head to `environments/dev/` and begin with the networking module! 🚀
