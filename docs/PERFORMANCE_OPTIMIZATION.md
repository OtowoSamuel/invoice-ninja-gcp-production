# =============================================================================
# Cloud Run Autoscaling & Performance Configuration
# Learn: Concurrency tuning, cold starts, resource optimization
# =============================================================================

# Performance-optimized Cloud Run configuration

## Autoscaling Configuration

### Development Environment
```yaml
min_instances: 0  # Cost optimization - scale to zero
max_instances: 5
concurrency: 80   # Requests per container
cpu: 1
memory: 512Mi
timeout: 300s     # 5 minutes
startup_cpu_boost: true
execution_environment: gen2
```

### Staging Environment
```yaml
min_instances: 1  # One warm instance
max_instances: 10
concurrency: 100
cpu: 2
memory: 1Gi
timeout: 300s
startup_cpu_boost: true
execution_environment: gen2
```

### Production Environment
```yaml
min_instances: 2  # High availability
max_instances: 50
concurrency: 120  # Tuned for Laravel
cpu: 2
memory: 2Gi
timeout: 300s
startup_cpu_boost: true
execution_environment: gen2
cpu_throttling: false  # Always allocate CPU
```

## Concurrency Tuning Guide

### Finding Optimal Concurrency

1. **Start with baseline**: 80 concurrent requests
2. **Load test** with incremental increases
3. **Monitor**:
   - Response time (p50, p95, p99)
   - Error rate
   - Container CPU/memory usage
   - Database connection pool utilization

4. **Adjust based on**:
   - Application type (CPU-bound vs I/O-bound)
   - Database connection pool size
   - External API call patterns
   - Memory usage per request

### Concurrency Formula
```
Optimal Concurrency = (Available Memory - Base Memory) / Memory Per Request
Max Connections = Concurrency × Max Instances
```

### Example Calculation
```
Memory: 2Gi = 2048 MB
Base Memory (PHP-FPM + overhead): 256 MB
Available: 1792 MB
Memory per request: ~15 MB

Optimal Concurrency = 1792 / 15 ≈ 119 requests
```

## Connection Pooling Configuration

### Laravel Database Configuration
```php
// config/database.php
'connections' => [
    'pgsql' => [
        'driver' => 'pgsql',
        'host' => env('DB_HOST'),
        'port' => env('DB_PORT', '5432'),
        'database' => env('DB_DATABASE'),
        'username' => env('DB_USERNAME'),
        'password' => env('DB_PASSWORD'),
        'charset' => 'utf8',
        'prefix' => '',
        'prefix_indexes' => true,
        'schema' => 'public',
        'sslmode' => 'prefer',
        
        // Connection pool settings
        'options' => [
            PDO::ATTR_PERSISTENT => false,  // Don't use persistent connections with Cloud SQL
            PDO::ATTR_TIMEOUT => 3,
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        ],
        
        // Pool configuration
        'pool' => [
            'min' => 2,
            'max' => 10,  // Per container
        ],
    ],
],
```

### Connection Pool Sizing
```
Total DB Connections = Concurrency × Max Instances × 1.2 (overhead)

Example:
- Concurrency: 100
- Max Instances: 20
- Total connections: 100 × 20 × 1.2 = 2,400

Cloud SQL max_connections should be >= 2,500
```

## Cold Start Optimization

### 1. Use Second Generation Execution Environment
```bash
gcloud run services update invoiceninja \
  --execution-environment=gen2 \
  --startup-cpu-boost
```

### 2. Optimize Container Image
```dockerfile
# Multi-stage build to reduce image size
FROM composer:2 as vendor
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader --no-scripts

FROM php:8.2-fpm-alpine
# Copy only production dependencies
COPY --from=vendor /app/vendor /var/www/html/vendor

# Precompile optimizations
RUN php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache && \
    php artisan event:cache
```

### 3. Warm-Up Requests
```bash
# Cloud Scheduler job to keep instances warm
gcloud scheduler jobs create http warm-up-invoiceninja \
  --schedule="*/5 * * * *" \
  --uri="https://invoiceninja.run.app/health" \
  --http-method=GET
```

### 4. Use Min Instances for Critical Services
```bash
# Production: Always keep 2 instances warm
gcloud run services update invoiceninja \
  --min-instances=2
```

## Caching Strategy

### 1. Application-Level Caching (Redis)
```php
// Bootstrap cache configuration
'redis' => [
    'client' => env('REDIS_CLIENT', 'phpredis'),
    'options' => [
        'cluster' => env('REDIS_CLUSTER', 'redis'),
        'prefix' => env('REDIS_PREFIX', 'invoiceninja_'),
    ],
    'default' => [
        'url' => env('REDIS_URL'),
        'host' => env('REDIS_HOST', '127.0.0.1'),
        'password' => env('REDIS_PASSWORD'),
        'port' => env('REDIS_PORT', '6379'),
        'database' => env('REDIS_DB', '0'),
        'read_timeout' => 60,
        'timeout' => 5,
        'persistent' => true,
        'retry_interval' => 100,
    ],
    'cache' => [
        'url' => env('REDIS_URL'),
        'host' => env('REDIS_HOST', '127.0.0.1'),
        'password' => env('REDIS_PASSWORD'),
        'port' => env('REDIS_PORT', '6379'),
        'database' => env('REDIS_CACHE_DB', '1'),
    ],
],
```

### 2. Query Result Caching
```php
// Cache expensive queries
$invoices = Cache::remember('user_invoices_' . $userId, 3600, function () use ($userId) {
    return Invoice::where('user_id', $userId)
        ->with(['client', 'items'])
        ->get();
});
```

### 3. HTTP Caching Headers
```php
// app/Http/Middleware/SetCacheHeaders.php
public function handle($request, Closure $next)
{
    $response = $next($request);
    
    if ($request->is('api/static/*')) {
        $response->header('Cache-Control', 'public, max-age=3600');
        $response->header('ETag', md5($response->getContent()));
    }
    
    return $response;
}
```

### 4. CDN Configuration (Cloud CDN)
```bash
# Enable Cloud CDN for static assets
gcloud compute backend-services update BACKEND_SERVICE \
  --enable-cdn \
  --cache-mode=CACHE_ALL_STATIC \
  --default-ttl=3600 \
  --max-ttl=86400
```

## Performance Testing Scripts

### Load Test with Apache Bench
```bash
#!/bin/bash
# load-test-ab.sh

URL="https://invoiceninja.run.app"
CONCURRENT=100
REQUESTS=10000

echo "Running load test: $REQUESTS requests, $CONCURRENT concurrent"
ab -n $REQUESTS -c $CONCURRENT -g results.tsv $URL/

# Analyze results
echo "Analyzing results..."
awk '{sum+=$9; count++} END {print "Average response time:", sum/count, "ms"}' results.tsv
```

### Load Test with k6
```javascript
// load-test-k6.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 },  // Ramp up to 100 users
    { duration: '5m', target: 100 },  // Stay at 100 users
    { duration: '2m', target: 200 },  // Ramp up to 200 users
    { duration: '5m', target: 200 },  // Stay at 200 users
    { duration: '2m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% of requests under 500ms
    http_req_failed: ['rate<0.05'],    // Error rate < 5%
  },
};

export default function() {
  let response = http.get('https://invoiceninja.run.app');
  
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  sleep(1);
}
```

### Run k6 Load Test
```bash
k6 run --out json=results.json load-test-k6.js

# Analyze results
k6 run --out cloud load-test-k6.js  # Send to k6 Cloud for analysis
```

### Continuous Load Testing with Artillery
```yaml
# artillery-config.yml
config:
  target: "https://invoiceninja.run.app"
  phases:
    - duration: 60
      arrivalRate: 10
      name: "Warm up"
    - duration: 300
      arrivalRate: 50
      name: "Sustained load"
    - duration: 120
      arrivalRate: 100
      name: "Spike test"
  processor: "./custom-functions.js"
  
scenarios:
  - name: "Homepage"
    weight: 40
    flow:
      - get:
          url: "/"
      
  - name: "Dashboard"
    weight: 30
    flow:
      - post:
          url: "/login"
          json:
            email: "{{ $randomEmail }}"
            password: "password"
      - get:
          url: "/dashboard"
      
  - name: "Create Invoice"
    weight: 30
    flow:
      - post:
          url: "/api/invoices"
          json:
            client_id: 1
            amount: 100
```

### Run Artillery
```bash
artillery run artillery-config.yml --output report.json
artillery report report.json  # Generate HTML report
```

## Performance Monitoring Script

```bash
#!/bin/bash
# monitor-performance.sh

PROJECT_ID="invoice-ninja-prod"
SERVICE_NAME="invoiceninja"

echo "===================================="
echo "Performance Metrics for $SERVICE_NAME"
echo "===================================="

# Get average response time (last 1 hour)
echo -e "\n📊 Average Response Time (last hour):"
gcloud monitoring time-series list \
  --filter="metric.type=\"run.googleapis.com/request_latencies\" AND resource.labels.service_name=\"$SERVICE_NAME\"" \
  --start-time="$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --format="table(points[].value.distributionValue.mean)"

# Get error rate
echo -e "\n❌ Error Rate (last hour):"
gcloud monitoring time-series list \
  --filter="metric.type=\"run.googleapis.com/request_count\" AND resource.labels.service_name=\"$SERVICE_NAME\" AND metric.labels.response_code_class=\"5xx\"" \
  --start-time="$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --format="table(points[].value.int64Value)"

# Get instance count
echo -e "\n🖥️ Container Instances (current):"
gcloud monitoring time-series list \
  --filter="metric.type=\"run.googleapis.com/container/instance_count\" AND resource.labels.service_name=\"$SERVICE_NAME\"" \
  --start-time="$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --format="table(points[].value.int64Value)"

# Get memory utilization
echo -e "\n💾 Memory Utilization (current):"
gcloud monitoring time-series list \
  --filter="metric.type=\"run.googleapis.com/container/memory/utilizations\" AND resource.labels.service_name=\"$SERVICE_NAME\"" \
  --start-time="$(date -u -d '5 minutes ago' +%Y-%m-%dT%H:%M:%SZ)" \
  --format="table(points[].value.distributionValue.mean)"

echo -e "\n✅ Performance check complete!"
```

## Resource Right-Sizing Guide

### 1. Analyze Current Usage
```bash
# CPU utilization over time
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/container/cpu/utilizations"' \
  --start-time="7d"

# Memory utilization over time
gcloud monitoring time-series list \
  --filter='metric.type="run.googleapis.com/container/memory/utilizations"' \
  --start-time="7d"
```

### 2. Recommendations

| Scenario | CPU | Memory | Concurrency |
|----------|-----|--------|-------------|
| Low traffic (<100 req/min) | 1 | 512Mi | 80 |
| Medium traffic (100-1000 req/min) | 1-2 | 1Gi | 100 |
| High traffic (>1000 req/min) | 2 | 2Gi | 120 |
| CPU-intensive (PDF generation) | 4 | 2Gi | 40 |
| Memory-intensive (large reports) | 2 | 4Gi | 60 |

### 3. Cost vs Performance Trade-offs

```
Lower Cost:
- min_instances: 0
- cpu: 1
- memory: 512Mi
- concurrency: 80

Balanced:
- min_instances: 1
- cpu: 1-2
- memory: 1Gi
- concurrency: 100

Performance:
- min_instances: 2+
- cpu: 2
- memory: 2Gi
- concurrency: 120
- cpu_throttling: false
```

## Health Check Configuration

```yaml
# Health check endpoint
startupProbe:
  httpGet:
    path: /health/startup
    port: 8080
  initialDelaySeconds: 0
  periodSeconds: 1
  timeoutSeconds: 1
  failureThreshold: 3

livenessProbe:
  httpGet:
    path: /health/live
    port: 8080
  initialDelaySeconds: 0
  periodSeconds: 10
  timeoutSeconds: 1
  failureThreshold: 3
```

### Laravel Health Check Routes
```php
// routes/web.php
Route::get('/health', function () {
    return response()->json(['status' => 'healthy'], 200);
});

Route::get('/health/startup', function () {
    // Check if application is ready
    try {
        DB::connection()->getPdo();
        return response()->json(['status' => 'ready'], 200);
    } catch (\Exception $e) {
        return response()->json(['status' => 'not ready'], 503);
    }
});

Route::get('/health/live', function () {
    // Basic liveness check
    return response()->json(['status' => 'alive'], 200);
});
```
