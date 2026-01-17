# Runbook: Database Connection Issues

## Severity
**SEV1** - Critical

## Symptoms
- Application unable to connect to database
- `Connection refused` or `Too many connections` errors
- Timeout errors on database queries
- Cloud Run containers failing health checks

## User Impact
- **Severity**: Critical
- **Affected**: All users
- **Business Impact**: Complete service outage - no access to application data

## Investigation Steps

### 1. Verify Database Status (2 minutes)
```bash
# Check Cloud SQL instance status
gcloud sql instances describe INSTANCE_NAME \
  --project=PROJECT_ID \
  --format="get(state)"

# Check database operation status
gcloud sql operations list \
  --instance=INSTANCE_NAME \
  --project=PROJECT_ID \
  --limit=5

# Test connection from gcloud
gcloud sql connect INSTANCE_NAME \
  --user=root \
  --project=PROJECT_ID
```

### 2. Check Connection Pool (3 minutes)
```bash
# Check current connections
gcloud monitoring time-series list \
  --filter='metric.type="cloudsql.googleapis.com/database/mysql/connections"' \
  --project=PROJECT_ID \
  --format="table(points[].value.int64Value)"

# Check max connections configuration
gcloud sql instances describe INSTANCE_NAME \
  --format="value(settings.databaseFlags)" \
  --project=PROJECT_ID | grep max_connections

# View connection sources in logs
gcloud logging read \
  'resource.type="cloudsql_database" AND textPayload=~"connection"' \
  --limit=50 \
  --project=PROJECT_ID
```

### 3. Check Network Connectivity (3 minutes)
```bash
# Verify VPC connector status
gcloud compute networks vpc-access connectors describe CONNECTOR_NAME \
  --region=REGION \
  --project=PROJECT_ID

# Check if Cloud SQL instance is accessible
gcloud sql instances describe INSTANCE_NAME \
  --format="get(ipAddresses[])" \
  --project=PROJECT_ID

# Test from Cloud Run (if possible)
gcloud run jobs execute db-connection-test \
  --region=REGION \
  --project=PROJECT_ID
```

## Common Root Causes & Solutions

### 1. Database Instance Down
**Symptoms**: Instance state is not `RUNNABLE`

**Solution**:
```bash
# Check why instance is down
gcloud sql operations list \
  --instance=INSTANCE_NAME \
  --project=PROJECT_ID \
  --filter="status!=DONE" \
  --limit=5

# If maintenance, wait for completion
# If unexpected stop, restart
gcloud sql instances restart INSTANCE_NAME \
  --project=PROJECT_ID

# Monitor restart progress
watch -n 10 'gcloud sql instances describe INSTANCE_NAME --format="get(state)" --project=PROJECT_ID'
```

### 2. Connection Pool Exhausted
**Symptoms**: `Too many connections` error

**Solution A**: Kill idle connections
```bash
# Connect to database
gcloud sql connect INSTANCE_NAME \
  --user=root \
  --project=PROJECT_ID

# In MySQL shell:
# Show current connections
SHOW PROCESSLIST;

# Kill idle connections (older than 60 seconds)
SELECT CONCAT('KILL ', id, ';') 
FROM information_schema.processlist 
WHERE command = 'Sleep' 
AND time > 60 
AND user != 'root';

# Execute the generated KILL statements
```

**Solution B**: Increase max connections
```bash
# Increase max_connections (requires instance restart)
gcloud sql instances patch INSTANCE_NAME \
  --database-flags=max_connections=300 \
  --project=PROJECT_ID

# Restart to apply
gcloud sql instances restart INSTANCE_NAME \
  --project=PROJECT_ID
```

**Solution C**: Scale down Cloud Run instances
```bash
# Temporarily reduce max instances to reduce connection pressure
gcloud run services update invoice-ninja-web \
  --max-instances=10 \
  --region=REGION \
  --project=PROJECT_ID
```

### 3. Network/VPC Connector Issue
**Symptoms**: `Connection timed out`, VPC connector errors

**Solution**:
```bash
# Check VPC connector health
gcloud compute networks vpc-access connectors describe CONNECTOR_NAME \
  --region=REGION \
  --project=PROJECT_ID \
  --format="get(state, minInstances, maxInstances)"

# If degraded, recreate connector (requires service update)
gcloud compute networks vpc-access connectors delete CONNECTOR_NAME \
  --region=REGION \
  --project=PROJECT_ID

gcloud compute networks vpc-access connectors create CONNECTOR_NAME \
  --region=REGION \
  --network=VPC_NAME \
  --range=10.8.0.0/28 \
  --project=PROJECT_ID

# Update Cloud Run to use new connector
gcloud run services update invoice-ninja-web \
  --vpc-connector=CONNECTOR_NAME \
  --region=REGION \
  --project=PROJECT_ID
```

### 4. Incorrect Credentials/Permissions
**Symptoms**: `Access denied` errors

**Solution**:
```bash
# Verify secret values
gcloud secrets versions access latest \
  --secret="db-password" \
  --project=PROJECT_ID

# Check service account permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:SA_EMAIL"

# Test connection with credentials
mysql -h DB_IP -u DB_USER -p

# If password incorrect, update secret
echo -n "NEW_PASSWORD" | gcloud secrets versions add db-password \
  --data-file=- \
  --project=PROJECT_ID

# Restart Cloud Run to pick up new secret
gcloud run services update invoice-ninja-web \
  --region=REGION \
  --project=PROJECT_ID
```

### 5. Database Overloaded
**Symptoms**: Slow query performance, high CPU/memory

**Solution**:
```bash
# Check database resource utilization
gcloud monitoring time-series list \
  --filter='metric.type="cloudsql.googleapis.com/database/cpu/utilization"' \
  --project=PROJECT_ID

gcloud monitoring time-series list \
  --filter='metric.type="cloudsql.googleapis.com/database/memory/utilization"' \
  --project=PROJECT_ID

# Identify slow queries
gcloud logging read \
  'resource.type="cloudsql_database" AND jsonPayload.message=~"slow query"' \
  --limit=20 \
  --project=PROJECT_ID

# Scale up database instance
gcloud sql instances patch INSTANCE_NAME \
  --tier=db-n1-standard-4 \
  --project=PROJECT_ID
```

## Resolution Steps

### Immediate Actions (< 2 minutes)
1. ✅ Declare SEV1 incident
2. ✅ Page on-call database engineer
3. ✅ Post in #incidents channel
4. ✅ Enable maintenance mode if possible

### Short-term Fix (2-10 minutes)
1. Identify root cause (use common causes above)
2. Apply appropriate solution
3. Verify database connectivity restored:
   ```bash
   # Test connection
   gcloud sql connect INSTANCE_NAME --user=root --project=PROJECT_ID
   ```
4. Monitor application recovery
5. Disable maintenance mode

### Long-term Fix
1. Conduct thorough RCA within 24 hours
2. Implement monitoring improvements
3. Review connection pool sizing
4. Optimize database queries if needed
5. Consider read replicas for scaling

## Emergency Failover Procedure

If primary database is unrecoverable:

```bash
# 1. Promote read replica to master
gcloud sql instances promote-replica REPLICA_NAME \
  --project=PROJECT_ID

# 2. Update connection string in secrets
NEW_DB_HOST=$(gcloud sql instances describe REPLICA_NAME \
  --format="get(ipAddresses[0].ipAddress)" \
  --project=PROJECT_ID)

echo "DB_HOST=$NEW_DB_HOST" | gcloud secrets versions add db-connection-string \
  --data-file=- \
  --project=PROJECT_ID

# 3. Update Cloud Run service
gcloud run services update invoice-ninja-web \
  --region=REGION \
  --project=PROJECT_ID

# 4. Verify application can connect
curl -f https://your-app.run.app/health
```

## Escalation Path

**Primary**: Database Engineer (5 min response)
- Slack: @db-engineer
- Phone: +1-XXX-XXX-XXXX
- PagerDuty: Database escalation

**Secondary**: Senior DevOps Engineer (10 min response)
- Slack: @senior-devops
- Phone: +1-XXX-XXX-XXXX

**Vendor**: Google Cloud Support
- Open P1 support case via Console
- Phone: Support hotline (Premium Support customers)

## Communication Template

```
🔴 SEV1 INCIDENT: Database Connection Failure

**Status**: Investigating / Mitigating / Resolved
**Impact**: Complete service outage
**Started**: [TIMESTAMP]
**ETA**: Under investigation

Current Status:
- [Brief description of issue]
- [What's being done]
- [Expected resolution time if known]

Updates will be provided every 5 minutes.
```

## Prevention Checklist
- [ ] Implement connection pool monitoring
- [ ] Set up proactive alerts for connection count
- [ ] Review and optimize slow queries
- [ ] Configure automatic failover with replicas
- [ ] Implement circuit breaker pattern in application
- [ ] Test disaster recovery procedures monthly
- [ ] Document connection limits per environment

## Related Documentation
- [Database Backup & Recovery](./database_backup_recovery.md)
- [High Availability Setup](../docs/high_availability.md)
- [Performance Tuning Guide](./database_performance.md)

## Post-Incident Tasks
- [ ] RCA completed within 24 hours
- [ ] Database health check added to monitoring
- [ ] Connection pool tuning reviewed
- [ ] Failover procedures tested
- [ ] Stakeholder report sent

---

**Last Updated**: 2026-01-17  
**Maintained By**: Database Team + DevOps  
**Review Frequency**: Monthly
