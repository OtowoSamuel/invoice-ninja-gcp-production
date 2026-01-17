# Runbook: High Error Rate

## Severity
**SEV2** - High Priority

## Symptoms
- Monitoring alert: "High Error Rate" triggered
- Error rate > 1% for 5+ minutes
- Users reporting application errors
- Dashboard shows spike in 5xx responses

## User Impact
- **Severity**: High
- **Affected**: All users attempting to access the application
- **Business Impact**: Unable to process invoices, accept payments, or access critical data

## Investigation Steps

### 1. Verify the Alert (2 minutes)
```bash
# Check current error rate
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/request_count" AND metric.labels.response_code_class="5xx"' \
  --project=PROJECT_ID

# View recent error logs
gcloud logging read \
  'resource.type="cloud_run_revision" AND severity>=ERROR' \
  --limit=50 \
  --format=json \
  --project=PROJECT_ID
```

### 2. Check Application Health (3 minutes)
```bash
# Check Cloud Run service status
gcloud run services describe invoice-ninja-web \
  --region=REGION \
  --project=PROJECT_ID \
  --format="table(status.conditions[].type, status.conditions[].status)"

# Check active revisions
gcloud run revisions list \
  --service=invoice-ninja-web \
  --region=REGION \
  --project=PROJECT_ID

# View recent deployments
gcloud run revisions list \
  --service=invoice-ninja-web \
  --limit=5 \
  --region=REGION \
  --project=PROJECT_ID \
  --format="table(metadata.name, status.conditions[].status, metadata.creationTimestamp)"
```

### 3. Check Dependencies (5 minutes)

#### Database
```bash
# Check Cloud SQL status
gcloud sql instances describe INSTANCE_NAME \
  --project=PROJECT_ID

# Check database connections
gcloud monitoring time-series list \
  --filter='metric.type="cloudsql.googleapis.com/database/mysql/connections"' \
  --project=PROJECT_ID

# Check for slow queries
gcloud logging read \
  'resource.type="cloud_sql_database" AND jsonPayload.message=~"slow query"' \
  --limit=20 \
  --project=PROJECT_ID
```

#### External Services
```bash
# Check if issue is with external dependencies
# Look for timeout errors in logs
gcloud logging read \
  'resource.type="cloud_run_revision" AND textPayload=~"timeout|connection refused"' \
  --limit=50 \
  --project=PROJECT_ID
```

### 4. Identify Error Patterns (5 minutes)
```bash
# Group errors by type
gcloud logging read \
  'resource.type="cloud_run_revision" AND severity>=ERROR' \
  --limit=100 \
  --format=json \
  --project=PROJECT_ID | \
  jq -r '.[] | .jsonPayload.message' | \
  sort | uniq -c | sort -rn

# Check error correlation with specific endpoints
gcloud logging read \
  'resource.type="cloud_run_revision" AND severity>=ERROR' \
  --limit=50 \
  --format=json \
  --project=PROJECT_ID | \
  jq -r '.[] | .httpRequest.requestUrl'
```

## Common Root Causes & Solutions

### 1. Recent Deployment Issue
**Symptoms**: Errors started immediately after deployment

**Solution**: Rollback
```bash
# Get previous revision
PREVIOUS_REVISION=$(gcloud run revisions list \
  --service=invoice-ninja-web \
  --region=REGION \
  --limit=2 \
  --format="value(metadata.name)" | tail -1)

# Rollback to previous revision
gcloud run services update-traffic invoice-ninja-web \
  --to-revisions=$PREVIOUS_REVISION=100 \
  --region=REGION \
  --project=PROJECT_ID

# Monitor error rate after rollback
watch -n 5 'gcloud monitoring time-series list --filter="metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\"" --project=PROJECT_ID'
```

### 2. Database Connection Pool Exhausted
**Symptoms**: `Too many connections` errors in logs

**Solution**: Scale database or adjust connection pool
```bash
# Check current connections
gcloud sql operations list \
  --instance=INSTANCE_NAME \
  --project=PROJECT_ID

# Temporarily increase max connections (requires restart)
gcloud sql instances patch INSTANCE_NAME \
  --database-flags=max_connections=250 \
  --project=PROJECT_ID

# Scale up Cloud Run to reduce connections per instance
gcloud run services update invoice-ninja-web \
  --max-instances=20 \
  --region=REGION \
  --project=PROJECT_ID
```

### 3. Memory/CPU Exhaustion
**Symptoms**: OOM (Out of Memory) errors, container restarts

**Solution**: Increase resources
```bash
# Check current resource usage
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/container/memory/utilizations"' \
  --project=PROJECT_ID

# Increase memory allocation
gcloud run services update invoice-ninja-web \
  --memory=1Gi \
  --cpu=2 \
  --region=REGION \
  --project=PROJECT_ID
```

### 4. External Service Failure
**Symptoms**: Timeouts to payment gateway, email service, etc.

**Solution**: Implement circuit breaker or graceful degradation
```bash
# Check which external service is failing
gcloud logging read \
  'resource.type="cloud_run_revision" AND textPayload=~"external|api.stripe|smtp"' \
  --limit=50 \
  --project=PROJECT_ID

# If critical, consider temporary workaround:
# - Disable payment processing temporarily
# - Queue emails for later retry
# - Enable maintenance mode if necessary
```

### 5. Configuration Error
**Symptoms**: Missing environment variables, incorrect secrets

**Solution**: Verify configuration
```bash
# Check environment variables
gcloud run services describe invoice-ninja-web \
  --region=REGION \
  --project=PROJECT_ID \
  --format="yaml(spec.template.spec.containers[].env)"

# Verify secrets are accessible
gcloud secrets versions access latest \
  --secret="app-key" \
  --project=PROJECT_ID

# Update configuration if needed
gcloud run services update invoice-ninja-web \
  --set-env-vars="APP_DEBUG=false" \
  --region=REGION \
  --project=PROJECT_ID
```

## Resolution Steps

### Immediate Actions (< 5 minutes)
1. ✅ Acknowledge alert in PagerDuty/incident management system
2. ✅ Post update in #incidents Slack channel
3. ✅ Determine severity and impact
4. ✅ If recent deployment, rollback immediately
5. ✅ Start incident timeline documentation

### Short-term Fix (5-15 minutes)
1. Identify root cause from common causes above
2. Apply appropriate solution
3. Monitor error rate for 5 minutes to confirm fix
4. If error rate drops below 1%, mark as resolved
5. If not resolved, escalate to senior engineer

### Long-term Fix (Post-incident)
1. Schedule RCA meeting within 24 hours
2. Identify preventive measures
3. Update monitoring/alerting if gaps found
4. Implement code fixes if application bug
5. Update documentation and runbooks

## Escalation Path

**Primary**: DevOps Team Lead (15 min response time)
- Slack: @devops-lead
- Phone: +1-XXX-XXX-XXXX
- PagerDuty: DevOps escalation policy

**Secondary**: CTO (30 min response time)
- Slack: @cto
- Phone: +1-XXX-XXX-XXXX

**Vendor Support** (if external service issue):
- GCP Support: Case via Console (Premium Support)
- Stripe Support: support@stripe.com
- SendGrid Support: support@sendgrid.com

## Communication Templates

### Initial Incident Update
```
🚨 INCIDENT: High Error Rate Detected

**Status**: Investigating
**Impact**: Users may experience errors when accessing the application
**Started**: [TIMESTAMP]
**Severity**: SEV2

We are actively investigating the cause and will provide updates every 15 minutes.
```

### Resolution Update
```
✅ RESOLVED: High Error Rate Incident

**Status**: Resolved
**Root Cause**: [Brief description]
**Resolution**: [What was done]
**Duration**: [Start time] to [End time]

A detailed RCA will be published within 24 hours. Thank you for your patience.
```

## Metrics to Capture
- Error rate % before/during/after
- Time to detect (alert trigger to acknowledgment)
- Time to identify (acknowledgment to root cause found)
- Time to resolve (root cause found to resolution)
- Number of users impacted
- Revenue impact (if applicable)

## Prevention Checklist
- [ ] Add more comprehensive testing before deployment
- [ ] Implement canary deployments
- [ ] Add circuit breakers for external services
- [ ] Review and optimize database queries
- [ ] Implement rate limiting if traffic spike caused issue
- [ ] Add more granular error monitoring
- [ ] Review resource allocation (CPU/memory)

## Related Documentation
- [Deployment Runbook](./deployment.md)
- [Database Runbook](./database_issues.md)
- [Cloud Run Troubleshooting Guide](./cloud_run_troubleshooting.md)
- [Incident Response Process](../docs/incident_response.md)

## Verification
After resolution, verify:
```bash
# 1. Error rate back to baseline (<0.1%)
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/request_count" AND metric.labels.response_code_class="5xx"' \
  --project=PROJECT_ID

# 2. Application responding normally
curl -I https://your-app.run.app/health

# 3. No errors in recent logs
gcloud logging read \
  'resource.type="cloud_run_revision" AND severity>=ERROR' \
  --limit=10 \
  --project=PROJECT_ID

# 4. SLO compliance restored
# Check monitoring dashboard: [DASHBOARD_URL]
```

## Post-Incident Tasks
- [ ] Complete RCA document
- [ ] Update this runbook with new learnings
- [ ] Schedule team review meeting
- [ ] Implement action items from RCA
- [ ] Update monitoring alerts if needed
- [ ] Send incident report to stakeholders

---

**Last Updated**: 2026-01-17  
**Maintained By**: DevOps Team  
**Review Frequency**: Quarterly or after each incident
