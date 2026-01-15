# Invoice Ninja - Production Deployment on GCP

Enterprise-grade deployment of Invoice Ninja (Laravel invoicing & payments platform) on Google Cloud Platform with GitLab CI/CD, comprehensive security scanning, and production observability.

[![Platform](https://img.shields.io/badge/Platform-GCP-blue)](https://cloud.google.com)
[![IaC](https://img.shields.io/badge/IaC-Terraform-purple)](https://www.terraform.io/)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitLab-orange)](https://gitlab.com)

## 📋 Overview

This repository contains a complete production-ready deployment of Invoice Ninja on Google Cloud Platform, demonstrating senior DevOps engineering practices including:

- 🏗️ **Infrastructure as Code** - Multi-environment Terraform modules
- 🐳 **Containerization** - Optimized Docker builds for web app + queue workers
- 🔄 **CI/CD Pipeline** - GitLab pipelines with security scanning (SAST, DAST, secrets)
- 🔒 **Security** - Secret management, IAM least-privilege, vulnerability scanning
- 📊 **Observability** - Cloud Monitoring, logging, alerting, SLOs
- 🚨 **Incident Response** - Runbooks, disaster recovery, backup strategies
- ✅ **Compliance** - Audit-ready documentation (ISO 27001, SOC 2)

## 🏗️ Architecture

```
┌─────────────┐
│   Users     │
└──────┬──────┘
       │ HTTPS
       ▼
┌──────────────────────┐
│  Cloud Run (Web App) │
│  - Autoscaling       │
│  - Private VPC       │
└──────┬───────────────┘
       │
       ├──► Cloud SQL (PostgreSQL) - Private IP
       ├──► Redis (Memorystore) - Cache
       ├──► Secret Manager - Credentials
       ├──► Cloud Storage - File storage
       │
       ▼
┌────────────────────────┐
│ Cloud Run (Workers)    │
│ - Background jobs      │
│ - Queue processing     │
└────────────────────────┘
       │
       ├──► Payment Gateway (Stripe)
       ├──► Email Provider (SMTP)
       └──► Cloud Monitoring - Logs/Metrics
```

[Full architecture diagram →](docs/ARCHITECTURE.md)

## 📁 Repository Structure

```
invoice-ninja-gcp-production/
├── invoiceninja/          # Invoice Ninja application (git submodule)
│
├── terraform/             # Infrastructure as Code
│   ├── environments/      # Dev, Staging, Prod configs
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   └── modules/           # Reusable Terraform modules
│       ├── networking/    # VPC, subnets, VPC connector
│       ├── cloud-sql/     # PostgreSQL with backups
│       ├── cloud-run/     # Serverless containers
│       ├── secrets/       # Secret Manager
│       ├── iam/           # Service accounts & permissions
│       └── monitoring/    # Alerts & dashboards
│
├── docker/                # Container configurations
│   ├── web/              # Web application Dockerfile
│   └── worker/           # Queue worker Dockerfile
│
├── .gitlab/              # GitLab CI/CD
│   └── ci-templates/     # Reusable pipeline templates
│
├── scripts/              # Automation scripts
│   ├── backup/          # Backup automation
│   ├── deploy/          # Deployment helpers
│   └── monitoring/      # Monitoring utilities
│
└── docs/                # Documentation
    ├── ARCHITECTURE.md   # System architecture
    ├── LEARNING_PATH.md  # Learning guide
    ├── RUNBOOKS/        # Operational procedures
    └── ADR/             # Architecture Decision Records
```

## 🚀 Quick Start

### Prerequisites

- GCP account with billing enabled
- GitLab account (for CI/CD)
- Local tools: `terraform`, `gcloud`, `docker`, `git`

### 1. Clone Repository

```bash
git clone <your-repo-url>
cd invoice-ninja-gcp-production

# Initialize Invoice Ninja submodule
git submodule update --init --recursive
```

### 2. Deploy Infrastructure

```bash
cd terraform/environments/dev

# Configure your project
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Add your GCP project ID

# Deploy
terraform init
terraform plan
terraform apply
```

### 3. Build & Deploy Application

```bash
# Build Docker images
docker build -t gcr.io/YOUR-PROJECT/invoice-ninja-web:dev -f docker/web/Dockerfile .
docker build -t gcr.io/YOUR-PROJECT/invoice-ninja-worker:dev -f docker/worker/Dockerfile .

# Push to GCP
docker push gcr.io/YOUR-PROJECT/invoice-ninja-web:dev
docker push gcr.io/YOUR-PROJECT/invoice-ninja-worker:dev

# Deploy via Terraform or GitLab CI/CD
```

Full deployment guide → [terraform/README.md](terraform/README.md)

## 📚 Documentation

- **[Learning Path](docs/LEARNING_PATH.md)** - 3-4 day intensive learning guide
- **[Architecture](docs/ARCHITECTURE.md)** - System design & diagrams
- **[Terraform Guide](terraform/README.md)** - Infrastructure deployment
- **[Runbooks](docs/RUNBOOKS/)** - Incident response procedures
- **[ADRs](docs/ADR/)** - Architecture decisions

## 🔒 Security Features

- ✅ SAST (Semgrep, PHPStan)
- ✅ Container scanning (Trivy)
- ✅ Dependency scanning (Composer audit)
- ✅ Secrets scanning (TruffleHog, GitLeaks)
- ✅ DAST (OWASP ZAP)
- ✅ IAM least-privilege policies
- ✅ Private networking (VPC)
- ✅ Encrypted secrets (Secret Manager)
- ✅ Audit logging

## 📊 Observability

- **Metrics**: Request rate, latency (p50/p95/p99), error rate
- **Logging**: Structured logs with correlation IDs
- **Alerting**: Error rate, latency, uptime, resource exhaustion
- **Dashboards**: Application health, database performance, queue workers
- **SLOs**: 99.9% availability, <500ms p95 latency

## 🎯 Project Goals

This project demonstrates:

1. **Senior DevOps Engineering** - End-to-end cloud-native deployment
2. **Platform Engineering** - Reusable modules, templates, standards
3. **Site Reliability Engineering** - SLOs, incident response, DR
4. **Security Engineering** - Comprehensive security controls
5. **FinTech Operations** - Payment processing, compliance, audit readiness

## 🛠️ Technology Stack

- **Cloud**: Google Cloud Platform
- **IaC**: Terraform 1.5+
- **Containers**: Docker, Cloud Run
- **Database**: Cloud SQL (PostgreSQL 15)
- **Cache**: Redis / Memorystore
- **CI/CD**: GitLab CI/CD
- **Monitoring**: Cloud Monitoring, Cloud Logging
- **Application**: Laravel 10, PHP 8.2
- **Security**: Trivy, Semgrep, OWASP ZAP, TruffleHog

## 📈 CI/CD Pipeline

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│  Build   │──▶│   Test   │──▶│ Security │──▶│  Deploy  │──▶│  Monitor │
│  Images  │   │   Unit   │   │   Scan   │   │  Dev/Prod│   │  Health  │
└──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘
```

Features:
- Multi-stage builds for optimization
- Parallel security scanning
- Environment promotion (dev → staging → prod)
- Blue-green deployments
- Automatic rollback on failures

## 🤝 Contributing

This is a learning/portfolio project. Feel free to fork and adapt for your own use.

## 📄 License

- **This Deployment Code**: MIT License
- **Invoice Ninja Application**: [Elastic License 2.0](https://github.com/invoiceninja/invoiceninja/blob/master/LICENSE)

## 🎓 Learning Resources

- [Google Cloud Architecture Center](https://cloud.google.com/architecture)
- [Terraform GCP Provider Docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [Invoice Ninja Documentation](https://invoiceninja.github.io/)

## 📞 Support

For issues with:
- **This deployment**: Open an issue in this repo
- **Invoice Ninja app**: See [Invoice Ninja GitHub](https://github.com/invoiceninja/invoiceninja)
- **GCP services**: See [GCP Support](https://cloud.google.com/support)

---

**Built with ❤️ as a portfolio project demonstrating production DevOps practices**
