# Database Backup & Disaster Recovery Guide

## Overview
Comprehensive backup strategy and disaster recovery procedures for Invoice Ninja production database.

## Backup Strategy

### RPO & RTO Targets

| Environment | RPO (Recovery Point Objective) | RTO (Recovery Time Objective) |
|-------------|-------------------------------|-------------------------------|
| Production  | 5 minutes                     | 15 minutes                     |
| Staging     | 1 hour                        | 1 hour                        |
| Development | 24 hours                      | 4 hours                       |

### Backup Types

#### 1. Automated Daily Backups
- **Frequency**: Daily at 02:00 UTC
- **Retention**: 7 days
- **Storage Location**: Multi-region (automatic)
- **Type**: Full database backup

**Configuration**:
```bash
# Enable automated backups
gcloud sql instances patch INSTANCE_NAME \
  --backup-start-time=02:00 \
  --retained-backups-count=7 \
  --project=PROJECT_ID
```

**Verification**:
```bash
# List recent backups
gcloud sql backups list \
  --instance=INSTANCE_NAME \
  --project=PROJECT_ID

# Verify latest backup
gcloud sql backups describe BACKUP_ID \
  --instance=INSTANCE_NAME \
  --project=PROJECT_ID
```

#### 2. Point-in-Time Recovery (PITR)
- **Enabled**: Yes
- **Window**: 7 days
- **Transaction logs**: Continuous
- **Granularity**: Any second within the 7-day window

**Configuration**:
```bash
# Enable PITR
gcloud sql instances patch INSTANCE_NAME \
  --enable-point-in-time-recovery \
  --retained-transaction-log-days=7 \
  --project=PROJECT_ID
```

**Usage**:
```bash
# Restore to specific timestamp
gcloud sql backups restore BACKUP_ID \
  --backup-instance=INSTANCE_NAME \
  --backup-project=PROJECT_ID \
  --restore-instance=NEW_INSTANCE_NAME \
  --point-in-time=2026-01-17T10:30:00Z
```

#### 3. On-Demand Backups
- **When**: Before major changes, migrations, or deployments
- **Retention**: 90 days
- **Purpose**: Additional safety before risky operations

**Create**:
```bash
# Create on-demand backup with description
gcloud sql backups create \
  --instance=INSTANCE_NAME \
  --description="Pre-migration backup - v2.5 upgrade" \
  --project=PROJECT_ID
```

#### 4. Application-Level Exports
- **Frequency**: Weekly
- **Format**: SQL dump + JSON export
- **Storage**: Cloud Storage bucket (cross-region)
- **Purpose**: Compliance, long-term archival, cross-platform portability

**Script**:
```bash
#!/bin/bash
# backup_export.sh

DATE=$(date +%Y%m%d_%H%M%S)
BUCKET="gs://invoiceninja-backups-prod"
INSTANCE_NAME="invoiceninja-prod-db"

# SQL dump
gcloud sql export sql $INSTANCE_NAME \
  ${BUCKET}/sql-dumps/backup_${DATE}.sql \
  --database=invoiceninja \
  --project=PROJECT_ID

# Application data export (JSON)
gcloud run jobs execute data-export \
  --region=REGION \
  --env-vars="EXPORT_PATH=${BUCKET}/json-exports/backup_${DATE}.json" \
  --project=PROJECT_ID

# Verify export
gsutil ls -lh ${BUCKET}/sql-dumps/backup_${DATE}.sql
gsutil ls -lh ${BUCKET}/json-exports/backup_${DATE}.json

echo "Backup completed: $DATE"
```

**Automate with Cloud Scheduler**:
```bash
# Create scheduled backup job
gcloud scheduler jobs create http weekly-backup \
  --schedule="0 0 * * 0" \
  --uri="https://REGION-PROJECT_ID.cloudfunctions.net/run-backup" \
  --http-method=POST \
  --oidc-service-account-email=backup-sa@PROJECT_ID.iam.gserviceaccount.com \
  --time-zone="UTC" \
  --project=PROJECT_ID
```

## Backup Verification

### Daily Verification Script
```bash
#!/bin/bash
# verify_backups.sh

# Check last automated backup
LAST_BACKUP=$(gcloud sql backups list \
  --instance=INSTANCE_NAME \
  --limit=1 \
  --format="value(id)" \
  --project=PROJECT_ID)

if [ -z "$LAST_BACKUP" ]; then
  echo "❌ ERROR: No recent backup found!"
  exit 1
fi

# Check backup age (should be < 24 hours)
BACKUP_TIME=$(gcloud sql backups describe $LAST_BACKUP \
  --instance=INSTANCE_NAME \
  --format="value(windowStartTime)" \
  --project=PROJECT_ID)

BACKUP_AGE=$(($(date +%s) - $(date -d "$BACKUP_TIME" +%s)))
MAX_AGE=$((24 * 3600)) # 24 hours

if [ $BACKUP_AGE -gt $MAX_AGE ]; then
  echo "❌ ERROR: Last backup is too old ($((BACKUP_AGE / 3600)) hours)"
  exit 1
fi

# Verify PITR is enabled
PITR_ENABLED=$(gcloud sql instances describe INSTANCE_NAME \
  --format="value(settings.backupConfiguration.pointInTimeRecoveryEnabled)" \
  --project=PROJECT_ID)

if [ "$PITR_ENABLED" != "True" ]; then
  echo "❌ ERROR: Point-in-Time Recovery is not enabled!"
  exit 1
fi

# Check application exports in Cloud Storage
LATEST_EXPORT=$(gsutil ls -l gs://invoiceninja-backups-prod/sql-dumps/ | \
  grep -v TOTAL | tail -1 | awk '{print $2}')

EXPORT_AGE=$(($(date +%s) - $(date -d "$LATEST_EXPORT" +%s)))
MAX_EXPORT_AGE=$((7 * 24 * 3600)) # 7 days

if [ $EXPORT_AGE -gt $MAX_EXPORT_AGE ]; then
  echo "⚠️  WARNING: Last application export is $((EXPORT_AGE / 86400)) days old"
fi

echo "✅ All backup checks passed"
echo "  - Last automated backup: $((BACKUP_AGE / 3600)) hours ago"
echo "  - PITR enabled: Yes"
echo "  - Last export: $((EXPORT_AGE / 86400)) days ago"
```

**Run daily via Cloud Scheduler**:
```bash
gcloud scheduler jobs create http daily-backup-verification \
  --schedule="0 8 * * *" \
  --uri="https://REGION-PROJECT_ID.cloudfunctions.net/verify-backups" \
  --http-method=POST \
  --time-zone="UTC" \
  --project=PROJECT_ID
```

## Disaster Recovery Scenarios

### Scenario 1: Accidental Data Deletion

**Example**: User accidentally deleted critical invoices

**Recovery Steps**:
```bash
# 1. Identify when data was deleted (from logs)
DELETION_TIME="2026-01-17T14:30:00Z"

# 2. Create restore timestamp (1 minute before deletion)
RESTORE_TIME="2026-01-17T14:29:00Z"

# 3. Get latest backup ID before deletion
BACKUP_ID=$(gcloud sql backups list \
  --instance=INSTANCE_NAME \
  --filter="windowStartTime<$RESTORE_TIME" \
  --limit=1 \
  --format="value(id)" \
  --project=PROJECT_ID)

# 4. Create new instance from backup at specific time
gcloud sql backups restore $BACKUP_ID \
  --backup-instance=INSTANCE_NAME \
  --restore-instance=invoiceninja-restore-$(date +%Y%m%d) \
  --point-in-time=$RESTORE_TIME \
  --project=PROJECT_ID

# 5. Wait for restore to complete
gcloud sql operations list \
  --instance=invoiceninja-restore-$(date +%Y%m%d) \
  --filter="status!=DONE" \
  --project=PROJECT_ID

# 6. Export specific data from restored instance
gcloud sql export sql invoiceninja-restore-$(date +%Y%m%d) \
  gs://temp-recovery-bucket/recovered_data.sql \
  --database=invoiceninja \
  --table=invoices \
  --project=PROJECT_ID

# 7. Import recovered data into production
gcloud sql import sql INSTANCE_NAME \
  gs://temp-recovery-bucket/recovered_data.sql \
  --database=invoiceninja \
  --project=PROJECT_ID

# 8. Verify data recovery
# Connect and verify invoices are restored

# 9. Delete temporary restore instance
gcloud sql instances delete invoiceninja-restore-$(date +%Y%m%d) \
  --project=PROJECT_ID
```

**RTO**: 30-45 minutes  
**RPO**: Up to 5 minutes (PITR granularity)

### Scenario 2: Database Corruption

**Example**: Database corruption detected after failed migration

**Recovery Steps**:
```bash
# 1. Stop all writes to database
gcloud run services update invoice-ninja-web \
  --no-traffic \
  --region=REGION \
  --project=PROJECT_ID

# 2. Create backup of current (corrupted) state for forensics
gcloud sql backups create \
  --instance=INSTANCE_NAME \
  --description="Backup before corruption recovery" \
  --project=PROJECT_ID

# 3. Identify last known good backup
# Test backups from most recent to find last good one
BACKUP_TO_TEST=$(gcloud sql backups list \
  --instance=INSTANCE_NAME \
  --limit=5 \
  --format="value(id)" \
  --project=PROJECT_ID)

# 4. Restore from last known good backup
gcloud sql backups restore GOOD_BACKUP_ID \
  --backup-instance=INSTANCE_NAME \
  --restore-instance=INSTANCE_NAME \
  --project=PROJECT_ID

# 5. Verify database integrity
gcloud sql connect INSTANCE_NAME --user=root --project=PROJECT_ID
# In MySQL:
CHECK TABLE invoices;
CHECK TABLE clients;
# ... check all critical tables

# 6. Re-enable traffic
gcloud run services update invoice-ninja-web \
  --to-latest \
  --region=REGION \
  --project=PROJECT_ID

# 7. Monitor for issues
gcloud logging tail "resource.type=cloud_run_revision" --project=PROJECT_ID
```

**RTO**: 15-30 minutes  
**RPO**: Time since last backup (max 24 hours, typically < 1 hour with PITR)

### Scenario 3: Complete Region Outage

**Example**: GCP region completely unavailable

**Recovery Steps**:
```bash
# 1. Promote read replica in different region (if configured)
gcloud sql instances promote-replica invoiceninja-replica-eu \
  --project=PROJECT_ID

# 2. Update DNS to point to new region
# (If using Cloud Load Balancer, update backend)
gcloud compute url-maps edit URL_MAP_NAME \
  --project=PROJECT_ID

# 3. Deploy Cloud Run services to new region
gcloud run services update invoice-ninja-web \
  --region=europe-west1 \
  --image=REGION-docker.pkg.dev/PROJECT_ID/invoiceninja/web:latest \
  --project=PROJECT_ID

# 4. Update VPC connector to new region
gcloud compute networks vpc-access connectors create connector-eu \
  --region=europe-west1 \
  --network=VPC_NAME \
  --range=10.9.0.0/28 \
  --project=PROJECT_ID

gcloud run services update invoice-ninja-web \
  --vpc-connector=connector-eu \
  --region=europe-west1 \
  --project=PROJECT_ID

# 5. Verify application in new region
curl -I https://invoiceninja-eu-PROJECT_ID.a.run.app/health

# 6. Update production DNS
gcloud dns record-sets transaction start \
  --zone=ZONE_NAME \
  --project=PROJECT_ID

gcloud dns record-sets transaction add \
  NEW_IP_ADDRESS \
  --name=app.yourdomain.com. \
  --ttl=300 \
  --type=A \
  --zone=ZONE_NAME \
  --project=PROJECT_ID

gcloud dns record-sets transaction execute \
  --zone=ZONE_NAME \
  --project=PROJECT_ID
```

**RTO**: 30-60 minutes (with read replica)  
**RPO**: Near-zero (continuous replication)

### Scenario 4: Complete Account Compromise

**Example**: GCP account credentials compromised, malicious activity detected

**Recovery Steps**:
```bash
# 1. Immediately rotate all credentials
# - Revoke compromised service account keys
# - Rotate database passwords
# - Reset IAM permissions

# 2. Create new GCP project
gcloud projects create invoiceninja-recovery-PROJECT_ID \
  --name="Invoice Ninja Recovery"

# 3. Restore latest backup to new project
# Export from old project
gcloud sql export sql INSTANCE_NAME \
  gs://recovery-bucket/final-backup.sql \
  --database=invoiceninja \
  --project=OLD_PROJECT_ID

# Import to new project
gcloud sql instances create invoiceninja-new-db \
  --tier=db-n1-standard-2 \
  --region=REGION \
  --project=NEW_PROJECT_ID

gcloud sql import sql invoiceninja-new-db \
  gs://recovery-bucket/final-backup.sql \
  --database=invoiceninja \
  --project=NEW_PROJECT_ID

# 4. Redeploy application in new project
# Follow standard deployment procedures

# 5. Audit all access logs
gcloud logging read \
  'protoPayload.@type="type.googleapis.com/google.cloud.audit.AuditLog"' \
  --project=OLD_PROJECT_ID \
  --format=json > security-audit.json

# 6. Update DNS to point to new environment
# 7. Decommission old project after verification
```

**RTO**: 2-4 hours  
**RPO**: Last successful backup (potentially up to 24 hours)

## DR Testing Schedule

### Monthly: Database Restore Test
```bash
# Automated test - runs on first Sunday of each month
# 1. Restore latest backup to test instance
# 2. Verify data integrity
# 3. Run application tests against restored DB
# 4. Measure and log RTO
# 5. Delete test instance
```

### Quarterly: Full DR Drill
- Simulate complete region outage
- Execute failover procedures
- Verify application functionality in DR region
- Test data consistency
- Document actual RTO/RPO achieved
- Update DR procedures based on findings

### Annually: Chaos Engineering
- Unannounced failure simulation
- Test on-call response
- Verify monitoring and alerting
- Complete end-to-end DR process
- Executive-level incident simulation

## Backup Monitoring & Alerts

### Alert: Backup Failure
```bash
# Create alert for failed backups
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="Database Backup Failure" \
  --condition-display-name="Backup operation failed" \
  --condition-threshold-value=1 \
  --condition-threshold-duration=300s \
  --condition-threshold-filter='metric.type="cloudsql.googleapis.com/database/backup/status" AND metric.labels.status="failed"' \
  --project=PROJECT_ID
```

### Alert: PITR Disabled
```bash
# Alert if PITR gets disabled
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="PITR Disabled" \
  --condition-display-name="Point-in-Time Recovery disabled" \
  --condition-threshold-value=0 \
  --condition-threshold-duration=60s \
  --condition-threshold-filter='metric.type="cloudsql.googleapis.com/database/backup/pitr_enabled" AND metric.value=false' \
  --project=PROJECT_ID
```

### Alert: Old Backup
```bash
# Alert if no backup in 25+ hours
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="Backup Age Exceeded" \
  --condition-display-name="No backup in 25 hours" \
  --condition-threshold-value=90000 \
  --condition-threshold-duration=0s \
  --condition-threshold-filter='metric.type="cloudsql.googleapis.com/database/backup/age"' \
  --project=PROJECT_ID
```

## Backup Storage Costs

| Backup Type | Storage Location | Monthly Cost (estimate) |
|-------------|------------------|-------------------------|
| Automated Daily (7 days) | Multi-region | ~$10-20 |
| PITR Transaction Logs | Multi-region | ~$5-15 |
| Application Exports | Cloud Storage Multi-region | ~$20-30 |
| **Total** | | **~$35-65/month** |

*Costs scale with database size and retention period*

## Compliance Requirements

### SOC 2 / ISO 27001
- ✅ Daily automated backups
- ✅ 7-day retention minimum
- ✅ Encrypted at rest and in transit
- ✅ Access logs maintained
- ✅ Regular restore testing
- ✅ Documented DR procedures

### GDPR / Data Protection
- ✅ Backups encrypted with customer-managed keys (optional)
- ✅ Geographic data residency controls
- ✅ Secure deletion of old backups
- ✅ Access control and auditing

## Checklist: Post-Recovery Verification

After any recovery procedure:
- [ ] Database accessible and responding
- [ ] All tables present and intact
- [ ] Row counts match expected values
- [ ] Application can connect and authenticate
- [ ] Critical user flows working (create invoice, process payment)
- [ ] No data corruption detected
- [ ] Monitoring and logging functional
- [ ] Performance metrics normal
- [ ] Security audit logs reviewed
- [ ] Stakeholders notified of recovery completion
- [ ] Incident documentation completed

## Scripts & Automation

All DR scripts available in: `/scripts/backup/`
- `backup_export.sh` - Weekly application export
- `verify_backups.sh` - Daily backup verification
- `test_restore.sh` - Monthly restore testing
- `emergency_restore.sh` - Quick restore for SEV1 incidents

## Related Documentation
- [Database Operations Runbook](./database_operations.md)
- [Incident Response Procedures](./incident_response.md)
- [High Availability Setup](../docs/high_availability.md)
- [Security Compliance Guide](../docs/security_compliance.md)

---

**Last Updated**: 2026-01-17  
**Owner**: Database Team + DevOps  
**Review Frequency**: Quarterly + after each DR test  
**Next DR Drill**: First Sunday of next month
