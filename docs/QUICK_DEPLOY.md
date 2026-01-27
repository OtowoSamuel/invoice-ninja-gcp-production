# Quick Deploy Commands - Invoice Ninja Dev

## 🚀 Fast Track: Deploy Now

### Option 1: Push to GitLab (Automated Pipeline) ⭐ RECOMMENDED
```bash
cd /home/otowo-samuel/Documents/Projects-2026/invoice-ninja-gcp-production

git add .
git commit -m "Configure Invoice Ninja dev deployment"
git push origin develop

# Watch pipeline: https://gitlab.com/YOUR_USERNAME/YOUR_REPO/-/pipelines
```

### Option 2: Manual Docker Build & Deploy
```bash
cd /home/otowo-samuel/Documents/Projects-2026/invoice-ninja-gcp-production

# 1. Authenticate
gcloud auth configure-docker us-central1-docker.pkg.dev

# 2. Build image
docker build -f docker/web/Dockerfile \
  -t us-central1-docker.pkg.dev/invoice-ninja-prod/invoiceninja/web:v1.0 \
  .

# 3. Push image (takes 5-10 min)
docker push us-central1-docker.pkg.dev/invoice-ninja-prod/invoiceninja/web:v1.0

# 4. Deploy to Cloud Run
gcloud run deploy invoice-ninja-web \
  --image us-central1-docker.pkg.dev/invoice-ninja-prod/invoiceninja/web:v1.0 \
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
  --timeout 300 \
  --service-account invoice-ninja-dev-run-sa@invoice-ninja-prod.iam.gserviceaccount.com

# 5. Open app
open https://invoice-ninja-web-lahu6cymfa-uc.a.run.app
```

---

## 🔍 Check Status

```bash
# Cloud Run service
gcloud run services describe invoice-ninja-web --region=us-central1

# Logs (last 50 lines)
gcloud run services logs read invoice-ninja-web --region=us-central1 --limit=50

# Database
gcloud sql instances describe invoice-ninja-dev-db

# Secrets
gcloud secrets list | grep invoice-ninja-dev
```

---

## 🗄️ Database Access

```bash
# Connect via gcloud
gcloud sql connect invoice-ninja-dev-db --user=invoiceninja

# Get password
gcloud secrets versions access latest --secret=invoice-ninja-dev-db-password

# Inside psql:
\l                    # List databases
\c invoiceninja       # Connect to database
\dt                   # List tables
SELECT * FROM migrations;  # Check migrations ran
```

---

## 🐛 Debug Issues

```bash
# Stream logs live
gcloud run services logs tail invoice-ninja-web --region=us-central1

# Check container startup
gcloud run revisions list --service invoice-ninja-web --region=us-central1

# Test database from Cloud Shell
PGPASSWORD=$(gcloud secrets versions access latest --secret=invoice-ninja-dev-db-password) \
psql -h 10.215.0.3 -U invoiceninja -d invoiceninja

# Check VPC connector
gcloud compute networks vpc-access connectors describe in-dev-connector --region=us-central1
```

---

## 📊 View Monitoring

```bash
# Dashboard
echo "https://console.cloud.google.com/monitoring/dashboards?project=invoice-ninja-prod"

# Recent errors
gcloud logging read "resource.type=cloud_run_revision AND severity>=ERROR" --limit=20 --format=json

# Alert policies
gcloud alpha monitoring policies list
```

---

## 🔄 Update Application

```bash
# Rebuild and deploy new version
docker build -f docker/web/Dockerfile \
  -t us-central1-docker.pkg.dev/invoice-ninja-prod/invoiceninja/web:v1.1 \
  .

docker push us-central1-docker.pkg.dev/invoice-ninja-prod/invoiceninja/web:v1.1

gcloud run deploy invoice-ninja-web \
  --image us-central1-docker.pkg.dev/invoice-ninja-prod/invoiceninja/web:v1.1 \
  --region us-central1
```

---

## 🚨 Rollback

```bash
# List revisions
gcloud run revisions list --service invoice-ninja-web --region=us-central1

# Route traffic to previous revision
gcloud run services update-traffic invoice-ninja-web \
  --to-revisions=invoice-ninja-web-00001-abc=100 \
  --region=us-central1
```

---

## 🧹 Teardown (Clean Up)

```bash
cd /home/otowo-samuel/Documents/Projects-2026/invoice-ninja-gcp-production/terraform/environments/dev

terraform destroy -auto-approve

# Delete Artifact Registry
gcloud artifacts repositories delete invoiceninja --location=us-central1
```

---

## 📱 URLs

- **App:** https://invoice-ninja-web-lahu6cymfa-uc.a.run.app
- **GCP Console:** https://console.cloud.google.com/run?project=invoice-ninja-prod
- **Cloud SQL:** https://console.cloud.google.com/sql/instances?project=invoice-ninja-prod
- **Secrets:** https://console.cloud.google.com/security/secret-manager?project=invoice-ninja-prod
- **Monitoring:** https://console.cloud.google.com/monitoring?project=invoice-ninja-prod

---

## 🆘 Emergency Contacts

- **Cloud SQL Connection:** `invoice-ninja-prod:us-central1:invoice-ninja-dev-db`
- **Service Account:** `invoice-ninja-dev-run-sa@invoice-ninja-prod.iam.gserviceaccount.com`
- **Alert Email:** `samuelosei25@gmail.com`
- **VPC Connector:** `in-dev-connector`
- **Database IP:** `10.215.0.3` (private only)
