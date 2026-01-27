# GitLab CI/CD Deployment Checklist

## ✅ Pre-Deployment Setup (Once Infrastructure is Ready)

### 1. Create GCP Artifact Registry Repository
```bash
gcloud artifacts repositories create invoiceninja \
  --repository-format=docker \
  --location=us-central1 \
  --description="Invoice Ninja Docker images"
```

### 2. Update GitLab Variables (.gitlab/variables/dev.yml)
Update the following values with actual terraform outputs:

```yaml
variables:
  GCP_PROJECT_ID: "invoice-ninja-prod"
  VPC_CONNECTOR: "in-dev-connector"  # From terraform output: vpc_connector_id
  SERVICE_ACCOUNT: "invoice-ninja-dev-run-sa@invoice-ninja-prod.iam.gserviceaccount.com"
  DB_INSTANCE: "invoice-ninja-dev-db"  # From terraform output: cloud_sql_instance_name
```

### 3. Update Deploy Template (.gitlab/ci-templates/deploy.yml)
Fix secret names to match what terraform created:
- `invoice-ninja-dev-app-key` (not `app-key`)
- `invoice-ninja-dev-db-password` (not `db-password`)
- `invoice-ninja-dev-smtp-password` (not `smtp-password`)
- `invoice-ninja-dev-stripe-key` (not `stripe-key`)

### 4. Configure Database Connection in Dockerfile/Entrypoint
Cloud Run will need these environment variables:
```env
DB_HOST=/cloudsql/invoice-ninja-prod:us-central1:invoice-ninja-dev-db
DB_DATABASE=invoiceninja
DB_USERNAME=invoiceninja
```

For Cloud SQL Unix socket connection:
- Update `docker/web/Dockerfile` to include Cloud SQL proxy support OR
- Use Cloud Run's built-in Cloud SQL connection: `--add-cloudsql-instances`

### 5. Grant Deployer Service Account Artifact Registry Access
```bash
gcloud artifacts repositories add-iam-policy-binding invoiceninja \
  --location=us-central1 \
  --member="serviceAccount:invoice-ninja-dev-deployer-sa@invoice-ninja-prod.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"
```

## 📋 Deployment Process

### Step 1: Test Local Docker Build
```bash
cd /home/otowo-samuel/Documents/Projects-2026/invoice-ninja-gcp-production
docker build -f docker/web/Dockerfile -t invoice-ninja-web:test .
docker run --rm invoice-ninja-web:test php artisan --version
```

### Step 2: Push to GitLab (Trigger Pipeline)
```bash
git add .
git commit -m "Configure dev environment for deployment"
git push origin develop
```

### Step 3: Monitor GitLab Pipeline
1. Go to GitLab → CI/CD → Pipelines
2. Watch stages: build → test → security → deploy
3. Check for errors in each job

### Step 4: Verify Deployment
```bash
# Get Cloud Run URL from terraform output
CLOUD_RUN_URL=$(cd terraform/environments/dev && terraform output -raw cloud_run_url)

# Test health endpoint
curl $CLOUD_RUN_URL/health

# Check logs
gcloud run services logs read invoice-ninja-web --region=us-central1 --limit=50
```

### Step 5: Run Database Migrations
```bash
# Get Cloud Run service name
SERVICE_NAME="invoice-ninja-web"

# Execute migration command
gcloud run jobs execute migrate-job \
  --region=us-central1 \
  --wait

# OR manually via console:
# Cloud Run → invoice-ninja-web → Logs → Filter for errors
```

## 🔍 Troubleshooting Commands

### Check Cloud Run Service Status
```bash
gcloud run services describe invoice-ninja-web \
  --region=us-central1 \
  --format=yaml
```

### View Cloud SQL Connection Details
```bash
gcloud sql instances describe invoice-ninja-dev-db \
  --format=yaml | grep -A 5 "connectionName\|ipAddresses"
```

### Test Database Connectivity
```bash
# Get private IP
PRIVATE_IP=$(cd terraform/environments/dev && terraform output -raw cloud_sql_private_ip)

# Test from Cloud Shell (if in VPC)
gcloud compute ssh test-vm --zone=us-central1-a --tunnel-through-iap
psql -h $PRIVATE_IP -U invoiceninja -d invoiceninja
```

### Check VPC Connector
```bash
gcloud compute networks vpc-access connectors describe in-dev-connector \
  --region=us-central1
```

### View Secrets
```bash
# List all secrets
gcloud secrets list

# View secret value (if you have access)
gcloud secrets versions access latest --secret="invoice-ninja-dev-app-key"
```

## ⚠️ Common Issues & Fixes

### Issue 1: "Permission denied" in GitLab pipeline
**Fix:** Ensure `GCP_SERVICE_KEY` variable contains valid service account JSON with:
- `roles/run.admin`
- `roles/artifactregistry.writer`
- `roles/iam.serviceAccountUser`

### Issue 2: "No configuration files" in deploy stage
**Fix:** Check that deploy template references correct image names:
```yaml
--image ${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/invoiceninja/web:${CI_COMMIT_SHA}
```

### Issue 3: Database connection timeout
**Fix:** Ensure Cloud Run has:
1. VPC connector attached: `--vpc-connector=in-dev-connector`
2. Cloud SQL instance connection: `--add-cloudsql-instances=invoice-ninja-prod:us-central1:invoice-ninja-dev-db`
3. Service account with `roles/cloudsql.client`

### Issue 4: "could not find driver" (PDO PostgreSQL)
**Fix:** Update Dockerfile to include `pdo_pgsql` extension:
```dockerfile
RUN docker-php-ext-install pdo pdo_pgsql pgsql
```

## 📝 Next Steps After Successful Deployment

1. **Set up Cloud Run Job for migrations:**
   - Create separate Cloud Run Job for `php artisan migrate`
   - Run before deploying new code versions

2. **Configure custom domain:**
   ```bash
   gcloud run domain-mappings create \
     --service=invoice-ninja-web \
     --domain=dev.invoiceninja.yourdomain.com
   ```

3. **Enable Cloud Armor (DDoS protection):**
   - Create security policy
   - Attach to Cloud Run service

4. **Set up backup verification:**
   - Test restore process
   - Verify automated backups running

5. **Configure logging & monitoring:**
   - Cloud Logging filters
   - Custom dashboards in Cloud Monitoring
   - Alert policies (already created by terraform)

## 🚀 Production Promotion (After Dev Success)

1. Copy dev configuration to staging
2. Test full deployment workflow
3. Update production terraform with:
   - `deletion_protection = true`
   - Larger instance tier (db-g1-small minimum)
   - Higher min_instances (2+)
   - REGIONAL availability (HA)
4. Implement blue-green deployment
5. Set up CloudCDN for static assets
