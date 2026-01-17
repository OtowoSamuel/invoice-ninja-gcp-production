# Runbook: Service Down / Health Check Failure

**Severity**: SEV1 (Critical)  
**Response Time**: Immediate  
**Affected Component**: Entire Application  

## Symptoms

- Alert: "Service Down" firing
- Uptime check failing
- Users cannot access application
- 503/504 errors on all requests
- Health check endpoint unreachable

## Impact

- **User Impact**: CRITICAL - Complete service outage
- **Business Impact**: All users affected, revenue stopped
- **SLO Impact**: Major SLO breach

## Immediate Actions (< 2 minutes)

### 1. Verify Outage Scope
```bash
# Check from external location
curl -v https://invoiceninja.run.app/health

# Check all regions if multi-region
for REGION in us-central1 us-east1 europe-west1; do
  echo "Checking $REGION..."
  curl -v https://${REGION}-invoiceninja.run.app/health
done
```

### 2. Check Service Status
```bash
# Cloud Run service status
gcloud run services describe invoiceninja \
  --format="value(status.conditions)"

# Check for recent errors
gcloud run services describe invoiceninja \
  --format="yaml(status)"
```

## Investigation Steps

### 1. Check Recent Changes
```bash
# Recent deployments (last 1 hour)
gcloud run revisions list --service=invoiceninja \
  --filter="metadata.creationTimestamp>=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --format="table(name,creationTimestamp,status)"

# Recent Cloud SQL changes
gcloud sql operations list --instance=invoiceninja-db \
  --filter="startTime>=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)"
```

### 2. Check Container Status
```bash
# Container instances
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/container/instance_count"' \
  --start-time="5m"

# Container startup failures
gcloud logging read "
  resource.type=\"cloud_run_revision\"
  AND (\"Container failed to start\" OR \"Container terminated\")
  AND timestamp>=\"$(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%SZ)\"
" --limit=20
```

### 3. Check Database Connectivity
```bash
# Test database connection
gcloud sql connect invoiceninja-db --user=postgres

# Check database status
gcloud sql instances describe invoiceninja-db \
  --format="value(state,databaseVersion)"
```

### 4. Check Load Balancer / Networking
```bash
# If using Load Balancer
gcloud compute backend-services get-health invoiceninja-backend

# Check VPC connector
gcloud compute networks vpc-access connectors describe invoiceninja-connector \
  --region=us-central1
```

## Resolution Steps

### Option 1: Immediate Rollback (FASTEST - 1 minute)

```bash
#!/bin/bash
# Emergency rollback script

set -e

echo "🚨 EMERGENCY ROLLBACK INITIATED"

# Get last known good revision (2nd most recent)
PREVIOUS_REVISION=$(gcloud run revisions list \
  --service=invoiceninja \
  --format="value(name)" \
  --limit=2 | tail -1)

echo "Rolling back to: $PREVIOUS_REVISION"

# Immediate traffic switch
gcloud run services update-traffic invoiceninja \
  --to-revisions="$PREVIOUS_REVISION=100"

echo "✅ Rollback complete"

# Verify
sleep 10
curl -f https://invoiceninja.run.app/health
```

### Option 2: Restart Service (2 minutes)

```bash
# Force new revision deployment (triggers restart)
gcloud run services update invoiceninja \
  --max-instances=50

# Or update with same image to force restart
IMAGE=$(gcloud run services describe invoiceninja --format="value(spec.template.spec.containers[0].image)")
gcloud run services update invoiceninja --image="$IMAGE"
```

### Option 3: Database Recovery (5 minutes)

```bash
# If database is down
gcloud sql instances restart invoiceninja-db

# Wait for database to be ready
until gcloud sql instances describe invoiceninja-db --format="value(state)" | grep RUNNABLE; do
  echo "Waiting for database..."
  sleep 5
done

echo "✅ Database restarted"
```

### Option 4: Restore from Backup (15 minutes)

```bash
# If complete failure, restore last backup
LATEST_BACKUP=$(gcloud sql backups list \
  --instance=invoiceninja-db \
  --limit=1 \
  --format="value(id)")

echo "Restoring backup: $LATEST_BACKUP"

gcloud sql backups restore "$LATEST_BACKUP" \
  --backup-instance=invoiceninja-db \
  --instance=invoiceninja-db

# This will take 10-15 minutes
```

### Option 5: Deploy to Secondary Region (30 minutes)

```bash
# If primary region is down
SECONDARY_REGION="us-east1"

# Deploy in secondary region
gcloud run deploy invoiceninja \
  --image="us-docker.pkg.dev/invoice-ninja-prod/invoiceninja/web:latest" \
  --region="$SECONDARY_REGION"

# Update DNS/Load Balancer to route to secondary region
# (Manual step - update DNS records)
```

## Communication Template

### Initial Notification (< 5 minutes)
```
🚨 INCIDENT: Service Down
Status: Investigating
Impact: Complete service outage
ETA: Investigating
Updates: Every 10 minutes

Channels:
- Status Page: https://status.example.com
- Slack: #incidents-prod
- Email: incidents@example.com
```

### Update Template
```
UPDATE: Service Down Incident
Time: [Timestamp]
Status: [Investigating/Identified/Monitoring/Resolved]
Current Action: [What we're doing]
Next Update: [Time]
```

### Resolution Notification
```
✅ RESOLVED: Service Down
Duration: [X minutes]
Root Cause: [Brief description]
Resolution: [What fixed it]
Impact: [How many users affected]
Next Steps: [Postmortem scheduled]
```

## Escalation Path

**Immediate**:
1. Page DevOps On-Call via PagerDuty
2. Post in #incidents-prod Slack channel
3. Update status page

**+ 5 minutes** (if not resolved):
4. Call Platform Engineering Lead: +1-XXX-XXX-XXXX
5. Notify VP Engineering via email

**+ 15 minutes**:
6. Executive escalation: CTO phone +1-XXX-XXX-XXXX
7. Initiate war room (Zoom link in #incidents-prod topic)

**+ 30 minutes**:
8. Customer communication plan
9. PR team notification

## Post-Resolution Checklist

- [ ] Service health verified (all checks passing)
- [ ] Error rate < 0.1%
- [ ] Response times normal (p95 < 500ms)
- [ ] All regions operational (if multi-region)
- [ ] Database connections healthy
- [ ] Queue workers processing normally
- [ ] Status page updated
- [ ] Customers notified of resolution
- [ ] Incident timeline documented
- [ ] Postmortem scheduled (within 24 hours)

## Verification Commands

```bash
#!/bin/bash
# verify-service-health.sh

echo "===================================="
echo "Service Health Verification"
echo "===================================="

# 1. Health check
echo -e "\n1. Health Check:"
if curl -f -s https://invoiceninja.run.app/health > /dev/null; then
    echo "✅ Health check passing"
else
    echo "❌ Health check failing"
    exit 1
fi

# 2. Error rate
echo -e "\n2. Error Rate:"
ERROR_COUNT=$(gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/request_count" AND metric.labels.response_code_class="5xx"' \
  --start-time="5m" \
  --format="value(points[].value.int64Value)" | awk '{s+=$1} END {print s}')

TOTAL_COUNT=$(gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/request_count"' \
  --start-time="5m" \
  --format="value(points[].value.int64Value)" | awk '{s+=$1} END {print s}')

ERROR_RATE=$(echo "scale=4; ($ERROR_COUNT / $TOTAL_COUNT) * 100" | bc)

if (( $(echo "$ERROR_RATE < 0.1" | bc -l) )); then
    echo "✅ Error rate: ${ERROR_RATE}%"
else
    echo "❌ Error rate too high: ${ERROR_RATE}%"
    exit 1
fi

# 3. Response time
echo -e "\n3. Response Time:"
P95_LATENCY=$(gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/request_latencies"' \
  --start-time="5m" \
  --format="value(points[].value.distributionValue.mean)" | sort -n | tail -1)

if (( $(echo "$P95_LATENCY < 500" | bc -l) )); then
    echo "✅ P95 latency: ${P95_LATENCY}ms"
else
    echo "⚠️ P95 latency elevated: ${P95_LATENCY}ms"
fi

# 4. Container instances
echo -e "\n4. Container Instances:"
INSTANCE_COUNT=$(gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/container/instance_count"' \
  --start-time="1m" \
  --format="value(points[].value.int64Value)" | tail -1)

if [ "$INSTANCE_COUNT" -gt 0 ]; then
    echo "✅ Container instances: $INSTANCE_COUNT"
else
    echo "❌ No container instances running"
    exit 1
fi

# 5. Database connectivity
echo -e "\n5. Database Connectivity:"
if gcloud sql instances describe invoiceninja-db --format="value(state)" | grep -q "RUNNABLE"; then
    echo "✅ Database running"
else
    echo "❌ Database not running"
    exit 1
fi

echo -e "\n===================================="
echo "✅ All health checks passed"
echo "===================================="
```

## Incident History

| Date | Duration | Root Cause | Resolution | Postmortem |
|------|----------|------------|------------|------------|
| 2025-12-01 | 45 min | Bad deployment (OOM) | Rollback + resource increase | [Link](#) |
| 2025-10-15 | 12 min | Database restart | Waited for restart | [Link](#) |
| 2025-09-20 | 120 min | Region outage | Failover to secondary | [Link](#) |

## Related Runbooks

- [High Error Rate](high-error-rate.md)
- [Database Failure](database-failure.md)
- [High Latency](high-latency.md)
- [Deployment Rollback](deployment-rollback.md)

## Preventive Measures

- [ ] Implement automated rollback on health check failure
- [ ] Set up multi-region active-active
- [ ] Add pre-deployment smoke tests
- [ ] Improve health check robustness
- [ ] Add chaos engineering tests
- [ ] Implement circuit breakers

---

*Last Updated: 2026-01-17*  
*Owner: Platform Team*  
*Severity: SEV1 (Critical)*  
*Review Frequency: Monthly*
