# Quick Reference Guide - Common Operations

Quick commands and procedures for day-to-day operations.

---

## Monitoring & Alerting

### Check Current System Health
```bash
# View monitoring dashboard
https://console.cloud.google.com/monitoring/dashboards?project=PROJECT_ID

# Check SLO compliance
gcloud monitoring dashboards list --project=PROJECT_ID

# View recent alerts
gcloud alpha monitoring policies list \
  --filter="enabled=true" \
  --project=PROJECT_ID
```

### View Recent Errors
```bash
# Last 50 application errors
gcloud logging read \
  'resource.type="cloud_run_revision" AND severity>=ERROR' \
  --limit=50 \
  --format=json \
  --project=PROJECT_ID

# Group errors by type
gcloud logging read \
  'resource.type="cloud_run_revision" AND severity>=ERROR' \
  --limit=100 \
  --format=json \
  --project=PROJECT_ID | \
  jq -r '.[] | .jsonPayload.message' | \
  sort | uniq -c | sort -rn
```

### Check Error Rate
```bash
# Current error rate
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/request_count" AND metric.labels.response_code_class="5xx"' \
  --project=PROJECT_ID
```

---

## Deployments

### Deploy New Version
```bash
# Via GitLab CI/CD (recommended)
git tag v2.5.1
git push origin v2.5.1

# Manual deployment (emergency)
gcloud run deploy invoice-ninja-web \
  --image=REGION-docker.pkg.dev/PROJECT_ID/invoiceninja/web:TAG \
  --region=REGION \
  --project=PROJECT_ID
```

### Check Deployment Status
```bash
# List recent revisions
gcloud run revisions list \
  --service=invoice-ninja-web \
  --region=REGION \
  --project=PROJECT_ID \
  --limit=5

# Check revision status
gcloud run revisions describe REVISION_NAME \
  --region=REGION \
  --project=PROJECT_ID \
  --format="table(status.conditions[].type, status.conditions[].status)"
```

### Rollback Deployment
```bash
# Get previous revision
PREVIOUS=$(gcloud run revisions list \
  --service=invoice-ninja-web \
  --region=REGION \
  --limit=2 \
  --format="value(metadata.name)" | tail -1)

# Rollback
gcloud run services update-traffic invoice-ninja-web \
  --to-revisions=$PREVIOUS=100 \
  --region=REGION \
  --project=PROJECT_ID

# Verify
gcloud run services describe invoice-ninja-web \
  --region=REGION \
  --project=PROJECT_ID \
  --format="table(status.traffic[])"
```

### Gradual Traffic Shift (Canary)
```bash
# Split traffic: 90% old, 10% new
gcloud run services update-traffic invoice-ninja-web \
  --to-revisions=REVISION_OLD=90,REVISION_NEW=10 \
  --region=REGION \
  --project=PROJECT_ID

# Increase to 50/50
gcloud run services update-traffic invoice-ninja-web \
  --to-revisions=REVISION_OLD=50,REVISION_NEW=50 \
  --region=REGION \
  --project=PROJECT_ID

# Full cutover to new
gcloud run services update-traffic invoice-ninja-web \
  --to-revisions=REVISION_NEW=100 \
  --region=REGION \
  --project=PROJECT_ID
```

---

## Database Operations

### Check Database Status
```bash
# Instance status
gcloud sql instances describe INSTANCE_NAME \
  --project=PROJECT_ID \
  --format="get(state, settings.tier)"

# Current connections
gcloud monitoring time-series list \
  --filter='metric.type="cloudsql.googleapis.com/database/mysql/connections"' \
  --project=PROJECT_ID
```

### Database Backup

#### Create On-Demand Backup
```bash
gcloud sql backups create \
  --instance=INSTANCE_NAME \
  --description="Pre-migration backup" \
  --project=PROJECT_ID
```

#### List Backups
```bash
gcloud sql backups list \
  --instance=INSTANCE_NAME \
  --project=PROJECT_ID \
  --format="table(id, windowStartTime, status)"
```

#### Restore from Backup
```bash
# Restore to new instance (safest)
gcloud sql backups restore BACKUP_ID \
  --backup-instance=INSTANCE_NAME \
  --restore-instance=INSTANCE_NAME-restore \
  --project=PROJECT_ID

# Point-in-time recovery
gcloud sql backups restore BACKUP_ID \
  --backup-instance=INSTANCE_NAME \
  --restore-instance=INSTANCE_NAME-pitr \
  --point-in-time=2026-01-17T10:30:00Z \
  --project=PROJECT_ID
```

### Database Maintenance

#### Connect to Database
```bash
# Via gcloud (recommended)
gcloud sql connect INSTANCE_NAME \
  --user=root \
  --project=PROJECT_ID

# Get connection info
gcloud sql instances describe INSTANCE_NAME \
  --format="get(ipAddresses[0].ipAddress)" \
  --project=PROJECT_ID
```

#### Run Migrations
```bash
# Via Cloud Run job
gcloud run jobs execute db-migrations \
  --region=REGION \
  --project=PROJECT_ID \
  --wait

# Monitor migration logs
gcloud logging tail \
  "resource.type=cloud_run_job" \
  --project=PROJECT_ID
```

---

## Secrets Management

### View Secrets
```bash
# List all secrets
gcloud secrets list --project=PROJECT_ID

# Get secret value
gcloud secrets versions access latest \
  --secret="app-key" \
  --project=PROJECT_ID
```

### Update Secret
```bash
# From file
gcloud secrets versions add app-key \
  --data-file=/path/to/new-key.txt \
  --project=PROJECT_ID

# From stdin
echo -n "NEW_SECRET_VALUE" | \
  gcloud secrets versions add app-key \
    --data-file=- \
    --project=PROJECT_ID

# After updating, restart service
gcloud run services update invoice-ninja-web \
  --region=REGION \
  --project=PROJECT_ID
```

### Rotate Secret
```bash
# 1. Create new version
echo -n "NEW_PASSWORD" | \
  gcloud secrets versions add db-password \
    --data-file=- \
    --project=PROJECT_ID

# 2. Update database password
gcloud sql users set-password DB_USER \
  --instance=INSTANCE_NAME \
  --password=NEW_PASSWORD \
  --project=PROJECT_ID

# 3. Restart application
gcloud run services update invoice-ninja-web \
  --region=REGION \
  --project=PROJECT_ID

# 4. Disable old secret version (after verification)
gcloud secrets versions disable VERSION_NUMBER \
  --secret="db-password" \
  --project=PROJECT_ID
```

---

## Scaling Operations

### Manual Scaling
```bash
# Scale up
gcloud run services update invoice-ninja-web \
  --min-instances=5 \
  --max-instances=50 \
  --region=REGION \
  --project=PROJECT_ID

# Scale down
gcloud run services update invoice-ninja-web \
  --min-instances=1 \
  --max-instances=10 \
  --region=REGION \
  --project=PROJECT_ID
```

### Update Resources
```bash
# Increase memory/CPU
gcloud run services update invoice-ninja-web \
  --memory=1Gi \
  --cpu=2 \
  --region=REGION \
  --project=PROJECT_ID

# Update concurrency
gcloud run services update invoice-ninja-web \
  --concurrency=100 \
  --region=REGION \
  --project=PROJECT_ID
```

### Check Autoscaling
```bash
# Current instance count
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/container/instance_count"' \
  --project=PROJECT_ID

# CPU utilization
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/container/cpu/utilizations"' \
  --project=PROJECT_ID
```

---

## Logging

### Tail Logs (Live)
```bash
# All Cloud Run logs
gcloud logging tail \
  "resource.type=cloud_run_revision" \
  --project=PROJECT_ID

# Filter by severity
gcloud logging tail \
  "resource.type=cloud_run_revision AND severity>=ERROR" \
  --project=PROJECT_ID

# Specific service
gcloud logging tail \
  "resource.type=cloud_run_revision AND resource.labels.service_name=invoice-ninja-web" \
  --project=PROJECT_ID
```

### Search Historical Logs
```bash
# Last hour of errors
gcloud logging read \
  'resource.type="cloud_run_revision" AND severity>=ERROR AND timestamp>="2026-01-17T10:00:00Z"' \
  --limit=100 \
  --format=json \
  --project=PROJECT_ID

# Search by text
gcloud logging read \
  'resource.type="cloud_run_revision" AND textPayload=~"payment failed"' \
  --limit=50 \
  --project=PROJECT_ID

# Export logs to file
gcloud logging read \
  'resource.type="cloud_run_revision" AND severity>=ERROR' \
  --limit=1000 \
  --format=json \
  --project=PROJECT_ID > errors.json
```

### Database Logs
```bash
# Slow queries
gcloud logging read \
  'resource.type="cloudsql_database" AND jsonPayload.message=~"slow query"' \
  --limit=20 \
  --project=PROJECT_ID

# Connection issues
gcloud logging read \
  'resource.type="cloudsql_database" AND textPayload=~"connection"' \
  --limit=50 \
  --project=PROJECT_ID
```

---

## Security Operations

### Check IAM Permissions
```bash
# List service account permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:SA_EMAIL"

# Check who has access to a resource
gcloud run services get-iam-policy invoice-ninja-web \
  --region=REGION \
  --project=PROJECT_ID
```

### Audit Log Review
```bash
# IAM changes
gcloud logging read \
  'protoPayload.@type="type.googleapis.com/google.cloud.audit.AuditLog" AND protoPayload.methodName=~"iam.googleapis.com"' \
  --limit=50 \
  --project=PROJECT_ID

# Secret access
gcloud logging read \
  'protoPayload.@type="type.googleapis.com/google.cloud.audit.AuditLog" AND protoPayload.methodName=~"secretmanager.googleapis.com"' \
  --limit=50 \
  --project=PROJECT_ID
```

### Rotate Service Account Keys
```bash
# Create new key
gcloud iam service-accounts keys create new-key.json \
  --iam-account=SA_EMAIL \
  --project=PROJECT_ID

# List keys
gcloud iam service-accounts keys list \
  --iam-account=SA_EMAIL \
  --project=PROJECT_ID

# Delete old key (after updating GitLab)
gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=SA_EMAIL \
  --project=PROJECT_ID
```

---

## Cost Management

### Check Current Costs
```bash
# View billing dashboard
https://console.cloud.google.com/billing/PROJECT_ID

# Export billing data
gcloud billing accounts list

# Check budget alerts
gcloud billing budgets list \
  --billing-account=BILLING_ACCOUNT_ID
```

### Cost Optimization

#### Stop Dev/Staging Database
```bash
# Stop (saves compute costs)
gcloud sql instances patch INSTANCE_NAME-dev \
  --activation-policy=NEVER \
  --project=PROJECT_ID

# Start when needed
gcloud sql instances patch INSTANCE_NAME-dev \
  --activation-policy=ALWAYS \
  --project=PROJECT_ID
```

#### Scale Down Development
```bash
# Reduce dev environment resources
gcloud run services update invoice-ninja-web-dev \
  --min-instances=0 \
  --max-instances=2 \
  --memory=256Mi \
  --cpu=1 \
  --region=REGION \
  --project=PROJECT_ID
```

---

## Incident Response

### Quick Incident Check
```bash
# 1. Check error rate
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/request_count" AND metric.labels.response_code_class="5xx"' \
  --project=PROJECT_ID

# 2. Check service status
gcloud run services list \
  --region=REGION \
  --project=PROJECT_ID \
  --format="table(metadata.name, status.conditions[].status)"

# 3. Check database
gcloud sql instances describe INSTANCE_NAME \
  --format="get(state)" \
  --project=PROJECT_ID

# 4. Recent errors
gcloud logging read \
  'resource.type="cloud_run_revision" AND severity>=ERROR' \
  --limit=20 \
  --project=PROJECT_ID
```

### Emergency Rollback
```bash
# One-liner rollback
PREV=$(gcloud run revisions list --service=invoice-ninja-web --region=REGION --limit=2 --format="value(metadata.name)" | tail -1) && \
gcloud run services update-traffic invoice-ninja-web --to-revisions=$PREV=100 --region=REGION --project=PROJECT_ID
```

### Enable Maintenance Mode
```bash
# Route all traffic to maintenance revision
gcloud run services update-traffic invoice-ninja-web \
  --to-revisions=invoice-ninja-web-maintenance=100 \
  --region=REGION \
  --project=PROJECT_ID
```

---

## Useful Aliases

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
# Project
export GCP_PROJECT="invoice-ninja-prod"
export GCP_REGION="us-central1"

# Aliases
alias gcpset='gcloud config set project $GCP_PROJECT'
alias gcplogs='gcloud logging tail "resource.type=cloud_run_revision" --project=$GCP_PROJECT'
alias gcperrors='gcloud logging read "resource.type=cloud_run_revision AND severity>=ERROR" --limit=50 --project=$GCP_PROJECT'
alias gcpstatus='gcloud run services list --region=$GCP_REGION --project=$GCP_PROJECT'
alias gcpdb='gcloud sql connect invoice-ninja-prod-db --user=root --project=$GCP_PROJECT'
alias gcprollback='PREV=$(gcloud run revisions list --service=invoice-ninja-web --region=$GCP_REGION --limit=2 --format="value(metadata.name)" | tail -1) && gcloud run services update-traffic invoice-ninja-web --to-revisions=$PREV=100 --region=$GCP_REGION --project=$GCP_PROJECT'
```

---

## Emergency Contacts

**On-Call Engineers**:
- Primary: Slack @devops-oncall, PagerDuty
- Secondary: Slack @senior-devops

**Escalation**:
- Engineering Manager: @eng-manager
- CTO: @cto

**Vendor Support**:
- GCP Support: Console → Support → New Case (P1 for SEV1)
- GitLab Support: support@gitlab.com

---

## Useful Links

- Monitoring Dashboard: https://console.cloud.google.com/monitoring/dashboards?project=PROJECT_ID
- Cloud Run Services: https://console.cloud.google.com/run?project=PROJECT_ID
- Cloud SQL Instances: https://console.cloud.google.com/sql/instances?project=PROJECT_ID
- Secrets: https://console.cloud.google.com/security/secret-manager?project=PROJECT_ID
- GitLab CI/CD: https://gitlab.com/ORG/invoice-ninja-gcp-production/pipelines
- Logs Explorer: https://console.cloud.google.com/logs/query?project=PROJECT_ID
- Error Reporting: https://console.cloud.google.com/errors?project=PROJECT_ID

---

**Last Updated**: 2026-01-17  
**Review Frequency**: Monthly  
**Owner**: DevOps Team
