# 🎉 Dev Infrastructure Deployment Complete!

## ✅ Successfully Created Resources (36 total)

### Terraform Outputs
```
cloud_run_url              = https://invoice-ninja-web-lahu6cymfa-uc.a.run.app
cloud_sql_connection_name  = invoice-ninja-prod:us-central1:invoice-ninja-dev-db
cloud_sql_instance_name    = invoice-ninja-dev-db
service_account_email      = invoice-ninja-dev-run-sa@invoice-ninja-prod.iam.gserviceaccount.com
vpc_connector_id           = projects/invoice-ninja-prod/locations/us-central1/connectors/in-dev-connector
```

### Infrastructure Components

#### 🔐 Security & Secrets
- ✅ **Secret Manager Secrets:**
  - `invoice-ninja-dev-app-key` (Laravel APP_KEY)
  - `invoice-ninja-dev-db-password` (PostgreSQL password)
  - `invoice-ninja-dev-smtp-password` (Email SMTP)
  - `invoice-ninja-dev-stripe-key` (Payment processing)

#### 👤 IAM Service Accounts
- ✅ `invoice-ninja-dev-run-sa` - Cloud Run execution (SQL client, Storage, Secrets)
- ✅ `invoice-ninja-dev-worker-sa` - Background workers (SQL client, Storage, Secrets)  
- ✅ `invoice-ninja-dev-deployer-sa` - GitLab CI/CD deployments (Run admin, Artifact Registry writer)

#### 🗄️ Database
- ✅ **Cloud SQL PostgreSQL 15**
  - Instance: `invoice-ninja-dev-db`
  - Tier: db-f1-micro (613MB RAM, 1 shared vCPU)
  - Private IP only: 10.215.0.3 (no public access)
  - SSL mode: ENCRYPTED_ONLY
  - Automated backups: Daily at 2 AM, 7 retained
  - Database: `invoiceninja`
  - User: `invoiceninja`
  - Settings:
    - shared_buffers: 64MB
    - effective_cache_size: 80MB
    - max_connections: 100
  - **Deletion protection: DISABLED** (dev only)

#### 🌐 Networking
- ✅ VPC: `invoice-ninja-dev-vpc` (custom mode)
- ✅ VPC Connector: `in-dev-connector`
  - Subnet: 10.8.0.0/28 (16 IPs)
  - Min instances: 2
  - Max instances: 3
  - Machine type: e2-micro
- ✅ Private Service Connection for Cloud SQL
- ✅ Firewall: Allow health checks from 35.191.0.0/16, 130.211.0.0/22

#### ☁️ Cloud Run
- ✅ **Service: `invoice-ninja-web`**
  - URL: https://invoice-ninja-web-lahu6cymfa-uc.a.run.app
  - Currently running: gcr.io/cloudrun/hello (placeholder)
  - Memory: 512Mi
  - CPU: 1
  - Min instances: 0 (scale to zero)
  - Max instances: 5
  - Concurrency: 80 requests/container
  - Timeout: 300 seconds (5 minutes)
  - **Publicly accessible** (allow-unauthenticated)
  - VPC connector attached
  - Cloud SQL connection configured

#### 📊 Monitoring
- ✅ Notification channel: Email to `samuelosei25@gmail.com`
- ✅ Alert: High error rate (>5% for 5 minutes)
- ✅ Alert: High latency (>2s p95 for 5 minutes)
- ✅ Dashboard: Invoice Ninja Dev Environment

#### 🐳 Container Registry
- ✅ **Artifact Registry Repository: `invoiceninja`**
  - Location: us-central1
  - Format: Docker
  - IAM: deployer-sa has Writer role
  - Ready to receive images

---

## 🚀 Next Steps: Deploy Invoice Ninja Application

### 1. Update GitLab CI/CD Variables (ALREADY DONE)
- ✅ `.gitlab/variables/dev.yml` updated with:
  - GCP_PROJECT_ID: invoice-ninja-prod
  - VPC_CONNECTOR: in-dev-connector
  - SERVICE_ACCOUNT: invoice-ninja-dev-run-sa@invoice-ninja-prod.iam.gserviceaccount.com
  - DB_CONNECTION_NAME: invoice-ninja-prod:us-central1:invoice-ninja-dev-db

### 2. Docker Configuration (ALREADY DONE)
- ✅ Created `docker/web/entrypoint.sh` - Cloud SQL connection, migrations, caching
- ✅ Updated `docker/web/Dockerfile` - Added entrypoint script
- ✅ Deploy template updated - Correct secret names, Cloud SQL connection

### 3. Test Local Docker Build
```bash
cd /home/otowo-samuel/Documents/Projects-2026/invoice-ninja-gcp-production

# Build web image
docker build -f docker/web/Dockerfile -t invoice-ninja-web:test .

# Test if it starts
docker run --rm \
  -e APP_KEY=base64:YprFxC7bdv/7J+Rf2dLE4qxbPahxIiSz6g45GheetLM= \
  -e DB_CONNECTION=pgsql \
  -p 8080:8080 \
  invoice-ninja-web:test
```

Expected output: Nginx starts, PHP-FPM running, Laravel ready

### 4. Build & Push via GitLab CI/CD

#### Option A: Manual Push from Local Machine
```bash
# Authenticate to Artifact Registry
gcloud auth configure-docker us-central1-docker.pkg.dev

# Build and tag
docker build -f docker/web/Dockerfile \
  -t us-central1-docker.pkg.dev/invoice-ninja-prod/invoiceninja/web:v1.0 \
  .

# Push
docker push us-central1-docker.pkg.dev/invoice-ninja-prod/invoiceninja/web:v1.0
```

#### Option B: Push to GitLab (Recommended - Full CI/CD)
```bash
cd /home/otowo-samuel/Documents/Projects-2026/invoice-ninja-gcp-production

# Stage changes
git add .
git commit -m "feat: configure dev environment for Invoice Ninja deployment

- Updated GitLab CI/CD variables with actual GCP values
- Created entrypoint.sh for Cloud SQL connection and Laravel setup
- Updated deploy template with correct secret names
- Configured Dockerfile to use entrypoint script

Refs: GITLAB_DEPLOY_CHECKLIST.md"

# Push to develop branch (triggers pipeline)
git push origin develop
```

### 5. Monitor GitLab Pipeline
1. Go to GitLab: **CI/CD → Pipelines**
2. Watch stages execute:
   - **build** - Docker image built and pushed to Artifact Registry (~5-10 min)
   - **test** - PHPUnit tests, code quality checks (~2-5 min)
   - **security** - Trivy scan, dependency check (~3-5 min)
   - **deploy** - Cloud Run service updated with new image (~1-2 min)
   
Expected errors on first run:
- ❌ Tests might fail (database connection needed)
- ✅ Build should succeed
- ✅ Deploy should succeed (but app won't work yet)

### 6. Deploy Cloud Run with Real Image
Once image is built, update Cloud Run manually first:

```bash
# Get latest image tag from Artifact Registry
gcloud artifacts docker images list us-central1-docker.pkg.dev/invoice-ninja-prod/invoiceninja/web

# Deploy to Cloud Run
gcloud run deploy invoice-ninja-web \
  --image us-central1-docker.pkg.dev/invoice-ninja-prod/invoiceninja/web:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --vpc-connector in-dev-connector \
  --add-cloudsql-instances invoice-ninja-prod:us-central1:invoice-ninja-dev-db \
  --set-env-vars="APP_ENV=local,APP_DEBUG=true,DB_CONNECTION=pgsql,DB_DATABASE=invoiceninja,DB_USERNAME=invoiceninja,RUN_MIGRATIONS=true" \
  --set-secrets="APP_KEY=invoice-ninja-dev-app-key:latest,DB_PASSWORD=invoice-ninja-dev-db-password:latest" \
  --memory 512Mi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 5 \
  --service-account invoice-ninja-dev-run-sa@invoice-ninja-prod.iam.gserviceaccount.com
```

### 7. Verify Deployment
```bash
# Check Cloud Run logs
gcloud run services logs read invoice-ninja-web \
  --region=us-central1 \
  --limit=50 \
  --format=json

# Test health endpoint
curl https://invoice-ninja-web-lahu6cymfa-uc.a.run.app/health

# Test Invoice Ninja UI
curl https://invoice-ninja-web-lahu6cymfa-uc.a.run.app/setup

# Check database connection
gcloud sql connect invoice-ninja-dev-db --user=invoiceninja
# Password from secret: gcloud secrets versions access latest --secret=invoice-ninja-dev-db-password
\l  # List databases
\c invoiceninja  # Connect to database
\dt  # List tables (should see Laravel migrations)
```

### 8. Complete Invoice Ninja Setup
1. Open: https://invoice-ninja-web-lahu6cymfa-uc.a.run.app
2. Follow setup wizard:
   - Database already configured (automatic via entrypoint.sh)
   - Create admin user
   - Configure email settings (use SMTP secret)
   - Configure payment gateway (use Stripe secret)

### 9. Configure GitLab for Continuous Deployment
Once manual deploy works, GitLab CI/CD will handle future deployments:

**.gitlab-ci.yml workflow:**
1. Developer pushes to `develop` branch
2. Pipeline builds Docker image
3. Runs tests
4. Scans for vulnerabilities
5. Deploys to dev environment
6. Sends notification

**For staging/production:**
- Merge `develop` → `staging` → deploy to staging
- Merge `staging` → `main` → deploy to production (manual approval)

---

## 📊 Cost Estimate (Dev Environment)

| Resource | Tier | Monthly Cost (USD) |
|----------|------|-------------------|
| Cloud SQL (db-f1-micro) | 613MB RAM, 0.6 vCPU | ~$7.66 |
| Cloud SQL storage (10GB SSD) | Standard | ~$1.70 |
| Cloud Run (scale to zero) | 512Mi, 1 CPU | ~$0 (free tier) |
| VPC Connector (e2-micro x2) | Min 2 instances | ~$8.76 |
| Artifact Registry storage | <10GB | ~$0.10 |
| Secret Manager | 4 secrets, few accesses | ~$0.06 |
| Cloud Monitoring | Basic metrics | Free |
| **Total** | | **~$18.28/month** |

*Note: With free tier credits, actual cost may be $0 for first 3 months*

---

## 🔒 Security Checklist

- ✅ Database: Private IP only (no public access)
- ✅ SSL/TLS: Enforced for Cloud SQL connections
- ✅ Secrets: Stored in Secret Manager (not environment variables)
- ✅ IAM: Least-privilege service accounts (no owner/editor roles)
- ✅ Backups: Automated daily backups (7 retained)
- ✅ Monitoring: Alerts configured for errors and latency
- ✅ Firewall: Restricted to health check ranges only
- ✅ Container: Running as non-root user (invoiceninja:1000)
- ⚠️ **TODO:** Enable Cloud Armor for DDoS protection
- ⚠️ **TODO:** Configure WAF rules for web application firewall
- ⚠️ **TODO:** Set up Redis/Memorystore for session storage

---

## 📖 Documentation & Runbooks

See these files for detailed procedures:

1. **GITLAB_DEPLOY_CHECKLIST.md** - Step-by-step deployment guide
2. **docs/runbooks/INCIDENT_RESPONSE.md** - How to handle production incidents
3. **docs/runbooks/BACKUP_RESTORE.md** - Database backup and recovery procedures
4. **docs/runbooks/ROLLBACK.md** - How to rollback failed deployments
5. **docs/guides/MONITORING.md** - Monitoring and alerting setup

---

## 🐛 Troubleshooting

### Issue: Container fails to start
**Check logs:**
```bash
gcloud run services logs read invoice-ninja-web --region=us-central1 --limit=100
```

**Common causes:**
- Missing APP_KEY (check secret)
- Database connection failed (check VPC connector, Cloud SQL instance)
- PHP extensions missing (check Dockerfile)
- Permission denied (check service account IAM roles)

### Issue: Database connection timeout
**Verify connectivity:**
```bash
# Check VPC connector status
gcloud compute networks vpc-access connectors describe in-dev-connector --region=us-central1

# Check Cloud SQL instance
gcloud sql instances describe invoice-ninja-dev-db

# Check service account roles
gcloud projects get-iam-policy invoice-ninja-prod \
  --flatten="bindings[].members" \
  --filter="bindings.members:invoice-ninja-dev-run-sa@*"
```

**Fix:**
1. Ensure Cloud Run has `--add-cloudsql-instances` flag
2. Ensure VPC connector is attached
3. Ensure service account has `roles/cloudsql.client`

### Issue: "Permission denied" accessing secrets
**Check IAM:**
```bash
gcloud secrets get-iam-policy invoice-ninja-dev-app-key

# Should show: invoice-ninja-dev-run-sa with roles/secretmanager.secretAccessor
```

**Fix:**
```bash
gcloud secrets add-iam-policy-binding invoice-ninja-dev-app-key \
  --member="serviceAccount:invoice-ninja-dev-run-sa@invoice-ninja-prod.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

---

## 🎓 What You Learned

1. **Terraform Infrastructure as Code:**
   - Modular architecture (networking, iam, secrets, cloud-sql, cloud-run, monitoring)
   - State management with GCS backend
   - Resource dependencies and outputs
   - Multi-environment configuration

2. **GCP Cloud SQL:**
   - Private IP networking
   - SSL/TLS encryption
   - Automated backups
   - Database flags tuning for small instances

3. **Cloud Run:**
   - Serverless containers
   - VPC connector for private network access
   - Cloud SQL connections
   - Secret Manager integration
   - Service accounts and IAM

4. **GitLab CI/CD:**
   - Multi-stage pipelines (build, test, security, deploy)
   - Reusable templates
   - Environment-specific variables
   - Blue-green deployments

5. **Docker Best Practices:**
   - Multi-stage builds (composer, node, production)
   - Layer caching optimization
   - Non-root user execution
   - Health checks
   - Entrypoint scripts for initialization

6. **Security:**
   - Secret Manager for credentials
   - Least-privilege IAM
   - Private networking
   - Encryption in transit and at rest

---

## 🚦 Current Status

| Component | Status | Next Action |
|-----------|--------|-------------|
| Infrastructure | ✅ READY | N/A |
| Artifact Registry | ✅ READY | Push first image |
| GitLab CI/CD Config | ✅ READY | Test pipeline |
| Docker Images | ⏳ PENDING | Build and push |
| Application Deployment | ⏳ PENDING | Deploy to Cloud Run |
| Database Migrations | ⏳ PENDING | Run after first deploy |
| Invoice Ninja Setup | ⏳ PENDING | Complete web setup wizard |

**You are here:** 🎯 Ready to build and deploy Invoice Ninja application!

**Estimated time to working app:** 15-30 minutes
- Build Docker image: 5-10 min
- Push to Artifact Registry: 2-5 min  
- Deploy to Cloud Run: 1-2 min
- Run migrations: 1 min
- Test application: 5 min
