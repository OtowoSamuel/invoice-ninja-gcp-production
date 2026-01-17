# Manual Setup Checklist

**What you need to configure manually before deploying**

---

## 📋 Setup Phases

### Phase 1: Pre-Terraform Setup (Do This FIRST) ✨

#### 1.1 Enable GCP APIs
```bash
# Set your project
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs (takes 2-3 minutes)
gcloud services enable \
  run.googleapis.com \
  sql-component.googleapis.com \
  sqladmin.googleapis.com \
  compute.googleapis.com \
  vpcaccess.googleapis.com \
  servicenetworking.googleapis.com \
  cloudresourcemanager.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  monitoring.googleapis.com \
  logging.googleapis.com \
  cloudscheduler.googleapis.com

# Verify APIs are enabled
gcloud services list --enabled
```

#### 1.2 Create Terraform State Bucket
```bash
# Create bucket for Terraform state
gsutil mb -p YOUR_PROJECT_ID -l us-central1 gs://YOUR_PROJECT_ID-terraform-state

# Enable versioning (important for rollback)
gsutil versioning set on gs://YOUR_PROJECT_ID-terraform-state

# Prevent accidental deletion
gsutil lifecycle set - gs://YOUR_PROJECT_ID-terraform-state <<EOF
{
  "lifecycle": {
    "rule": [{
      "action": {"type": "Delete"},
      "condition": {"numNewerVersions": 5}
    }]
  }
}
EOF
```

#### 1.3 Update Terraform Backend Configuration
Edit `terraform/environments/prod/backend.tf`:
```hcl
terraform {
  backend "gcs" {
    bucket = "YOUR_PROJECT_ID-terraform-state"  # ← Update this
    prefix = "prod"
  }
}
```

---

### Phase 2: GitLab CI/CD Variables (Required for Pipeline) ✨

**Go to**: GitLab → Your Project → Settings → CI/CD → Variables

Add these variables (all should be **Protected** ✓ and **Masked** where possible):

#### Core Variables (REQUIRED)
| Variable | Type | Value | Masked | Protected |
|----------|------|-------|--------|-----------|
| `GCP_SERVICE_KEY` | **File** | (your service account JSON) | ❌ No | ✓ Yes |
| `GCP_PROJECT_ID` | Variable | `your-project-id` | ✓ Yes | ✓ Yes |
| `GCP_REGION` | Variable | `us-central1` | ❌ No | ✓ Yes |

#### Application Secrets (REQUIRED)
| Variable | Type | Value | Masked | Protected |
|----------|------|-------|--------|-----------|
| `APP_KEY` | Variable | Generate with `php artisan key:generate --show` | ✓ Yes | ✓ Yes |
| `DB_PASSWORD` | Variable | Strong password (min 16 chars) | ✓ Yes | ✓ Yes |
| `REDIS_PASSWORD` | Variable | Strong password (min 16 chars) | ✓ Yes | ✓ Yes |

#### Application Configuration (RECOMMENDED)
| Variable | Type | Value | Masked | Protected |
|----------|------|-------|--------|-----------|
| `APP_URL` | Variable | `https://yourdomain.com` | ❌ No | ✓ Yes |
| `MAIL_HOST` | Variable | `smtp.gmail.com` | ❌ No | ✓ Yes |
| `MAIL_USERNAME` | Variable | Your email | ❌ No | ✓ Yes |
| `MAIL_PASSWORD` | Variable | App password | ✓ Yes | ✓ Yes |

#### Generate Secrets Commands
```bash
# Laravel APP_KEY (run in Invoice Ninja project)
docker run --rm invoiceninja/invoiceninja:5 php artisan key:generate --show

# Strong passwords (use one of these)
openssl rand -base64 32
pwgen -s 32 1
LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32
```

---

### Phase 3: Terraform Infrastructure (Do This BEFORE First Deployment) ✨

#### 3.1 Update Terraform Variables
Edit `terraform/environments/prod/terraform.tfvars`:
```hcl
# Update these values
project_id = "YOUR_PROJECT_ID"
region     = "us-central1"
domain     = "yourdomain.com"

# Database configuration
db_password = "USE_VARIABLE_NOT_HARDCODED"  # Reference from variables

# Alert configuration
alert_email = "devops@yourcompany.com"
pagerduty_token = "your-pagerduty-token"  # Optional
slack_webhook = "your-slack-webhook"      # Optional
```

#### 3.2 Initialize and Apply Terraform
```bash
cd terraform/environments/prod

# Initialize Terraform
terraform init

# Review what will be created (IMPORTANT!)
terraform plan

# Apply infrastructure (takes 10-15 minutes)
terraform apply

# Save outputs (you'll need these)
terraform output > ../../terraform-outputs.txt
```

**What Terraform Creates**:
- ✅ Cloud SQL instance (PostgreSQL)
- ✅ VPC network and serverless connector
- ✅ Artifact Registry repository
- ✅ Secret Manager secrets
- ✅ IAM service accounts and roles
- ✅ Monitoring dashboards and alerts
- ✅ Cloud Storage buckets

---

### Phase 4: Domain & DNS (Optional but Recommended) 🌐

#### 4.1 Get Cloud Run Service URL
```bash
# After first deployment, get the URL
gcloud run services describe invoice-ninja-web \
  --region=us-central1 \
  --format="get(status.url)"

# Output: https://invoice-ninja-web-xxxxx-uc.a.run.app
```

#### 4.2 Configure Custom Domain
```bash
# Add your domain to Cloud Run
gcloud run domain-mappings create \
  --service=invoice-ninja-web \
  --domain=yourdomain.com \
  --region=us-central1

# Get DNS records to add
gcloud run domain-mappings describe \
  --domain=yourdomain.com \
  --region=us-central1

# Add these to your DNS provider:
# Type: A
# Name: @
# Value: (IP address from output)
#
# Type: AAAA
# Name: @
# Value: (IPv6 address from output)
```

---

### Phase 5: First Deployment (Deploy the App) 🚀

#### 5.1 Tag and Push to Trigger Pipeline
```bash
# In your Invoice Ninja project
git tag v1.0.0
git push origin v1.0.0

# This triggers GitLab CI/CD which will:
# 1. Build Docker images
# 2. Push to Artifact Registry
# 3. Deploy to Cloud Run
```

#### 5.2 Monitor Deployment
```bash
# Watch GitLab pipeline
# Go to: GitLab → CI/CD → Pipelines

# Or watch Cloud Run deployment
gcloud run services describe invoice-ninja-web \
  --region=us-central1 \
  --format="get(status.conditions)"
```

#### 5.3 Run Initial Database Migrations
```bash
# After first deployment, run migrations
gcloud run jobs execute db-migrations \
  --region=us-central1 \
  --wait

# Or run manually in Cloud Run
gcloud run services update invoice-ninja-web \
  --region=us-central1 \
  --command="php" \
  --args="artisan,migrate,--force"
```

---

## 🔍 What You DON'T Need to Configure Yet

These can wait until after successful deployment:

### ❌ Not Required Now
- ❌ PagerDuty integration (monitoring alerts work via email)
- ❌ Slack notifications (optional)
- ❌ OWASP ZAP DAST scanning (run manually first)
- ❌ SSL certificate (Cloud Run provides automatic HTTPS)
- ❌ Backup schedule (automatic daily backups enabled by Terraform)
- ❌ Log exports to BigQuery (already configured in Terraform)
- ❌ Budget alerts (already configured in Terraform)

---

## ✅ Quick Start: Minimum Required Steps

**If you want to deploy RIGHT NOW, do just these:**

```bash
# 1. Enable APIs (5 minutes)
gcloud services enable run.googleapis.com sql-component.googleapis.com \
  sqladmin.googleapis.com compute.googleapis.com vpcaccess.googleapis.com \
  servicenetworking.googleapis.com artifactregistry.googleapis.com \
  secretmanager.googleapis.com monitoring.googleapis.com

# 2. Create state bucket (1 minute)
gsutil mb -p YOUR_PROJECT_ID gs://YOUR_PROJECT_ID-terraform-state
gsutil versioning set on gs://YOUR_PROJECT_ID-terraform-state

# 3. Generate secrets (1 minute)
docker run --rm invoiceninja/invoiceninja:5 php artisan key:generate --show
openssl rand -base64 32  # DB password
openssl rand -base64 32  # Redis password

# 4. Add GitLab variables (5 minutes)
# - GCP_SERVICE_KEY (File)
# - GCP_PROJECT_ID
# - APP_KEY
# - DB_PASSWORD
# - REDIS_PASSWORD

# 5. Apply Terraform (15 minutes)
cd terraform/environments/prod
terraform init
terraform apply

# 6. Deploy (10 minutes)
git tag v1.0.0
git push origin v1.0.0
```

**Total time: ~40 minutes** ⏱️

---

## 📊 Verification After Setup

### Check Infrastructure
```bash
# Cloud Run service
gcloud run services list

# Cloud SQL
gcloud sql instances list

# Secrets
gcloud secrets list

# Monitoring
gcloud monitoring dashboards list
```

### Check Application
```bash
# Get service URL
gcloud run services describe invoice-ninja-web \
  --region=us-central1 \
  --format="get(status.url)"

# Test endpoint
curl https://invoice-ninja-web-xxxxx-uc.a.run.app/health

# Check logs
gcloud logging tail "resource.type=cloud_run_revision" --limit=50
```

---

## 🆘 Troubleshooting

### Issue: "API not enabled"
```bash
# Enable the specific API mentioned in the error
gcloud services enable API_NAME.googleapis.com
```

### Issue: "Permission denied"
```bash
# Check service account has correct roles
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:YOUR_SA_EMAIL"

# Should have: run.admin, cloudsql.client, secretmanager.admin
```

### Issue: "Terraform state locked"
```bash
# Force unlock (only if you're sure no one else is running terraform)
cd terraform/environments/prod
terraform force-unlock LOCK_ID
```

### Issue: "Database connection failed"
```bash
# Check VPC connector
gcloud compute networks vpc-access connectors list

# Check Cloud SQL status
gcloud sql instances describe INSTANCE_NAME

# Check secrets
gcloud secrets versions access latest --secret=db-password
```

---

## 📚 Related Documentation

- [Quick Reference Guide](QUICK_REFERENCE.md) - Common operations
- [Runbooks](RUNBOOKS/) - Incident response procedures
- [Phase 2 & 3 Summary](PHASE_2_3_COMPLETION_SUMMARY.md) - What we built

---

**Last Updated**: January 17, 2026  
**Next Review**: Before first production deployment  
**Owner**: DevOps Team
