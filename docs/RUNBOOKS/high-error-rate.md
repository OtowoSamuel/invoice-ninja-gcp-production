# Runbook: High Error Rate (5xx Errors)

**Severity**: SEV2 (High)  
**Response Time**: 15 minutes  
**Affected Component**: Application / Cloud Run  

## Symptoms

- Alert: "High Error Rate" firing
- Cloud Monitoring shows >5% 5xx error rate
- Users reporting errors or service unavailable
- Increased latency on requests

## Impact

- **User Impact**: High - users cannot complete transactions
- **Business Impact**: Revenue loss, customer dissatisfaction
- **SLO Impact**: Burns error budget rapidly

## Investigation Steps

### 1. Check Recent Deployments
```bash
# List recent Cloud Run revisions
gcloud run revisions list \
  --service=invoiceninja \
  --format="table(name,creationTimestamp,status)"

# Check current traffic split
gcloud run services describe invoiceninja \
  --format="value(status.traffic)"
```

**Action**: If errors started after recent deployment → Proceed to Resolution Step 1 (Rollback)

### 2. Check Application Logs
```bash
# View error logs (last 10 minutes)
gcloud logging read "
  resource.type=\"cloud_run_revision\"
  AND resource.labels.service_name=\"invoiceninja\"
  AND severity>=\"ERROR\"
  AND timestamp>=\"$(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%SZ)\"
" --limit=50 --format=json | jq -r '.[].textPayload'

# Look for patterns:
# - Database connection errors
# - Timeout errors
# - Memory errors (OOM)
# - Unhandled exceptions
```

**Action**: Identify error pattern and proceed to relevant resolution step

### 3. Check Database Health
```bash
# Database CPU utilization
gcloud monitoring time-series list \
  --filter='metric.type="cloudsql.googleapis.com/database/cpu/utilization"' \
  --start-time="15m"

# Database connections
gcloud monitoring time-series list \
  --filter='metric.type="cloudsql.googleapis.com/database/postgresql/num_backends"' \
  --start-time="15m"

# Check for slow queries
gcloud sql operations list --instance=invoiceninja-db --limit=10
```

**Action**: If database issues detected → Proceed to Resolution Step 3

### 4. Check External Dependencies
```bash
# Check external API response times from logs
gcloud logging read "
  jsonPayload.external_api_call:*
  AND timestamp>=\"$(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%SZ)\"
" --format=json | jq '.[] | {api: .jsonPayload.api, duration: .jsonPayload.duration_ms}'
```

### 5. Check Resource Limits
```bash
# Container instance count
gcloud run services describe invoiceninja \
  --format="value(status.observedGeneration,spec.template.spec.containerConcurrency,spec.template.metadata.annotations.autoscaling\.knative\.dev/maxScale)"

# Memory usage
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/container/memory/utilizations"' \
  --start-time="15m"
```

## Resolution Steps

### Option 1: Rollback to Previous Revision (Quickest - 2 minutes)

```bash
# Get current and previous revisions
CURRENT_REVISION=$(gcloud run revisions list --service=invoiceninja --format="value(name)" --limit=1)
PREVIOUS_REVISION=$(gcloud run revisions list --service=invoiceninja --format="value(name)" --limit=2 | tail -1)

echo "Current: $CURRENT_REVISION"
echo "Rolling back to: $PREVIOUS_REVISION"

# Immediate rollback
gcloud run services update-traffic invoiceninja \
  --to-revisions="$PREVIOUS_REVISION=100"

# Monitor for 2 minutes
sleep 120

# Verify error rate decreased
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/request_count" AND metric.labels.response_code_class="5xx"' \
  --start-time="2m"
```

**Verification**: Error rate should drop below 1% within 2 minutes

### Option 2: Scale Up Resources (If under load - 3 minutes)

```bash
# Increase max instances
gcloud run services update invoiceninja \
  --max-instances=100 \
  --min-instances=5

# Increase resources per container
gcloud run services update invoiceninja \
  --memory=4Gi \
  --cpu=4
```

**Verification**: Check if error rate decreases with more resources

### Option 3: Restart Database (If DB issues - 5 minutes)

```bash
# Restart Cloud SQL instance
gcloud sql instances restart invoiceninja-db

# Wait for restart
gcloud sql operations wait \
  $(gcloud sql operations list --instance=invoiceninja-db --limit=1 --format="value(name)")

# Verify connectivity
gcloud sql connect invoiceninja-db --user=postgres --database=invoiceninja
```

**Verification**: Database connections should recover

### Option 4: Clear Application Cache (If cache corruption - 1 minute)

```bash
# Connect to Redis and flush cache
REDIS_HOST=$(gcloud redis instances describe invoiceninja-redis --region=us-central1 --format="value(host)")

# Flush cache
redis-cli -h $REDIS_HOST FLUSHALL

# Restart application to reconnect
gcloud run services update invoiceninja --max-instances=50
```

## Post-Resolution Actions

### 1. Verify Service Health
```bash
# Check health endpoint
curl -f https://invoiceninja.run.app/health

# Monitor error rate for 15 minutes
watch -n 30 'gcloud monitoring time-series list \
  --filter="metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\"" \
  --start-time="5m"'
```

### 2. Update Stakeholders
```
Template:
- Subject: [RESOLVED] High Error Rate Incident
- Impact: X minutes of elevated errors (Y% error rate)
- Root Cause: [Brief description]
- Resolution: [What was done]
- Next Steps: [Preventive measures]
```

### 3. Schedule Postmortem
- Create incident ticket with timeline
- Schedule postmortem within 48 hours
- Identify action items

## Escalation Path

1. **Primary**: DevOps On-Call → Slack #incidents-prod
2. **15 min**: Platform Engineering Lead → Phone +1-XXX-XXX-XXXX
3. **30 min**: VP Engineering → Email vp-eng@example.com
4. **45 min**: CTO → Phone +1-XXX-XXX-XXXX

## Related Documentation

- [Application Logs Documentation](https://docs.example.com/logs)
- [Rollback Procedure](https://docs.example.com/rollback)
- [Database Troubleshooting](https://docs.example.com/database-troubleshooting)

## Incident History

| Date | Duration | Root Cause | Resolution |
|------|----------|------------|------------|
| 2026-01-10 | 12 min | Bad deployment | Rollback |
| 2025-12-15 | 8 min | DB connection leak | Restart app |
| 2025-11-20 | 25 min | External API timeout | Increased timeout |

## Preventive Measures

- [ ] Implement canary deployments
- [ ] Add circuit breakers for external APIs
- [ ] Improve health checks
- [ ] Add connection pool monitoring
- [ ] Implement automatic rollback on high error rate

---

*Last Updated: 2026-01-17*  
*Owner: Platform Team*  
*Review Frequency: Monthly*
