# Terraform Quick Start Guide

## 🎯 What We Built

Complete Terraform infrastructure for Invoice Ninja on GCP with:
- ✅ VPC networking with private connectivity
- ✅ Cloud SQL PostgreSQL with backups
- ✅ Cloud Run for serverless containers
- ✅ Secret Manager for credentials
- ✅ IAM with least-privilege service accounts
- ✅ Cloud Monitoring with alerts

## 📍 Your Files Are Here

```
/home/otowo-samuel/Documents/Projects-2026/invoice-ninja-gcp-production/terraform/
```

## 🚀 Quick Start (5 minutes)

### Step 1: Set Your Project ID
```bash
cd terraform/environments/dev

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

**Update these in `terraform.tfvars`:**
```hcl
project_id  = "your-gcp-project-id"     # Get from: gcloud config get-value project
region      = "us-central1"              # Or your preferred region
alert_email = "your-email@example.com"   # For monitoring alerts
```

### Step 2: Initialize Terraform
```bash
terraform init
```

This downloads the GCP provider and prepares Terraform.

### Step 3: Review the Plan
```bash
terraform plan
```

Review what will be created (VPC, Cloud SQL, service accounts, etc.)

### Step 4: Deploy (when ready)
```bash
terraform apply
```

Type `yes` when prompted. This takes ~10-15 minutes (Cloud SQL is slow to create).

### Step 5: Get Outputs
```bash
terraform output
```

You'll see:
- Cloud Run URL (placeholder until you deploy container)
- Cloud SQL connection details
- Service account emails

## 📚 Reference Repositories to Learn From

### 1. Official Google Modules (⭐ Start Here)
```bash
# Clone to study locally
git clone https://github.com/terraform-google-modules/terraform-google-sql-db.git
git clone https://github.com/terraform-google-modules/terraform-google-network.git
git clone https://github.com/terraform-google-modules/terraform-google-cloud-run.git

# Look at the examples/ directory in each
```

### 2. Google Cloud Foundation Fabric
- **URL**: https://github.com/GoogleCloudPlatform/cloud-foundation-fabric
- **What to Study**: `modules/` and `blueprints/` directories
- **Why**: Enterprise-grade patterns, real-world examples

### 3. Terraform GCP Provider Docs
- **URL**: https://registry.terraform.io/providers/hashicorp/google/latest/docs
- **Use**: Look up any resource (google_cloud_run_service, google_sql_database_instance, etc.)

### 4. Specific Examples for Your Stack
- Cloud Run + Cloud SQL: https://github.com/GoogleCloudPlatform/terraform-google-cloud-run
- Laravel deployment patterns: Search "terraform laravel gcp" on GitHub
- FinTech security patterns: Google Cloud Architecture Center

## 🔍 Understanding the Structure

### Modules (Reusable Building Blocks)
```
modules/
├── networking/   → VPC, subnets, connectors
├── cloud-sql/    → PostgreSQL database
├── cloud-run/    → Serverless containers
├── secrets/      → Secret Manager
├── iam/          → Service accounts & permissions
└── monitoring/   → Alerts & dashboards
```

Each module has:
- `main.tf` - Resource definitions
- `variables.tf` - Input parameters
- `outputs.tf` - Values to export
- `README.md` - Documentation

### Environments (Where You Deploy)
```
environments/
├── dev/      → Development (you are here)
├── staging/  → Pre-production
└── prod/     → Production
```

Each environment:
- Calls the same modules
- Uses different variables (size, region, etc.)
- Has separate state

## 🎓 Learning Path

1. **Day 1 Morning** - Understand one module:
   - Read `modules/networking/main.tf`
   - Compare with official example: `terraform-google-modules/terraform-google-network`
   - Understand VPC, subnets, Serverless VPC connector

2. **Day 1 Afternoon** - Deploy dev environment:
   - Fill in `terraform.tfvars`
   - Run `terraform plan`
   - Run `terraform apply`
   - Explore GCP console to see resources

3. **Day 2** - Customize and learn:
   - Modify Cloud SQL tier (try different sizes)
   - Add custom environment variables
   - Study monitoring alerts
   - Read official Terraform docs for each resource

## 🔧 Common Commands

```bash
# Format code
terraform fmt -recursive

# Validate syntax
terraform validate

# Preview changes
terraform plan

# Apply changes
terraform apply

# Show current state
terraform show

# List resources
terraform state list

# Get specific output
terraform output cloud_run_url

# Destroy everything (careful!)
terraform destroy
```

## 🐛 Troubleshooting

### "API not enabled"
```bash
gcloud services enable compute.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable secretmanager.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable vpcaccess.googleapis.com
```

### "Quota exceeded"
- Check GCP quotas: https://console.cloud.google.com/iam-admin/quotas
- Request increase if needed (usually instant for dev)

### "Permission denied"
```bash
# Re-authenticate
gcloud auth application-default login

# Check current project
gcloud config get-value project
```

### "State lock" errors
```bash
# View lock info
terraform force-unlock <LOCK_ID>
```

## 📝 Next Steps

1. **Review the main README**: `terraform/README.md` (comprehensive guide)
2. **Study reference repos**: Clone and explore the official Google modules
3. **Deploy dev**: Follow the quick start above
4. **Learn by modifying**: Change variables, add resources, experiment
5. **Read GCP docs**: Understand each service (Cloud Run, Cloud SQL, etc.)

## 💡 Tips for Deep Learning

### Understand Each Resource
For every `resource` block in Terraform:
1. Read the Terraform docs
2. Read the GCP docs for that service
3. Try deploying it
4. Modify it and see what changes
5. Understand the pricing implications

### Study Real Examples
- Don't just copy-paste
- Understand WHY each configuration choice was made
- Compare multiple examples of the same resource
- Read the official module source code

### Practice Iteratively
1. Deploy basic version
2. Test it works
3. Add one feature
4. Test again
5. Repeat

## 🔗 Key Documentation Links

- **Terraform GCP Provider**: https://registry.terraform.io/providers/hashicorp/google/latest/docs
- **Cloud Run**: https://cloud.google.com/run/docs
- **Cloud SQL**: https://cloud.google.com/sql/docs
- **Secret Manager**: https://cloud.google.com/secret-manager/docs
- **Serverless VPC**: https://cloud.google.com/vpc/docs/configure-serverless-vpc-access
- **Terraform Best Practices**: https://www.terraform-best-practices.com/

---

**Ready to deploy?** Head to `terraform/environments/dev/` and run `terraform init`! 🚀
