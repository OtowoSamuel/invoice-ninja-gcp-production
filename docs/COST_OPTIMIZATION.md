# =============================================================================
# Cost Optimization Strategy
# Learn: GCP cost analysis, optimization techniques, FinOps practices
# =============================================================================

## Cost Breakdown by Service

### Typical Monthly Costs (Production)

| Service | Configuration | Estimated Monthly Cost | Optimization |
|---------|--------------|----------------------|--------------|
| **Cloud Run (Web)** | 2-50 instances, 2CPU, 2Gi | $150-$500 | Scale to zero in dev/staging |
| **Cloud Run (Worker)** | 1-5 instances, 1CPU, 1Gi | $50-$150 | Right-size based on queue depth |
| **Cloud SQL** | db-custom-4-8192, 100GB SSD | $250-$350 | Stop dev/staging off-hours |
| **Memorystore (Redis)** | M1 (1GB) | $50 | Share across environments |
| **Cloud Storage** | 500GB standard, 1M operations | $10-$20 | Lifecycle policies |
| **Cloud Load Balancing** | 1M requests | $20-$40 | - |
| **Cloud Logging** | 50GB ingestion, 30-day retention | $25-$50 | Log sampling, shorter retention |
| **Secret Manager** | 1000 accesses/month | $1-$5 | Cache secrets in app |
| **Artifact Registry** | 10GB storage | $1 | Clean old images |
| **Monitoring & Metrics** | Custom metrics, dashboards | $10-$20 | Optimize metric cardinality |
| **VPC Networking** | Serverless VPC connector | $10 | - |
| **Cloud NAT** | 100GB egress | $10-$30 | Optimize external API calls |
| **Backups** | 200GB | $8 | Adjust retention |

**Total Estimated Cost**: $595 - $1,235/month

### Development Environment Cost Reduction
| Optimization | Monthly Savings |
|--------------|-----------------|
| Scale Cloud Run to zero | ~$100 |
| Stop Cloud SQL off-hours (12h/day) | ~$150 |
| Use smaller machine types | ~$80 |
| Share Redis across envs | ~$40 |
| Reduce log retention to 7 days | ~$30 |
**Total Dev Savings**: ~$400/month

## Cost Optimization Scripts

### 1. Stop Dev/Staging Resources After Hours

```bash
#!/bin/bash
# scripts/stop-dev-resources.sh
# Schedule with Cloud Scheduler: 0 18 * * 1-5 (6PM weekdays)

PROJECT_ID="invoice-ninja-prod"
ENVIRONMENTS=("dev" "staging")

for ENV in "${ENVIRONMENTS[@]}"; do
    echo "Stopping resources for $ENV environment..."
    
    # Stop Cloud SQL
    DB_INSTANCE="${ENV}-invoiceninja-db"
    echo "Stopping Cloud SQL: $DB_INSTANCE"
    gcloud sql instances patch "$DB_INSTANCE" \
        --activation-policy=NEVER \
        --project="$PROJECT_ID"
    
    # Scale Cloud Run to 0 min instances
    SERVICE_NAME="${ENV}-invoiceninja"
    echo "Scaling Cloud Run to 0: $SERVICE_NAME"
    gcloud run services update "$SERVICE_NAME" \
        --min-instances=0 \
        --project="$PROJECT_ID" \
        --region=us-central1
done

echo "✅ Dev/staging resources stopped"
```

### 2. Start Dev/Staging Resources in Morning

```bash
#!/bin/bash
# scripts/start-dev-resources.sh
# Schedule with Cloud Scheduler: 0 8 * * 1-5 (8AM weekdays)

PROJECT_ID="invoice-ninja-prod"
ENVIRONMENTS=("dev" "staging")

for ENV in "${ENVIRONMENTS[@]}"; do
    echo "Starting resources for $ENV environment..."
    
    # Start Cloud SQL
    DB_INSTANCE="${ENV}-invoiceninja-db"
    echo "Starting Cloud SQL: $DB_INSTANCE"
    gcloud sql instances patch "$DB_INSTANCE" \
        --activation-policy=ALWAYS \
        --project="$PROJECT_ID"
    
    # Scale Cloud Run to 1 min instance
    SERVICE_NAME="${ENV}-invoiceninja"
    echo "Scaling Cloud Run to 1: $SERVICE_NAME"
    gcloud run services update "$SERVICE_NAME" \
        --min-instances=1 \
        --project="$PROJECT_ID" \
        --region=us-central1
done

echo "✅ Dev/staging resources started"
```

### 3. Clean Old Container Images

```bash
#!/bin/bash
# scripts/cleanup-old-images.sh
# Keep only last 10 versions of each image

PROJECT_ID="invoice-ninja-prod"
REPOSITORY="invoiceninja"
LOCATION="us-central1"
KEEP_VERSIONS=10

IMAGES=$(gcloud artifacts docker images list \
    "${LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}" \
    --include-tags \
    --format="get(package)")

for IMAGE in $IMAGES; do
    echo "Cleaning old versions of: $IMAGE"
    
    # Get all versions sorted by creation time
    VERSIONS=$(gcloud artifacts docker images list "$IMAGE" \
        --sort-by=~CREATE_TIME \
        --format="get(version)" \
        --limit=999)
    
    # Skip first KEEP_VERSIONS, delete rest
    echo "$VERSIONS" | tail -n +$((KEEP_VERSIONS + 1)) | while read VERSION; do
        echo "  Deleting version: $VERSION"
        gcloud artifacts docker images delete "${IMAGE}@${VERSION}" --quiet
    done
done

echo "✅ Old images cleaned up"
```

### 4. Analyze Costs by Service

```bash
#!/bin/bash
# scripts/cost-analysis.sh

PROJECT_ID="invoice-ninja-prod"
START_DATE=$(date -d '30 days ago' +%Y-%m-%d)
END_DATE=$(date +%Y-%m-%d)

echo "===================================="
echo "Cost Analysis: $START_DATE to $END_DATE"
echo "===================================="

# Export billing data to BigQuery (one-time setup required)
echo -e "\n💰 Total Cost by Service (last 30 days):"
bq query --use_legacy_sql=false --format=prettyjson "
SELECT
  service.description AS service,
  ROUND(SUM(cost), 2) AS total_cost,
  ROUND(SUM(cost) / 30, 2) AS daily_avg_cost
FROM
  \`${PROJECT_ID}.billing_export.gcp_billing_export_v1_*\`
WHERE
  _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
    AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
  AND project.id = '${PROJECT_ID}'
GROUP BY
  service
ORDER BY
  total_cost DESC
LIMIT 20
"

echo -e "\n📊 Cost by Environment (last 30 days):"
bq query --use_legacy_sql=false --format=prettyjson "
SELECT
  labels.value AS environment,
  ROUND(SUM(cost), 2) AS total_cost
FROM
  \`${PROJECT_ID}.billing_export.gcp_billing_export_v1_*\`,
  UNNEST(labels) AS labels
WHERE
  _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY))
    AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
  AND labels.key = 'environment'
GROUP BY
  environment
ORDER BY
  total_cost DESC
"

echo -e "\n📈 Daily Cost Trend (last 7 days):"
bq query --use_legacy_sql=false --format=prettyjson "
SELECT
  FORMAT_DATE('%Y-%m-%d', DATE(usage_start_time)) AS date,
  ROUND(SUM(cost), 2) AS daily_cost
FROM
  \`${PROJECT_ID}.billing_export.gcp_billing_export_v1_*\`
WHERE
  _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY))
    AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
  AND project.id = '${PROJECT_ID}'
GROUP BY
  date
ORDER BY
  date DESC
"
```

### 5. Set Up Budget Alerts

```bash
#!/bin/bash
# scripts/setup-budget-alerts.sh

PROJECT_ID="invoice-ninja-prod"
BILLING_ACCOUNT_ID="your-billing-account-id"
ALERT_EMAIL="devops@example.com"

# Create budget with alerts at 50%, 80%, 100%
gcloud billing budgets create \
  --billing-account="$BILLING_ACCOUNT_ID" \
  --display-name="Invoice Ninja Monthly Budget" \
  --budget-amount=1000 \
  --threshold-rule=percent=50 \
  --threshold-rule=percent=80 \
  --threshold-rule=percent=100 \
  --all-updates-rule-pubsub-topic=projects/${PROJECT_ID}/topics/budget-alerts \
  --all-updates-rule-monitoring-notification-channels=projects/${PROJECT_ID}/notificationChannels/CHANNEL_ID
```

## Cloud Run Cost Optimization

### 1. Right-Size Resources

```yaml
# Development
resources:
  limits:
    cpu: "1"
    memory: 512Mi
  requests:
    cpu: "0.5"
    memory: 256Mi
min_instances: 0
max_instances: 3

# Production
resources:
  limits:
    cpu: "2"
    memory: 2Gi
  requests:
    cpu: "1"
    memory: 1Gi
min_instances: 2  # Only for critical services
max_instances: 20  # Set realistic limit
```

### 2. CPU Allocation Strategy

```bash
# Only allocate CPU during request processing (cheaper)
gcloud run services update invoiceninja \
  --cpu-throttling  # Default - CPU only during requests

# Always allocate CPU (more expensive, but better for background tasks)
gcloud run services update invoiceninja \
  --no-cpu-throttling  # Use for workers processing queue
```

### 3. Request Timeout Optimization

```bash
# Reduce timeout for fast endpoints
gcloud run services update invoiceninja \
  --timeout=60s  # Instead of default 300s

# This reduces cost for stalled requests
```

### 4. Use Second Gen Execution Environment

```bash
# Gen2 has better cold start and resource utilization
gcloud run services update invoiceninja \
  --execution-environment=gen2
```

## Cloud SQL Cost Optimization

### 1. Right-Size Machine Type

```bash
# Analyze current usage
gcloud sql operations list --instance=invoiceninja-db --limit=10

# Check CPU and memory utilization
gcloud monitoring time-series list \
  --filter='metric.type="cloudsql.googleapis.com/database/cpu/utilization"' \
  --start-time="7d"

# Resize if underutilized
gcloud sql instances patch invoiceninja-db \
  --tier=db-custom-2-8192  # 2 vCPU, 8GB RAM
```

### 2. Storage Optimization

```bash
# Enable automatic storage increase (but set max limit)
gcloud sql instances patch invoiceninja-db \
  --storage-auto-increase \
  --storage-auto-increase-limit=200

# Use SSD only if needed, HDD is cheaper
gcloud sql instances patch invoiceninja-db \
  --storage-type=HDD  # For dev/staging
```

### 3. Backup Retention

```bash
# Reduce backup retention (default is 7 days)
gcloud sql instances patch invoiceninja-db \
  --backup-start-time=03:00 \
  --retained-backups-count=7  # Keep only 7 backups

# Disable automatic backups for dev
gcloud sql instances patch invoiceninja-dev-db \
  --no-backup
```

### 4. High Availability

```bash
# Disable HA for dev/staging (50% cost savings)
gcloud sql instances patch invoiceninja-dev-db \
  --no-availability-type=REGIONAL

# Enable HA only for production
gcloud sql instances patch invoiceninja-prod-db \
  --availability-type=REGIONAL
```

## Logging & Monitoring Cost Optimization

### 1. Log Exclusion Filters

```bash
# Exclude health check logs
gcloud logging sinks create exclude-health-checks \
  sink.googleapis.com/exclude \
  --log-filter='
    resource.type="cloud_run_revision"
    AND httpRequest.requestUrl=~"/health"
  '

# Exclude debug logs in production
gcloud logging sinks create exclude-debug-logs \
  sink.googleapis.com/exclude \
  --log-filter='
    severity="DEBUG"
    AND resource.labels.service_name="invoiceninja"
  '
```

### 2. Log Sampling

```python
# application logging with sampling
import random
import logging

def should_log_debug():
    # Only log 10% of debug messages
    return random.random() < 0.1

if should_log_debug() or severity >= logging.INFO:
    logger.log(severity, message)
```

### 3. Reduce Log Retention

```bash
# Set retention to 30 days (default is 30 days)
gcloud logging buckets update _Default \
  --location=global \
  --retention-days=30

# Use shorter retention for non-critical logs
gcloud logging buckets create short-term-logs \
  --location=us-central1 \
  --retention-days=7
```

### 4. Optimize Metric Cardinality

```yaml
# BAD - High cardinality (creates many time series)
metrics:
  - name: request_count
    labels:
      - user_id  # Could be thousands of unique values
      - request_id  # Unique per request

# GOOD - Low cardinality
metrics:
  - name: request_count
    labels:
      - environment  # dev, staging, prod
      - status_code_class  # 2xx, 3xx, 4xx, 5xx
```

## Networking Cost Optimization

### 1. Minimize Data Egress

```yaml
# Use regional resources (same region as Cloud Run)
- Cloud SQL: us-central1
- Memorystore: us-central1
- Cloud Storage: us-central1
- External APIs: Consider caching

# Egress pricing:
# - Same zone: Free
# - Same region: $0.01/GB
# - Cross-region: $0.02/GB
# - Internet: $0.12/GB
```

### 2. Cloud CDN for Static Assets

```bash
# Enable Cloud CDN to reduce origin requests
gcloud compute backend-services update invoiceninja-backend \
  --enable-cdn \
  --cache-mode=CACHE_ALL_STATIC
```

### 3. Optimize External API Calls

```php
// Cache external API responses
$exchangeRates = Cache::remember('exchange_rates', 3600, function() {
    return ExternalAPI::getExchangeRates();
});

// Batch API calls where possible
$results = ExternalAPI::batch([
    ['endpoint' => '/users', 'method' => 'GET'],
    ['endpoint' => '/invoices', 'method' => 'GET'],
]);
```

## Storage Cost Optimization

### 1. Lifecycle Policies

```bash
# Auto-delete old files
gsutil lifecycle set lifecycle-policy.json gs://invoiceninja-uploads

# lifecycle-policy.json
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "age": 365,
          "matchesPrefix": ["temp/"]
        }
      },
      {
        "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
        "condition": {
          "age": 90,
          "matchesStorageClass": ["STANDARD"]
        }
      }
    ]
  }
}
```

### 2. Storage Class Selection

```yaml
# Use appropriate storage class
- Frequently accessed: STANDARD ($0.020/GB/month)
- Monthly access: NEARLINE ($0.010/GB/month)
- Yearly access: COLDLINE ($0.004/GB/month)
- Archival: ARCHIVE ($0.0012/GB/month)
```

## Cost Tracking Labels

```bash
# Apply consistent labels for cost attribution
gcloud run services update invoiceninja \
  --labels=environment=prod,team=platform,cost-center=engineering

gcloud sql instances patch invoiceninja-db \
  --labels=environment=prod,team=platform,cost-center=engineering

# Query costs by label
bq query --use_legacy_sql=false "
SELECT
  labels.value AS team,
  SUM(cost) AS total_cost
FROM
  \`billing_export.gcp_billing_export_v1_*\`,
  UNNEST(labels) AS labels
WHERE
  labels.key = 'team'
GROUP BY
  team
"
```

## Cost Monitoring Dashboard

```bash
# Create custom dashboard for cost tracking
gcloud monitoring dashboards create --config-from-file=cost-dashboard.json
```

```json
{
  "displayName": "Cost Monitoring Dashboard",
  "gridLayout": {
    "widgets": [
      {
        "title": "Daily Cost Trend",
        "xyChart": {
          "dataSets": [{
            "timeSeriesQuery": {
              "timeSeriesFilter": {
                "filter": "metric.type=\"billing.googleapis.com/cost\"",
                "aggregation": {
                  "alignmentPeriod": "86400s",
                  "perSeriesAligner": "ALIGN_SUM"
                }
              }
            }
          }]
        }
      },
      {
        "title": "Cost by Service",
        "pieChart": {
          "dataSets": [{
            "timeSeriesQuery": {
              "timeSeriesFilter": {
                "filter": "metric.type=\"billing.googleapis.com/cost\"",
                "aggregation": {
                  "alignmentPeriod": "2592000s",
                  "crossSeriesReducer": "REDUCE_SUM",
                  "groupByFields": ["resource.label.service"]
                }
              }
            }
          }]
        }
      }
    ]
  }
}
```

## FinOps Best Practices

### 1. Regular Cost Reviews
- **Daily**: Check for cost anomalies
- **Weekly**: Review cost trends by service
- **Monthly**: Analyze cost by environment/team
- **Quarterly**: Right-size resources, review commitments

### 2. Cost Allocation
```bash
# Tag all resources with:
- environment (dev/staging/prod)
- team (platform/product/data)
- cost-center (engineering/sales/marketing)
- project (invoiceninja/reporting/analytics)
```

### 3. Committed Use Discounts
```bash
# If running 24/7, consider committed use contracts
# - 1 year: 37% discount
# - 3 years: 55% discount

# Example: $1000/month workload
# - On-demand: $12,000/year
# - 1-year commit: $7,560/year (save $4,440)
# - 3-year commit: $5,400/year (save $6,600)
```

### 4. Idle Resource Detection
```bash
#!/bin/bash
# Find idle Cloud Run services (zero requests last 7 days)
gcloud run services list --format=json | jq -r '.[] | .metadata.name' | while read SERVICE; do
    REQUESTS=$(gcloud monitoring time-series list \
        --filter="metric.type=\"run.googleapis.com/request_count\" AND resource.labels.service_name=\"$SERVICE\"" \
        --start-time="7d" \
        --format="value(points[].value.int64Value)")
    
    if [ -z "$REQUESTS" ] || [ "$REQUESTS" -eq 0 ]; then
        echo "⚠️ Idle service: $SERVICE (consider deleting)"
    fi
done
```

## Target Monthly Costs

| Environment | Target | Actual | Status |
|-------------|--------|--------|--------|
| Development | $100 | - | ⏱️ Monitor |
| Staging | $200 | - | ⏱️ Monitor |
| Production | $800 | - | ⏱️ Monitor |
| **Total** | **$1,100** | - | ⏱️ Monitor |

## Cost Reduction Checklist

- [ ] Scale Cloud Run to zero in dev/staging
- [ ] Stop Cloud SQL during off-hours (dev/staging)
- [ ] Clean old container images (weekly)
- [ ] Apply log exclusion filters
- [ ] Reduce log retention to 30 days
- [ ] Use appropriate storage classes
- [ ] Enable Cloud CDN for static assets
- [ ] Right-size Cloud SQL instances
- [ ] Disable HA for non-prod databases
- [ ] Apply consistent resource labels
- [ ] Set up budget alerts
- [ ] Review costs weekly
- [ ] Optimize metric cardinality
- [ ] Cache external API calls
- [ ] Use regional resources (same region)
