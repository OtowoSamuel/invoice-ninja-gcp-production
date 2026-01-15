# Invoice Ninja GCP Production Deployment - Deep Learning Path

> **Mission**: Master senior DevOps engineering skills through deploying a production-grade Laravel FinTech application on GCP with enterprise-level CI/CD, security, and observability.

## 📋 Project Overview

**Application**: Invoice Ninja (Open Source Invoicing & Payments Platform)
- **Tech Stack**: Laravel PHP, MySQL/PostgreSQL, Redis, Queue Workers
- **Why This App**: Real FinTech use case, payment processing, compliance requirements, production-ready architecture
- **Timeline**: 3-4 Days Intensive
- **Outcome**: Portfolio-ready production deployment + deep DevOps expertise

---

## 🎯 Learning Objectives Mapped to Job Requirements

| Job Requirement | Learning Module | Hands-On Practice |
|----------------|-----------------|-------------------|
| 4+ years DevOps experience | Complete production deployment | End-to-end architecture ownership |
| GCP cloud-native architecture | Multi-service GCP infrastructure | Cloud Run, Cloud SQL, Pub/Sub, VPC |
| GitLab CI/CD at scale | Advanced pipelines with templates | Multi-environment, security scanning |
| Docker containerization | Multi-stage builds, optimization | Application + workers containerization |
| Microservices & workers | Queue workers, event-driven | Laravel queues, background jobs |
| Autoscaling & load balancing | Cloud Run concurrency tuning | Traffic management, cost optimization |
| SAST/DAST/secrets scanning | Security pipeline integration | Trivy, SonarQube, GitLeaks, OWASP ZAP |
| IaC with Terraform | Complete infrastructure as code | Modules, state management, best practices |
| IAM & secrets management | GCP IAM + Secret Manager | Service accounts, least privilege access |
| Observability & SLOs | Cloud Monitoring & Logging | Metrics, alerts, dashboards, error budgets |
| Incident response & DR | Runbooks, backup strategies | RCA templates, disaster recovery testing |
| Database management | Cloud SQL operations | Backups, PITR, replication, tuning |
| Laravel applications | Deployment patterns | Queue workers, config management |
| FinTech/Payments platforms | Invoice Ninja deployment | Payment processing, compliance |
| ISO 27001/SOC 2 compliance | Audit readiness | Security controls, documentation |

---

## 🛠️ Prerequisites

### Required Tools
- [ ] GCP Account with billing enabled (Free tier sufficient for learning)
- [ ] GitLab account (free tier)
- [ ] Local development environment:
  - [ ] Docker & Docker Compose
  - [ ] Terraform 1.5+
  - [ ] gcloud CLI
  - [ ] kubectl
  - [ ] git
  - [ ] VS Code (or preferred IDE)

### Required Knowledge (You'll Learn Deeper)
- Basic Linux commands
- Basic Docker concepts
- Basic Git workflow
- Basic understanding of CI/CD
- Basic cloud concepts

### GCP Services We'll Use
- Cloud Run (serverless containers)
- Cloud SQL (managed PostgreSQL)
- Cloud Storage (backups, assets)
- Cloud Pub/Sub (event messaging)
- Secret Manager (secrets management)
- Cloud Logging & Monitoring
- Cloud Load Balancing
- VPC & Networking
- Cloud Build (optional)
- Artifact Registry (container images)

---

## 📅 Day 1: Foundation & Infrastructure (8-10 hours)

### Phase 1.1: Project Setup & Understanding (1-2 hours)

#### **Learning Objectives**
- Understand Invoice Ninja architecture
- Analyze application dependencies
- Plan cloud-native deployment strategy

#### **Tasks**

**Step 1: Fork & Analyze Invoice Ninja**
```bash
# Clone Invoice Ninja
git clone https://github.com/invoiceninja/invoiceninja.git
cd invoiceninja

# Analyze the application structure
ls -la
cat composer.json  # Understand PHP dependencies
cat .env.example   # Understand configuration requirements
```

**Deep Learning Points:**
- 📖 Read Laravel documentation on queue workers
- 📖 Understand Invoice Ninja's architecture (web app + queue workers)
- 📖 Identify external dependencies (database, cache, email, storage)
- 📖 List environment variables needed for production

**Exercise 1.1**: Create an architecture diagram
```
Task: Draw the application architecture showing:
- Web application containers
- Queue worker containers
- Database (Cloud SQL)
- Cache (Redis/Memorystore)
- Storage (Cloud Storage)
- External services (email, payment gateways)
```

---

### Phase 1.2: GCP Project Setup (1 hour)

#### **Learning Objectives**
- Understand GCP project organization
- Learn IAM best practices
- Set up billing alerts

#### **Tasks**

**Step 1: Create GCP Project**
```bash
# Set project variables
export PROJECT_ID="invoice-ninja-prod"
export REGION="us-central1"
export ZONE="us-central1-a"

# Create project
gcloud projects create $PROJECT_ID --name="Invoice Ninja Production"

# Set default project
gcloud config set project $PROJECT_ID

# Link billing account (replace with your billing account ID)
gcloud billing projects link $PROJECT_ID --billing-account=YOUR_BILLING_ACCOUNT_ID
```

**Step 2: Enable Required APIs**
```bash
# Enable all required GCP APIs
gcloud services enable \
  run.googleapis.com \
  sql-component.googleapis.com \
  sqladmin.googleapis.com \
  compute.googleapis.com \
  vpcaccess.googleapis.com \
  servicenetworking.googleapis.com \
  secretmanager.googleapis.com \
  cloudresourcemanager.googleapis.com \
  artifactregistry.googleapis.com \
  cloudscheduler.googleapis.com \
  pubsub.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com
```

**Deep Learning Points:**
- 📖 Why we need each API
- 📖 GCP service dependencies
- 📖 Cost implications of each service

**Exercise 1.2**: Set up billing alerts
```
Task: Configure budget alerts for $50, $100, $200
- Understand GCP pricing model
- Learn cost monitoring best practices
```

---

### Phase 1.3: Terraform Infrastructure Setup (3-4 hours)

#### **Learning Objectives**
- Master Terraform module design
- Understand GCP networking
- Learn infrastructure best practices

#### **Tasks**

**Step 1: Initialize Terraform Project Structure**
```
terraform/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── outputs.tf
│   ├── staging/
│   └── prod/
├── modules/
│   ├── networking/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── cloud-sql/
│   ├── cloud-run/
│   ├── secrets/
│   ├── monitoring/
│   └── iam/
└── README.md
```

**Step 2: Networking Module**
```hcl
# modules/networking/main.tf
# Learn: VPC design, subnet CIDR planning, private service connection
```

**Deep Learning Points:**
- 📖 VPC peering vs VPC service controls
- 📖 Private Google Access
- 📖 Serverless VPC Access connector
- 📖 IP address planning
- 📖 Network security best practices

**Step 3: Cloud SQL Module**
```hcl
# modules/cloud-sql/main.tf
# Learn: High availability, backups, PITR, replication
```

**Deep Learning Points:**
- 📖 Cloud SQL vs self-managed databases
- 📖 Backup strategies (automated vs on-demand)
- 📖 Point-in-Time Recovery (PITR)
- 📖 Read replicas for scaling
- 📖 Connection methods (public IP, private IP, Cloud SQL Proxy)
- 📖 Performance tuning (flags, machine types)

**Step 4: Secret Manager Module**
```hcl
# modules/secrets/main.tf
# Learn: Secret lifecycle, rotation, access control
```

**Deep Learning Points:**
- 📖 Secret vs ConfigMap
- 📖 Secret versioning
- 📖 Automatic rotation strategies
- 📖 Access audit logging
- 📖 Integration with Cloud Run

**Step 5: IAM Module**
```hcl
# modules/iam/main.tf
# Learn: Service accounts, custom roles, least privilege
```

**Deep Learning Points:**
- 📖 Service account best practices
- 📖 Workload Identity
- 📖 Custom IAM roles design
- 📖 IAM policy hierarchy
- 📖 Access reviews and auditing

**Exercise 1.3**: Deploy dev environment
```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

**Validation Checklist:**
- [ ] VPC and subnets created
- [ ] Cloud SQL instance running
- [ ] Secrets created in Secret Manager
- [ ] Service accounts created with correct IAM
- [ ] Network connectivity verified

---

### Phase 1.4: Dockerization (2-3 hours)

#### **Learning Objectives**
- Master multi-stage Docker builds
- Understand container security
- Optimize image size and build time

#### **Tasks**

**Step 1: Multi-Stage Dockerfile for Web App**
```dockerfile
# docker/web/Dockerfile
# Learn: Build optimization, layer caching, security hardening
```

**Deep Learning Points:**
- 📖 Multi-stage builds for smaller images
- 📖 Layer caching strategies
- 📖 Non-root user containers
- 📖 Security scanning best practices
- 📖 .dockerignore optimization

**Step 2: Queue Worker Dockerfile**
```dockerfile
# docker/worker/Dockerfile
# Learn: Long-running process management, graceful shutdown
```

**Deep Learning Points:**
- 📖 Queue worker vs web server differences
- 📖 Signal handling (SIGTERM, SIGKILL)
- 📖 Graceful shutdown patterns
- 📖 Health checks for workers

**Step 3: Docker Compose for Local Development**
```yaml
# docker-compose.yml
# Learn: Local development environment, service dependencies
```

**Deep Learning Points:**
- 📖 Docker networks
- 📖 Volume management
- 📖 Environment variable injection
- 📖 Service dependencies and health checks

**Exercise 1.4**: Test locally
```bash
docker-compose up --build
# Access http://localhost:8000
# Verify database connection
# Test queue processing
```

**Validation Checklist:**
- [ ] Application starts successfully
- [ ] Database migrations run
- [ ] Queue worker processes jobs
- [ ] No security vulnerabilities (run `docker scan`)

---

### Phase 1.5: Basic GitLab CI/CD Pipeline (1-2 hours)

#### **Learning Objectives**
- Understand GitLab CI/CD structure
- Learn pipeline optimization
- Implement basic security scanning

#### **Tasks**

**Step 1: Create .gitlab-ci.yml**
```yaml
# .gitlab-ci.yml
# Learn: Pipeline stages, artifacts, caching
```

**Deep Learning Points:**
- 📖 GitLab pipeline stages and jobs
- 📖 Artifact management
- 📖 Cache vs artifacts
- 📖 Pipeline optimization techniques
- 📖 Parallel execution

**Step 2: Build and Push Images**
```yaml
build:
  stage: build
  # Learn: Image tagging strategies, registry management
```

**Deep Learning Points:**
- 📖 Semantic versioning for images
- 📖 GCP Artifact Registry vs Docker Hub
- 📖 Image retention policies
- 📖 Build reproducibility

**Exercise 1.5**: First deployment
```yaml
deploy:dev:
  stage: deploy
  # Deploy to Cloud Run dev environment
```

**Validation Checklist:**
- [ ] Pipeline runs successfully
- [ ] Images pushed to Artifact Registry
- [ ] Application deployed to Cloud Run
- [ ] Health check passes

---

## 📅 Day 2: Advanced DevOps & Security (8-10 hours)

### Phase 2.1: Advanced GitLab CI/CD with Templates (2-3 hours)

#### **Learning Objectives**
- Master GitLab CI/CD templates and includes
- Understand pipeline variables and environments
- Learn deployment strategies

#### **Tasks**

**Step 1: Create Reusable Pipeline Templates**
```
.gitlab/
├── ci-templates/
│   ├── build.yml
│   ├── test.yml
│   ├── security.yml
│   ├── deploy.yml
│   └── rollback.yml
└── variables/
    ├── dev.yml
    ├── staging.yml
    └── prod.yml
```

**Deep Learning Points:**
- 📖 Template inheritance and extension
- 📖 Dynamic child pipelines
- 📖 Pipeline variables and precedence
- 📖 Environment-specific configurations
- 📖 Manual approval gates

**Step 2: Multi-Environment Strategy**
```yaml
# Implement dev → staging → prod promotion
# Learn: Environment protection, approval workflows
```

**Deep Learning Points:**
- 📖 GitLab environments and deployments
- 📖 Protected environments
- 📖 Deployment history and rollbacks
- 📖 Environment variables vs CI/CD variables

**Exercise 2.1**: Implement blue-green deployment strategy
```
Task: Configure Cloud Run traffic splitting
- Deploy new version with 0% traffic
- Run smoke tests
- Gradually shift traffic (25%, 50%, 100%)
- Implement automatic rollback on errors
```

---

### Phase 2.2: Comprehensive Security Scanning (3-4 hours)

#### **Learning Objectives**
- Implement SAST, DAST, dependency scanning
- Understand vulnerability management
- Learn security policy enforcement

#### **Tasks**

**Step 1: SAST - Static Application Security Testing**
```yaml
sast:
  stage: security
  image: returntocorp/semgrep
  script:
    - semgrep --config=auto --json --output=sast-report.json .
```

**Tools to Integrate:**
- Semgrep (SAST for code)
- SonarQube Community Edition
- PHPStan (PHP static analysis)

**Deep Learning Points:**
- 📖 Types of security vulnerabilities
- 📖 OWASP Top 10
- 📖 False positive management
- 📖 Security policy as code

**Step 2: Container Scanning with Trivy**
```yaml
container-scan:
  stage: security
  image: aquasec/trivy:latest
  script:
    - trivy image --severity HIGH,CRITICAL $IMAGE_NAME
```

**Deep Learning Points:**
- 📖 CVE database and scoring
- 📖 Base image selection
- 📖 Vulnerability remediation strategies
- 📖 Security exception management

**Step 3: Dependency Scanning**
```yaml
dependency-scan:
  stage: security
  script:
    - composer audit
    - npm audit (if using Node.js)
```

**Deep Learning Points:**
- 📖 Software Bill of Materials (SBOM)
- 📖 Dependency update strategies
- 📖 Lock file management

**Step 4: Secrets Scanning**
```yaml
secrets-scan:
  stage: security
  image: trufflesecurity/trufflehog:latest
  script:
    - trufflehog git file://. --json
```

**Alternative Tools:**
- GitLeaks
- detect-secrets

**Deep Learning Points:**
- 📖 Types of secrets (API keys, tokens, certificates)
- 📖 Secret rotation workflows
- 📖 Git history scanning

**Step 5: DAST - Dynamic Application Security Testing**
```yaml
dast:
  stage: security
  image: owasp/zap2docker-stable
  script:
    - zap-baseline.py -t $APP_URL -r dast-report.html
```

**Deep Learning Points:**
- 📖 SAST vs DAST differences
- 📖 Authenticated scanning
- 📖 API security testing
- 📖 Performance impact of DAST

**Exercise 2.2**: Security Dashboard
```
Task: Create a security vulnerability tracking system
- Parse all security scan outputs
- Generate unified security report
- Set up alerts for critical vulnerabilities
- Create remediation workflow
```

---

### Phase 2.3: IAM Strategy & Service Accounts (1-2 hours)

#### **Learning Objectives**
- Design least-privilege access model
- Implement service account best practices
- Set up access auditing

#### **Tasks**

**Step 1: Service Account Architecture**
```
Service Accounts:
├── cloud-run-web-sa (Cloud Run web application)
├── cloud-run-worker-sa (Queue workers)
├── ci-cd-deployer-sa (GitLab CI/CD deployments)
├── backup-sa (Database backups)
└── monitoring-sa (Logging and monitoring)
```

**Deep Learning Points:**
- 📖 Service account vs user account
- 📖 Workload Identity Federation
- 📖 Short-lived tokens
- 📖 Service account impersonation

**Step 2: Custom IAM Roles**
```hcl
# Create custom roles with minimal permissions
resource "google_project_iam_custom_role" "cloud_run_deployer" {
  role_id     = "cloudRunDeployer"
  title       = "Cloud Run Deployer"
  permissions = [
    "run.services.create",
    "run.services.update",
    "run.services.get"
  ]
}
```

**Deep Learning Points:**
- 📖 Predefined vs custom roles
- 📖 IAM policy hierarchy
- 📖 IAM conditions and constraints
- 📖 Access approval workflows

**Exercise 2.3**: IAM Audit
```
Task: Conduct IAM security review
- List all service accounts and their permissions
- Identify over-privileged accounts
- Implement least-privilege adjustments
- Document access justifications
```

---

### Phase 2.4: Secrets Management Strategy (1-2 hours)

#### **Learning Objectives**
- Implement secure secret lifecycle
- Understand secret rotation
- Learn audit and compliance

#### **Tasks**

**Step 1: Secret Organization**
```
Secrets Structure:
├── database/
│   ├── db-password (automatic rotation)
│   └── db-connection-string
├── application/
│   ├── app-key
│   └── jwt-secret
├── external-services/
│   ├── smtp-password
│   ├── stripe-api-key
│   └── aws-s3-credentials
└── certificates/
    └── ssl-certificate
```

**Deep Learning Points:**
- 📖 Secret versioning and pinning
- 📖 Automatic secret rotation
- 📖 Secret replication across regions
- 📖 Access audit logs

**Step 2: Application Integration**
```bash
# Cloud Run secret mounting
gcloud run services update invoice-ninja \
  --update-secrets=DB_PASSWORD=db-password:latest \
  --update-secrets=APP_KEY=app-key:latest
```

**Deep Learning Points:**
- 📖 Environment variables vs secret volumes
- 📖 Secret caching strategies
- 📖 Graceful secret rotation
- 📖 Emergency secret revocation

**Exercise 2.4**: Secret Rotation Testing
```
Task: Implement and test database password rotation
- Create rotation Lambda/Cloud Function
- Update application connections
- Test zero-downtime rotation
- Document rollback procedure
```

---

## 📅 Day 3: Production Operations (8-10 hours)

### Phase 3.1: Observability Stack (3-4 hours)

#### **Learning Objectives**
- Master Cloud Logging and Monitoring
- Understand metrics, logs, and traces
- Implement SLIs and SLOs

#### **Tasks**

**Step 1: Structured Logging**
```php
// Application logging configuration
// Learn: Log levels, structured logs, correlation IDs
```

**Deep Learning Points:**
- 📖 Logging best practices (what to log, what not to log)
- 📖 Structured logging (JSON format)
- 📖 Log correlation and tracing
- 📖 PII redaction
- 📖 Log retention policies

**Step 2: Custom Metrics**
```yaml
# Expose application metrics
metrics:
  - invoice_created_total
  - payment_processed_total
  - queue_job_duration_seconds
  - database_query_duration_seconds
```

**Deep Learning Points:**
- 📖 Golden signals (latency, traffic, errors, saturation)
- 📖 RED method (Rate, Errors, Duration)
- 📖 Custom vs system metrics
- 📖 Metric cardinality management

**Step 3: Cloud Monitoring Dashboards**
```
Dashboards:
├── Application Health
│   ├── Request rate
│   ├── Error rate
│   ├── Response time (p50, p95, p99)
│   └── Container instances
├── Database Performance
│   ├── Connection pool usage
│   ├── Query performance
│   ├── Slow query log
│   └── Replication lag
├── Queue Workers
│   ├── Job processing rate
│   ├── Failed jobs
│   ├── Queue depth
│   └── Worker scaling
└── Infrastructure
    ├── CPU and memory usage
    ├── Network I/O
    ├── Disk usage
    └── Cost metrics
```

**Deep Learning Points:**
- 📖 Dashboard design principles
- 📖 Visualization types (graphs, heatmaps, tables)
- 📖 Real-time vs historical data
- 📖 Dashboard sharing and access control

**Step 4: Alerting Strategy**
```yaml
# Alert Rules
alerts:
  critical:
    - High error rate (>5% for 5 minutes)
    - Database connection failures
    - All containers down
    - SSL certificate expiring (<7 days)
  warning:
    - Elevated response time (p95 >2s)
    - Queue depth growing
    - High CPU usage (>80%)
    - Failed backup jobs
  informational:
    - Deployment completed
    - Autoscaling event
    - Configuration change
```

**Deep Learning Points:**
- 📖 Alert fatigue prevention
- 📖 Alert routing and escalation
- 📖 On-call rotation setup
- 📖 Alert runbook association
- 📖 SLO-based alerting

**Step 5: Define SLIs and SLOs**
```
Service Level Indicators (SLIs):
- Availability: % of successful requests
- Latency: % of requests served < 500ms
- Durability: % of data successfully backed up

Service Level Objectives (SLOs):
- 99.9% availability (43 minutes downtime/month)
- 95% of requests < 500ms
- 99.99% backup success rate

Error Budget:
- 0.1% = 43 minutes/month of downtime allowed
```

**Deep Learning Points:**
- 📖 SLI vs SLO vs SLA differences
- 📖 Error budget calculation
- 📖 Error budget policy
- 📖 SLO burn rate
- 📖 Multi-window, multi-burn-rate alerts

**Exercise 3.1**: Implement complete observability
```
Task: Build comprehensive monitoring solution
- Deploy Grafana for visualization (optional)
- Create 4 main dashboards
- Implement 10+ alert rules
- Set up PagerDuty/Opsgenie integration
- Test alerting with synthetic failures
```

---

### Phase 3.2: Autoscaling & Performance Optimization (2-3 hours)

#### **Learning Objectives**
- Master Cloud Run autoscaling
- Understand concurrency tuning
- Learn cost optimization techniques

#### **Tasks**

**Step 1: Cloud Run Autoscaling Configuration**
```bash
gcloud run services update invoice-ninja \
  --min-instances=1 \
  --max-instances=100 \
  --concurrency=80 \
  --cpu=2 \
  --memory=1Gi \
  --cpu-throttling \
  --execution-environment=gen2
```

**Deep Learning Points:**
- 📖 Request-based vs CPU-based autoscaling
- 📖 Cold start optimization
- 📖 Concurrency vs parallelism
- 📖 Min instances for availability
- 📖 Max instances for cost control
- 📖 Startup probes and health checks

**Step 2: Database Connection Pooling**
```php
// Database connection pool configuration
// Learn: Connection lifecycle, pool sizing
```

**Deep Learning Points:**
- 📖 Connection pool sizing formula
- 📖 Cloud SQL connection limits
- 📖 Cloud SQL Proxy benefits
- 📖 Private IP vs public IP performance

**Step 3: Caching Strategy**
```
Caching Layers:
├── Application Level
│   ├── Redis/Memorystore (session, cache)
│   └── Query result caching
├── CDN Level
│   ├── Cloud CDN for static assets
│   └── Edge caching headers
└── Database Level
    └── Query plan caching
```

**Deep Learning Points:**
- 📖 Cache invalidation strategies
- 📖 Cache warming
- 📖 Cache-aside vs write-through patterns
- 📖 TTL selection

**Step 4: Performance Testing**
```bash
# Load testing with Apache Bench
ab -n 10000 -c 100 https://your-app.run.app/

# Load testing with k6
k6 run load-test.js

# Continuous load testing
artillery run artillery-config.yml
```

**Deep Learning Points:**
- 📖 Load testing vs stress testing
- 📖 Realistic traffic simulation
- 📖 Performance bottleneck identification
- 📖 Database query optimization

**Exercise 3.2**: Performance Optimization Challenge
```
Task: Optimize application for 10x traffic
- Baseline: Measure current performance
- Identify bottlenecks using profiling
- Implement optimizations (caching, indexing, pooling)
- Re-test and compare results
- Document performance gains
```

---

### Phase 3.3: Cost Optimization (1-2 hours)

#### **Learning Objectives**
- Understand GCP billing
- Implement cost controls
- Learn FinOps best practices

#### **Tasks**

**Step 1: Cost Analysis**
```bash
# Enable detailed billing export
# Analyze costs by service, region, label

# Create cost dashboard
```

**Cost Breakdown:**
- Cloud Run: Requests, CPU-time, memory-time
- Cloud SQL: Instance uptime, storage, backups
- Cloud Storage: Storage, operations, data transfer
- Networking: Egress charges
- Logging: Log ingestion and storage

**Deep Learning Points:**
- 📖 GCP pricing model
- 📖 Sustained use discounts
- 📖 Committed use contracts
- 📖 Spot/preemptible instances

**Step 2: Cost Optimization Strategies**
```
Optimizations:
├── Cloud Run
│   ├── CPU allocation (only during request)
│   ├── Request timeout tuning
│   ├── Min instances = 0 for dev
│   └── Memory right-sizing
├── Cloud SQL
│   ├── Stop dev/staging during off-hours
│   ├── Storage auto-increase disabled
│   ├── Appropriate machine type
│   └── Backup retention policy
├── Logging
│   ├── Log sampling for high-volume
│   ├── Exclusion filters
│   └── Retention adjustment (30 days)
└── Networking
    └── Regional resources (avoid egress)
```

**Deep Learning Points:**
- 📖 Cloud Run billing model
- 📖 Idle instance costs
- 📖 Data transfer charges
- 📖 Log storage optimization

**Exercise 3.3**: Cost Reduction Challenge
```
Task: Reduce monthly costs by 30%
- Audit current spending
- Identify optimization opportunities
- Implement cost-saving measures
- Set up budget alerts
- Create cost attribution by team/project
```

---

### Phase 3.4: Backup & Disaster Recovery (2-3 hours)

#### **Learning Objectives**
- Implement comprehensive backup strategy
- Understand RTO and RPO
- Learn disaster recovery procedures

#### **Tasks**

**Step 1: Backup Strategy Design**
```
Backup Types:
├── Automated Backups (Cloud SQL)
│   ├── Daily automated backups (7 days retention)
│   ├── Transaction logs (PITR - 7 days)
│   └── Backup location (multi-region)
├── On-Demand Backups
│   ├── Before major changes
│   └── Long-term retention (monthly)
└── Application Data Backups
    ├── File storage (Cloud Storage versioning)
    └── Configuration backups
```

**Deep Learning Points:**
- 📖 RPO (Recovery Point Objective)
- 📖 RTO (Recovery Time Objective)
- 📖 Backup vs replication
- 📖 Cross-region backups for DR
- 📖 Backup encryption

**Step 2: Point-in-Time Recovery (PITR)**
```bash
# Enable PITR
gcloud sql instances patch invoice-ninja-db \
  --enable-point-in-time-recovery \
  --retained-transaction-log-days=7

# Restore to specific point
gcloud sql backups create \
  --instance=invoice-ninja-db

gcloud sql restore-backup \
  --backup-id=BACKUP_ID \
  --backup-instance=invoice-ninja-db \
  --instance=invoice-ninja-db-restored
```

**Deep Learning Points:**
- 📖 Binary log replication
- 📖 Transaction log shipping
- 📖 PITR window and costs
- 📖 Recovery time estimation

**Step 3: Disaster Recovery Plan**
```
DR Scenarios:
├── Database Failure
│   ├── Restore from backup
│   ├── Failover to replica
│   └── RTO: 15 minutes
├── Region Outage
│   ├── Cross-region replica promotion
│   ├── DNS cutover
│   └── RTO: 30 minutes
├── Data Corruption
│   ├── PITR to before corruption
│   └── RTO: 1 hour
└── Complete Account Compromise
    ├── Restore to new project
    └── RTO: 4 hours
```

**Deep Learning Points:**
- 📖 Disaster recovery tiers (Tier 1-4)
- 📖 Multi-region architecture
- 📖 Failover automation
- 📖 DR testing schedule

**Step 4: DR Testing**
```bash
# Monthly DR drill checklist
# 1. Simulate database failure
# 2. Execute recovery procedure
# 3. Verify application functionality
# 4. Measure actual RTO
# 5. Update runbooks
```

**Exercise 3.4**: DR Simulation
```
Task: Execute full disaster recovery drill
- Simulate region outage
- Follow DR runbook
- Restore service in different region
- Measure RTO and RPO
- Document lessons learned
- Update DR procedures
```

---

### Phase 3.5: Incident Response & Runbooks (1-2 hours)

#### **Learning Objectives**
- Create effective runbooks
- Learn incident management
- Implement RCA process

#### **Tasks**

**Step 1: Incident Response Plan**
```
Incident Severity Levels:
├── SEV1 (Critical)
│   ├── Complete service outage
│   ├── Data loss or breach
│   └── Response time: Immediate
├── SEV2 (High)
│   ├── Major functionality impaired
│   ├── Performance degradation
│   └── Response time: 15 minutes
├── SEV3 (Medium)
│   ├── Minor feature broken
│   └── Response time: 4 hours
└── SEV4 (Low)
    └── Cosmetic issues
```

**Deep Learning Points:**
- 📖 Incident command structure
- 📖 Communication protocols
- 📖 Escalation procedures
- 📖 Post-incident review

**Step 2: Create Runbooks**
```
Runbooks:
├── High Error Rate
│   ├── Symptoms
│   ├── Investigation steps
│   ├── Resolution actions
│   └── Escalation path
├── Database Connection Issues
├── Slow Response Times
├── Queue Worker Failures
├── Certificate Expiration
└── Deployment Rollback
```

**Runbook Template:**
```markdown
# Runbook: [Issue Name]

## Symptoms
- What alerts fire
- User-visible impact

## Severity
SEV1/SEV2/SEV3/SEV4

## Investigation
1. Check [specific metrics/logs]
2. Verify [specific components]

## Resolution
### Immediate Actions
1. [Quick fix steps]

### Long-term Fix
1. [Root cause remediation]

## Escalation
- Primary: [Team/Person]
- Secondary: [Team/Person]

## Related Documentation
- [Links to relevant docs]
```

**Deep Learning Points:**
- 📖 Runbook vs playbook
- 📖 Automated remediation
- 📖 Incident documentation
- 📖 Knowledge base building

**Step 3: Root Cause Analysis (RCA)**
```
RCA Template:
├── Incident Summary
├── Timeline
├── Impact Assessment
├── Root Cause (5 Whys)
├── Contributing Factors
├── Resolution Steps Taken
├── Action Items (with owners)
└── Lessons Learned
```

**Deep Learning Points:**
- 📖 5 Whys technique
- 📖 Fishbone diagram
- 📖 Blameless postmortems
- 📖 Action item tracking

**Exercise 3.5**: Incident Simulation
```
Task: Conduct incident response drill
- Simulate SEV1 incident (database down)
- Follow incident response procedure
- Document timeline
- Hold postmortem
- Create RCA document
- Generate action items
```

---

## 📅 Day 4: Leadership & Audit Readiness (6-8 hours)

### Phase 4.1: Architecture Documentation (2-3 hours)

#### **Learning Objectives**
- Learn architecture documentation standards
- Understand Architecture Decision Records
- Create technical design docs

#### **Tasks**

**Step 1: System Architecture Diagram**
```
Create comprehensive diagrams:
├── High-Level Architecture
├── Network Architecture
├── Security Architecture
├── CI/CD Pipeline Flow
├── Data Flow Diagram
└── Disaster Recovery Architecture
```

**Tools:**
- draw.io / diagrams.net
- Lucidchart
- PlantUML (as-code)

**Deep Learning Points:**
- 📖 C4 model (Context, Container, Component, Code)
- 📖 UML diagrams
- 📖 Architecture as code
- 📖 Diagram versioning

**Step 2: Architecture Decision Records (ADRs)**
```markdown
# ADR-001: Use Cloud Run for Application Hosting

## Status
Accepted

## Context
Need serverless, scalable platform for Laravel application

## Decision
Use Cloud Run instead of GKE or Compute Engine

## Consequences
### Positive
- Auto-scaling
- Pay-per-use
- No infrastructure management

### Negative
- Container startup time
- Limited to HTTP/gRPC
- Cold start latency

## Alternatives Considered
- Google Kubernetes Engine (GKE)
- Compute Engine with instance groups
- App Engine
```

**Deep Learning Points:**
- 📖 ADR format and purpose
- 📖 Decision-making documentation
- 📖 Technical tradeoff analysis

**Create ADRs for:**
- [ ] Cloud platform selection (GCP)
- [ ] Container orchestration (Cloud Run vs GKE)
- [ ] Database choice (Cloud SQL PostgreSQL)
- [ ] CI/CD platform (GitLab)
- [ ] IaC tool (Terraform)
- [ ] Monitoring solution (Cloud Monitoring)
- [ ] Secret management (Secret Manager)
- [ ] Networking approach (Serverless VPC)

**Step 3: Technical Design Documents**
```
Documentation:
├── README.md (project overview)
├── ARCHITECTURE.md (detailed architecture)
├── DEPLOYMENT.md (deployment procedures)
├── SECURITY.md (security controls)
├── RUNBOOKS/ (operational procedures)
├── ADR/ (architecture decisions)
└── COMPLIANCE.md (audit documentation)
```

**Deep Learning Points:**
- 📖 Documentation-as-code
- 📖 Documentation versioning
- 📖 Technical writing best practices
- 📖 Audience-appropriate documentation

**Exercise 4.1**: Complete documentation set
```
Task: Create comprehensive documentation package
- Write all ADRs
- Create architecture diagrams
- Document deployment procedures
- Create operational runbooks
- Prepare executive summary
```

---

### Phase 4.2: CI/CD Standards & Templates (2 hours)

#### **Learning Objectives**
- Design organization-wide CI/CD standards
- Create reusable templates
- Implement governance

#### **Tasks**

**Step 1: CI/CD Standards Document**
```markdown
# CI/CD Standards & Best Practices

## Pipeline Structure
All projects MUST include:
- Build stage
- Test stage
- Security scanning stage
- Deploy stage

## Security Requirements
- Container scanning (Trivy)
- SAST analysis
- Dependency scanning
- Secrets scanning
- Sign-off for production

## Deployment Standards
- Blue-green deployments
- Automated rollback
- Health check verification
- Traffic gradual rollout

## Branch Strategy
- main: production
- staging: pre-production
- feature/*: feature branches

## Approval Requirements
- Staging: Auto-deploy
- Production: Manual approval + 2 reviewers
```

**Deep Learning Points:**
- 📖 GitOps principles
- 📖 Trunk-based development
- 📖 Feature flags
- 📖 Deployment strategies (blue-green, canary, rolling)

**Step 2: Create Template Library**
```
.gitlab/templates/
├── base-pipeline.yml
├── docker-build.yml
├── security-scan.yml
├── deploy-cloud-run.yml
├── deploy-cloud-sql-migration.yml
└── rollback.yml
```

**Deep Learning Points:**
- 📖 Template composition
- 📖 Variable inheritance
- 📖 Template versioning
- 📖 Organization-level templates

**Step 3: Pipeline Governance**
```yaml
# Enforce required checks
required_checks:
  - security_scan
  - unit_tests
  - integration_tests
  - code_review
  - security_approval (for prod)
```

**Exercise 4.2**: Template Distribution
```
Task: Create organization template repository
- Package all templates
- Create usage documentation
- Set up template versioning
- Create migration guide for existing projects
```

---

### Phase 4.3: Compliance & Audit Readiness (2-3 hours)

#### **Learning Objectives**
- Understand ISO 27001 and SOC 2 requirements
- Implement audit-ready documentation
- Learn compliance automation

#### **Tasks**

**Step 1: Compliance Controls Mapping**
```
ISO 27001 Controls Implemented:
├── A.9: Access Control
│   ├── IAM policies
│   ├── MFA enforcement
│   └── Access reviews
├── A.10: Cryptography
│   ├── Encryption at rest
│   ├── Encryption in transit
│   └── Key management
├── A.12: Operations Security
│   ├── Change management
│   ├── Backup procedures
│   └── Logging and monitoring
├── A.14: System Acquisition
│   ├── Security in development
│   └── Security testing
└── A.17: Business Continuity
    ├── Backup strategy
    └── DR procedures

SOC 2 Trust Principles:
├── Security
├── Availability (SLOs)
├── Processing Integrity
├── Confidentiality
└── Privacy
```

**Deep Learning Points:**
- 📖 Compliance frameworks overview
- 📖 Control implementation evidence
- 📖 Continuous compliance
- 📖 Audit preparation

**Step 2: Evidence Collection Automation**
```bash
# Automated compliance evidence gathering
scripts/
├── collect-iam-permissions.sh
├── collect-access-logs.sh
├── collect-backup-evidence.sh
├── collect-change-logs.sh
└── generate-compliance-report.sh
```

**Deep Learning Points:**
- 📖 Evidence requirements
- 📖 Audit trails
- 📖 Compliance automation
- 📖 Policy-as-code

**Step 3: Audit Documentation Package**
```
audit-package/
├── system-architecture.pdf
├── security-controls-matrix.xlsx
├── iam-policies-export.json
├── access-logs/ (last 90 days)
├── backup-verification-logs/
├── incident-reports/
├── change-management-logs/
├── security-scan-results/
├── penetration-test-reports/
├── business-continuity-plan.pdf
├── disaster-recovery-test-results.pdf
└── employee-access-reviews.xlsx
```

**Step 4: Security Control Implementation**
```
Security Controls:
├── Preventive
│   ├── IAM policies
│   ├── Network security (firewall rules)
│   ├── Security scanning in CI/CD
│   └── Input validation
├── Detective
│   ├── Logging and monitoring
│   ├── Alerting
│   ├── Anomaly detection
│   └── Audit logs
└── Corrective
    ├── Automated rollback
    ├── Incident response
    └── Patch management
```

**Deep Learning Points:**
- 📖 Defense in depth
- 📖 Security control types
- 📖 Compliance mapping
- 📖 Risk assessment

**Exercise 4.3**: Mock Audit
```
Task: Conduct self-audit
- Review all compliance controls
- Collect evidence for each control
- Identify gaps
- Create remediation plan
- Present to stakeholders
```

---

### Phase 4.4: Performance Tuning & Optimization (1-2 hours)

#### **Learning Objectives**
- Advanced database optimization
- Application performance profiling
- Cost-performance tradeoffs

#### **Tasks**

**Step 1: Database Performance Tuning**
```sql
-- Identify slow queries
SELECT * FROM pg_stat_statements 
ORDER BY mean_exec_time DESC 
LIMIT 10;

-- Add appropriate indexes
CREATE INDEX idx_invoices_user_id ON invoices(user_id);
CREATE INDEX idx_invoices_created_at ON invoices(created_at);

-- Analyze query plans
EXPLAIN ANALYZE SELECT ...;
```

**Deep Learning Points:**
- 📖 Query optimization techniques
- 📖 Index design strategies
- 📖 Execution plan analysis
- 📖 Database statistics
- 📖 Connection pooling tuning

**Step 2: Application Profiling**
```bash
# PHP profiling with XDebug
# Identify bottlenecks

# Laravel optimization
php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan optimize

# Queue optimization
php artisan queue:work --sleep=3 --tries=3 --max-jobs=1000
```

**Deep Learning Points:**
- 📖 Profiling tools
- 📖 N+1 query problems
- 📖 Caching strategies
- 📖 Lazy loading vs eager loading

**Step 3: Infrastructure Right-Sizing**
```
Performance Testing Results:
├── Current: 2 CPU, 2GB RAM
├── Load test: 1000 concurrent users
├── Result: CPU 45%, Memory 60%
├── Recommendation: Downsize to 1 CPU, 1GB RAM
└── Cost savings: 40%
```

**Exercise 4.4**: Complete performance audit
```
Task: End-to-end performance optimization
- Baseline performance metrics
- Profile application
- Optimize database queries
- Right-size infrastructure
- Re-test and document improvements
- Calculate cost savings
```

---

### Phase 4.5: Final Production Deployment & Portfolio (1-2 hours)

#### **Learning Objectives**
- Execute production deployment
- Create portfolio documentation
- Prepare interview talking points

#### **Tasks**

**Step 1: Pre-Production Checklist**
```markdown
## Production Readiness Checklist

### Security
- [ ] All security scans passing
- [ ] No critical/high vulnerabilities
- [ ] Secrets in Secret Manager
- [ ] IAM policies reviewed
- [ ] SSL/TLS configured
- [ ] DDoS protection enabled
- [ ] WAF rules configured

### Performance
- [ ] Load testing completed
- [ ] Autoscaling configured
- [ ] Database optimized
- [ ] CDN configured
- [ ] Caching enabled

### Reliability
- [ ] SLOs defined
- [ ] Alerts configured
- [ ] Health checks passing
- [ ] Backup strategy implemented
- [ ] DR tested
- [ ] Runbooks created

### Compliance
- [ ] Audit logs enabled
- [ ] Data encryption verified
- [ ] Access reviews completed
- [ ] Documentation up-to-date

### Operational
- [ ] Monitoring dashboards
- [ ] On-call rotation setup
- [ ] Incident response plan
- [ ] Change management process
```

**Step 2: Production Deployment**
```bash
# Final deployment
cd terraform/environments/prod
terraform plan -out=prod.tfplan
terraform apply prod.tfplan

# Deploy application
git tag -a v1.0.0 -m "Production release v1.0.0"
git push origin v1.0.0

# GitLab pipeline automatically deploys to production
# Monitor deployment
```

**Step 3: Post-Deployment Validation**
```bash
# Smoke tests
curl -k https://invoice-ninja.example.com/health
curl -k https://invoice-ninja.example.com/api/v1/ping

# Monitor metrics
# Watch logs for errors
# Verify database connections
# Check queue processing
```

**Step 4: Create Portfolio Documentation**
```markdown
# Invoice Ninja GCP Production Deployment

## Project Overview
Deployed production-grade Invoice Ninja (Laravel FinTech application) 
on Google Cloud Platform with enterprise CI/CD, security, and observability.

## Technical Achievements
- 🏗️ Infrastructure as Code (Terraform)
- 🔄 GitLab CI/CD with security scanning
- 🐳 Docker containerization
- ☁️ Cloud-native GCP architecture
- 🔒 Comprehensive security implementation
- 📊 Full observability stack
- 🚨 Incident response procedures
- 📈 99.9% SLO achieved

## Architecture
[Include architecture diagram]

## Technologies Used
- GCP: Cloud Run, Cloud SQL, Secret Manager, Cloud Monitoring
- Terraform for IaC
- GitLab CI/CD
- Docker
- Laravel/PHP
- PostgreSQL
- Security: Trivy, Semgrep, OWASP ZAP

## Key Metrics
- Deployment frequency: Multiple per day
- Lead time: < 30 minutes
- MTTR: < 15 minutes
- Change failure rate: < 5%
- Availability: 99.95%

## Skills Demonstrated
[Map to job requirements]
```

**Deep Learning Points:**
- 📖 Portfolio presentation
- 📖 Technical storytelling
- 📖 Impact quantification
- 📖 Metrics-driven results

**Exercise 4.5**: Interview Preparation
```
Task: Prepare for technical interview
- Create presentation slides
- Practice explaining architecture
- Prepare for deep-dive questions
- Document lessons learned
- Create demo video (optional)
```

---

## 📚 Daily Validation Checkpoints

### End of Day 1 Checklist
- [ ] GCP project created and configured
- [ ] Terraform infrastructure deployed (dev)
- [ ] Application containerized
- [ ] Basic CI/CD pipeline working
- [ ] Application accessible via Cloud Run
- [ ] Database migrations successful

### End of Day 2 Checklist
- [ ] Multi-environment pipelines (dev/staging/prod)
- [ ] All security scans integrated
- [ ] IAM strategy implemented
- [ ] Secrets in Secret Manager
- [ ] Service accounts configured
- [ ] No critical security vulnerabilities

### End of Day 3 Checklist
- [ ] Monitoring dashboards created
- [ ] Alerts configured and tested
- [ ] SLOs defined and tracked
- [ ] Autoscaling tuned
- [ ] Backup strategy implemented
- [ ] DR tested successfully
- [ ] Runbooks created

### End of Day 4 Checklist
- [ ] All documentation completed
- [ ] Compliance controls mapped
- [ ] Production deployment successful
- [ ] Performance optimized
- [ ] Portfolio ready
- [ ] Interview prep done

---

## 🎓 Deep Learning Resources

### Must-Read Documentation
1. **GCP**
   - Cloud Run documentation
   - Cloud SQL best practices
   - IAM overview
   - Security best practices

2. **GitLab CI/CD**
   - Pipeline syntax
   - Security scanning
   - Templates and includes

3. **Terraform**
   - Best practices
   - Module design
   - State management

4. **Security**
   - OWASP Top 10
   - CIS Benchmarks
   - NIST Framework

5. **SRE**
   - Google SRE Book
   - SLOs, SLIs, SLAs
   - Incident management

### Recommended Books
- Site Reliability Engineering (Google)
- The Phoenix Project
- Accelerate
- Infrastructure as Code (Kief Morris)

### Hands-On Practice
- GCP Free Tier projects
- GitLab CI/CD tutorials
- Terraform modules creation
- Security scanning tools

---

## 🎯 Interview Preparation Guide

### Technical Deep-Dive Questions You'll Be Ready For

**GCP Architecture:**
- "Explain your Cloud Run scaling strategy"
- "How do you handle database connections in serverless?"
- "Walk me through your disaster recovery plan"

**CI/CD:**
- "How do you implement security scanning in pipelines?"
- "Explain your deployment strategy"
- "How do you handle rollbacks?"

**Security:**
- "What security controls did you implement?"
- "How do you manage secrets?"
- "Explain your IAM strategy"

**Observability:**
- "How do you monitor application health?"
- "What are your SLOs and why?"
- "Describe your incident response process"

**Leadership:**
- "How do you mentor junior engineers?"
- "How do you drive cross-team alignment?"
- "Describe a challenging incident you resolved"

### Your Talking Points
For each question, you'll have:
- Real implementation example
- Challenges faced
- Solutions implemented
- Metrics/results
- Lessons learned

---

## 🚀 Success Metrics

By the end of this learning path, you will have:

✅ **Production-Grade Deployment**
- Multi-environment GCP infrastructure
- 99.9%+ availability
- Automated CI/CD
- Comprehensive security

✅ **Technical Depth**
- Deep GCP expertise
- Advanced Terraform skills
- GitLab CI/CD mastery
- Security best practices

✅ **Leadership Evidence**
- Documentation standards
- Runbooks and procedures
- Architecture decisions
- Team templates

✅ **Compliance Knowledge**
- ISO 27001 controls
- SOC 2 principles
- Audit readiness
- Evidence collection

✅ **Portfolio**
- GitHub repository
- Architecture documentation
- Demo application
- Interview prep materials

---

## 📞 Support & Resources

### Getting Help
- GCP Documentation: https://cloud.google.com/docs
- GitLab CI/CD Docs: https://docs.gitlab.com/ee/ci/
- Invoice Ninja Docs: https://invoiceninja.github.io/
- Terraform Registry: https://registry.terraform.io/

### Community
- GCP Slack communities
- GitLab Forum
- r/devops
- DevOps Discord servers

---

## 🎬 Ready to Start?

**Next Steps:**
1. Set up your local environment (tools installation)
2. Create GCP free tier account
3. Fork Invoice Ninja repository
4. Begin Day 1, Phase 1.1

**Remember:**
- Take notes as you learn
- Document challenges and solutions
- Ask questions when stuck
- Celebrate small wins
- Build in public (blog/Twitter)

**Let's begin your journey to senior DevOps engineering! 🚀**

---

*Last Updated: January 15, 2026*
*Estimated Completion Time: 3-4 days intensive*
*Difficulty Level: Intermediate to Advanced*
