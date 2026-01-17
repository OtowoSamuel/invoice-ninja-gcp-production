# =============================================================================
# Backup & Disaster Recovery Strategy
# Learn: RTO/RPO, backup strategies, DR procedures
# =============================================================================

## Recovery Objectives

### RTO (Recovery Time Objective)

| Scenario | Target RTO | Maximum Downtime |
|----------|-----------|------------------|
| Application failure | 5 minutes | Automatic rollback |
| Database failure | 15 minutes | Failover to replica |
| Region outage | 30 minutes | Cross-region failover |
| Data corruption | 1 hour | Point-in-time restore |
| Complete disaster | 4 hours | Full rebuild |

### RPO (Recovery Point Objective)

| Data Type | Target RPO | Maximum Data Loss |
|-----------|-----------|------------------|
| Transactional data | <1 minute | Last committed transaction |
| User uploads | <5 minutes | Recent uploads |
| Configuration | <1 hour | Recent config changes |
| Logs/metrics | <15 minutes | Recent logs |

## Backup Strategy

### 1. Cloud SQL Automated Backups

```bash
# Enable automated backups with 7-day retention
gcloud sql instances patch invoiceninja-db \
  --backup-start-time=03:00 \
  --backup-location=us \
  --retained-backups-count=7 \
  --transaction-log-retention-days=7 \
  --enable-point-in-time-recovery

# Enable binary logging for PITR
gcloud sql instances patch invoiceninja-db \
  --database-flags=cloudsql.enable_pgaudit=on
```

### 2. On-Demand Backups

```bash
#!/bin/bash
# scripts/backup/create-backup.sh
# Run before major changes

PROJECT_ID="invoice-ninja-prod"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="manual-backup-${TIMESTAMP}"

echo "Creating on-demand backup..."
gcloud sql backups create \
  --instance=invoiceninja-db \
  --project="$PROJECT_ID" \
  --description="Manual backup before deployment ${TIMESTAMP}"

echo "✅ Backup created: $BACKUP_NAME"

# List all backups
gcloud sql backups list --instance=invoiceninja-db
```

### 3. Application Data Backups

```bash
#!/bin/bash
# scripts/backup/backup-application-data.sh

PROJECT_ID="invoice-ninja-prod"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_BUCKET="gs://invoiceninja-backups"

echo "Backing up application data..."

# Backup uploaded files
echo "1. Backing up uploaded files..."
gsutil -m rsync -r -d \
  gs://invoiceninja-uploads \
  "${BACKUP_BUCKET}/files/${TIMESTAMP}/"

# Backup configuration
echo "2. Backing up configuration..."
gcloud secrets versions list app-key --format=json > app-key-versions.json
gsutil cp app-key-versions.json "${BACKUP_BUCKET}/config/${TIMESTAMP}/"

# Backup database schema
echo "3. Backing up database schema..."
gcloud sql export sql invoiceninja-db \
  "${BACKUP_BUCKET}/schema/${TIMESTAMP}/schema.sql" \
  --database=invoiceninja \
  --offload

echo "✅ Application data backed up to ${BACKUP_BUCKET}/${TIMESTAMP}/"
```

### 4. Cross-Region Backup Replication

```bash
#!/bin/bash
# scripts/backup/replicate-backups.sh

SOURCE_BUCKET="gs://invoiceninja-backups"
DEST_BUCKET="gs://invoiceninja-backups-eu"  # Different region

echo "Replicating backups to secondary region..."
gsutil -m rsync -r -d "$SOURCE_BUCKET" "$DEST_BUCKET"

echo "✅ Backups replicated to ${DEST_BUCKET}"
```

### 5. Backup Verification

```bash
#!/bin/bash
# scripts/backup/verify-backup.sh
# Run weekly to verify backup integrity

PROJECT_ID="invoice-ninja-prod"
LATEST_BACKUP=$(gcloud sql backups list \
  --instance=invoiceninja-db \
  --limit=1 \
  --format="value(id)")

echo "Verifying backup: $LATEST_BACKUP"

# Create temporary test instance from backup
TEST_INSTANCE="invoiceninja-test-restore-$(date +%s)"

echo "1. Creating test instance from backup..."
gcloud sql instances restore-backup invoiceninja-db \
  --backup-id="$LATEST_BACKUP" \
  --backup-instance=invoiceninja-db \
  --target-instance="$TEST_INSTANCE" \
  --project="$PROJECT_ID"

# Wait for instance to be ready
gcloud sql operations wait \
  --project="$PROJECT_ID" \
  $(gcloud sql operations list --instance="$TEST_INSTANCE" --limit=1 --format="value(name)")

# Verify data integrity
echo "2. Verifying data integrity..."
ROW_COUNT=$(gcloud sql connect "$TEST_INSTANCE" --database=invoiceninja --user=postgres << EOF
SELECT COUNT(*) FROM invoices;
EOF
)

echo "Row count: $ROW_COUNT"

# Cleanup test instance
echo "3. Cleaning up test instance..."
gcloud sql instances delete "$TEST_INSTANCE" --quiet

if [ "$ROW_COUNT" -gt 0 ]; then
    echo "✅ Backup verification successful"
else
    echo "❌ Backup verification failed"
    exit 1
fi
```

## Point-in-Time Recovery (PITR)

### Understanding PITR

```
Backup Window: Last 7 days
Granularity: Any second within the window
Recovery Process: Restore backup + replay transaction logs
```

### PITR Recovery Procedure

```bash
#!/bin/bash
# scripts/recovery/pitr-restore.sh

PROJECT_ID="invoice-ninja-prod"
TARGET_TIME="2026-01-15T10:30:00.000Z"  # UTC timestamp
RECOVERED_INSTANCE="invoiceninja-db-recovered"

echo "===================================="
echo "Point-in-Time Recovery"
echo "Target Time: $TARGET_TIME"
echo "===================================="

# Step 1: Create clone at specific point in time
echo "1. Creating PITR clone..."
gcloud sql instances clone invoiceninja-db "$RECOVERED_INSTANCE" \
  --point-in-time="$TARGET_TIME" \
  --project="$PROJECT_ID"

# Step 2: Wait for clone to be ready
echo "2. Waiting for clone to complete..."
gcloud sql operations wait \
  $(gcloud sql operations list --instance="$RECOVERED_INSTANCE" --limit=1 --format="value(name)")

# Step 3: Verify data
echo "3. Verifying recovered data..."
gcloud sql connect "$RECOVERED_INSTANCE" --user=postgres

echo "✅ PITR recovery complete"
echo "Recovered instance: $RECOVERED_INSTANCE"
echo ""
echo "Next steps:"
echo "1. Verify data integrity"
echo "2. If correct, promote this instance or export data"
echo "3. Delete temporary instance when done"
```

## Disaster Recovery Scenarios

### Scenario 1: Application Failure

**Symptoms**: 5xx errors, health checks failing

```bash
#!/bin/bash
# dr-runbook-01-application-failure.sh

echo "DR Scenario 1: Application Failure"
echo "===================================="

# 1. Check current deployment
CURRENT_REVISION=$(gcloud run revisions list \
  --service=invoiceninja \
  --format="value(name)" \
  --limit=1)

echo "Current revision: $CURRENT_REVISION"

# 2. Get previous stable revision
PREVIOUS_REVISION=$(gcloud run revisions list \
  --service=invoiceninja \
  --format="value(name)" \
  --limit=2 | tail -1)

echo "Previous revision: $PREVIOUS_REVISION"

# 3. Rollback to previous revision
echo "Rolling back to previous revision..."
gcloud run services update-traffic invoiceninja \
  --to-revisions="$PREVIOUS_REVISION=100"

# 4. Verify health
sleep 10
curl -f https://invoiceninja.run.app/health

echo "✅ Rollback complete"
echo "RTO: ~5 minutes"
```

### Scenario 2: Database Failure

**Symptoms**: Connection errors, database unresponsive

```bash
#!/bin/bash
# dr-runbook-02-database-failure.sh

echo "DR Scenario 2: Database Failure"
echo "===================================="

# Option A: Restart database
echo "Option A: Restarting database..."
gcloud sql instances restart invoiceninja-db

# Option B: Failover to replica (if HA enabled)
echo "Option B: Failover to replica..."
gcloud sql instances failover invoiceninja-db

# Option C: Restore from backup
echo "Option C: Restore from latest backup..."
LATEST_BACKUP=$(gcloud sql backups list \
  --instance=invoiceninja-db \
  --limit=1 \
  --format="value(id)")

gcloud sql backups restore "$LATEST_BACKUP" \
  --backup-instance=invoiceninja-db \
  --instance=invoiceninja-db

echo "✅ Database recovery complete"
echo "RTO: ~15 minutes"
```

### Scenario 3: Region Outage

**Symptoms**: All services in region unavailable

```bash
#!/bin/bash
# dr-runbook-03-region-outage.sh

echo "DR Scenario 3: Region Outage"
echo "===================================="

PRIMARY_REGION="us-central1"
FAILOVER_REGION="us-east1"

# 1. Promote read replica in secondary region
echo "1. Promoting read replica to primary..."
gcloud sql instances promote-replica invoiceninja-db-replica \
  --region="$FAILOVER_REGION"

# 2. Deploy application in secondary region
echo "2. Deploying application in secondary region..."
gcloud run deploy invoiceninja \
  --image="us-docker.pkg.dev/invoice-ninja-prod/invoiceninja/web:latest" \
  --region="$FAILOVER_REGION" \
  --set-env-vars="DB_HOST=${FAILOVER_REGION_DB_IP}"

# 3. Update DNS/Load Balancer
echo "3. Updating traffic routing..."
gcloud compute url-maps import invoiceninja-lb \
  --source=failover-url-map.yaml \
  --global

# 4. Verify new region is serving traffic
sleep 30
curl -f https://invoiceninja.example.com/health

echo "✅ Regional failover complete"
echo "RTO: ~30 minutes"
```

### Scenario 4: Data Corruption

**Symptoms**: Incorrect data, application errors

```bash
#!/bin/bash
# dr-runbook-04-data-corruption.sh

echo "DR Scenario 4: Data Corruption"
echo "===================================="

# 1. Identify corruption timeframe
echo "When was the corruption first noticed? (YYYY-MM-DDTHH:MM:SSZ)"
read CORRUPTION_TIME

# 2. Calculate recovery point (before corruption)
RECOVERY_TIME=$(date -d "$CORRUPTION_TIME - 1 hour" -u +%Y-%m-%dT%H:%M:%SZ)
echo "Recovery point: $RECOVERY_TIME"

# 3. Create PITR clone
echo "Creating PITR clone..."
gcloud sql instances clone invoiceninja-db invoiceninja-db-recovered \
  --point-in-time="$RECOVERY_TIME"

# 4. Export affected data from recovered instance
echo "Exporting recovered data..."
gcloud sql export csv invoiceninja-db-recovered \
  gs://invoiceninja-recovery/recovered-data.csv \
  --database=invoiceninja \
  --query="SELECT * FROM invoices WHERE updated_at < '$RECOVERY_TIME'"

# 5. Import into production (after verification)
echo "Data exported to gs://invoiceninja-recovery/recovered-data.csv"
echo "⚠️ MANUAL STEP: Verify and import data manually"

echo "✅ Data recovery prepared"
echo "RTO: ~1 hour + manual verification time"
```

### Scenario 5: Complete Account Compromise

**Symptoms**: Unauthorized access, resources deleted

```bash
#!/bin/bash
# dr-runbook-05-account-compromise.sh

echo "DR Scenario 5: Account Compromise"
echo "===================================="

# 1. Immediate actions
echo "1. IMMEDIATE ACTIONS:"
echo "   - Revoke all service account keys"
echo "   - Reset user passwords"
echo "   - Enable 2FA if not already enabled"

# 2. Create new GCP project
NEW_PROJECT_ID="invoice-ninja-recovery-$(date +%s)"
echo "2. Creating new GCP project: $NEW_PROJECT_ID"
gcloud projects create "$NEW_PROJECT_ID" --name="Invoice Ninja Recovery"

# 3. Restore from cross-region backups
echo "3. Restoring from cross-region backups..."
BACKUP_BUCKET="gs://invoiceninja-backups-eu"  # Secondary region

# Restore database
gcloud sql instances create invoiceninja-db \
  --project="$NEW_PROJECT_ID" \
  --region=us-central1

LATEST_BACKUP=$(gsutil ls "$BACKUP_BUCKET/database/" | tail -1)
gcloud sql import sql invoiceninja-db "$LATEST_BACKUP"

# 4. Deploy application from clean source
echo "4. Deploying application from clean source..."
cd /path/to/clean/source
gcloud run deploy invoiceninja \
  --project="$NEW_PROJECT_ID" \
  --source=.

# 5. Restore secrets
echo "5. Restoring secrets..."
# Restore from backup or regenerate

echo "✅ Clean environment deployed"
echo "RTO: ~4 hours"
echo ""
echo "POST-RECOVERY ACTIONS:"
echo "1. Conduct security audit"
echo "2. Review access logs"
echo "3. Update all credentials"
echo "4. Implement additional security controls"
```

## DR Testing Schedule

```yaml
# DR testing calendar
Monthly:
  - Backup verification (automated)
  - Application rollback test
  
Quarterly:
  - Database PITR test
  - Regional failover simulation
  
Annually:
  - Full disaster recovery drill
  - Account compromise scenario
  - Update DR runbooks
```

## DR Testing Checklist

```bash
#!/bin/bash
# scripts/dr/dr-test.sh

echo "===================================="
echo "Disaster Recovery Test"
echo "Date: $(date)"
echo "===================================="

# 1. Verify backups exist
echo -e "\n1. Checking backups..."
BACKUP_COUNT=$(gcloud sql backups list --instance=invoiceninja-db --format="value(id)" | wc -l)
if [ "$BACKUP_COUNT" -ge 7 ]; then
    echo "✅ Adequate backups: $BACKUP_COUNT"
else
    echo "❌ Insufficient backups: $BACKUP_COUNT (expected >= 7)"
fi

# 2. Test backup restore
echo -e "\n2. Testing backup restore..."
bash scripts/backup/verify-backup.sh

# 3. Test application rollback
echo -e "\n3. Testing application rollback..."
CURRENT=$(gcloud run revisions list --service=invoiceninja --format="value(name)" --limit=1)
PREVIOUS=$(gcloud run revisions list --service=invoiceninja --format="value(name)" --limit=2 | tail -1)

gcloud run services update-traffic invoiceninja --to-revisions="$PREVIOUS=100"
sleep 10
curl -f https://invoiceninja.run.app/health
gcloud run services update-traffic invoiceninja --to-revisions="$CURRENT=100"

echo "✅ Rollback test complete"

# 4. Measure RTO
echo -e "\n4. Measuring RTO..."
START_TIME=$(date +%s)
# Simulate recovery
sleep 5
END_TIME=$(date +%s)
RTO=$((END_TIME - START_TIME))
echo "✅ RTO: ${RTO}s (target: <300s)"

# 5. Test cross-region backup access
echo -e "\n5. Testing cross-region backup access..."
gsutil ls gs://invoiceninja-backups-eu/ > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Cross-region backups accessible"
else
    echo "❌ Cross-region backups inaccessible"
fi

echo -e "\n===================================="
echo "DR Test Complete"
echo "===================================="
```

## Backup Monitoring

```bash
# Alert on backup failure
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="Backup Failure Alert" \
  --condition-display-name="No backup in 24 hours" \
  --condition-filter='
    resource.type="cloudsql_database"
    AND metric.type="cloudsql.googleapis.com/database/backup/count"
    AND metric.value<1
  ' \
  --condition-duration=86400s
```

## Recovery Procedures Documentation

### Database Recovery Flowchart

```
┌─────────────────────┐
│ Database Failure    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Is DB responding?   │
├─────────────────────┤
│ No → Restart        │──┐
│ Yes → Check replica │  │
└──────────┬──────────┘  │
           │             │
           ▼             ▼
┌─────────────────────┐ ┌──────────────┐
│ Replica healthy?    │ │ DB restarted │
├─────────────────────┤ └──────┬───────┘
│ Yes → Failover      │        │
│ No → Restore backup │        │
└──────────┬──────────┘        │
           │                   │
           ▼                   ▼
┌──────────────────────────────┐
│ Verify application health    │
└──────────────────────────────┘
```

## Recovery Contacts

```yaml
Primary On-Call:
  - Name: DevOps Team
  - Phone: +1-XXX-XXX-XXXX
  - Email: devops@example.com
  - PagerDuty: devops-oncall

Secondary On-Call:
  - Name: Platform Engineering Lead
  - Phone: +1-XXX-XXX-XXXX
  - Email: platform-lead@example.com

Database Specialist:
  - Name: DBA Team
  - Phone: +1-XXX-XXX-XXXX
  - Email: dba@example.com

Management Escalation:
  - Name: VP Engineering
  - Phone: +1-XXX-XXX-XXXX
  - Email: vp-eng@example.com
```

## Post-Recovery Checklist

- [ ] Verify all services are operational
- [ ] Check data integrity
- [ ] Review recovery metrics (RTO/RPO)
- [ ] Document lessons learned
- [ ] Update runbooks if needed
- [ ] Notify stakeholders
- [ ] Schedule post-mortem
- [ ] Implement preventive measures

## Backup Retention Policy

```yaml
Automated Backups:
  Retention: 7 days
  Frequency: Daily at 3 AM UTC
  Type: Full + transaction logs

Manual Backups:
  Retention: 90 days
  Frequency: On-demand
  Type: Full

Long-term Backups:
  Retention: 1 year
  Frequency: Monthly
  Type: Full + schema
  Location: Cold storage (Archive class)
```
