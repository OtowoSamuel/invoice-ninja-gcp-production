# IAM Module

## Overview
Manages service accounts, custom IAM roles, and access policies following the principle of least privilege.

## Learning Objectives
- Understand GCP IAM hierarchy (Organization > Folder > Project > Resource)
- Learn service account best practices
- Master custom role creation
- Implement Workload Identity Federation

## Service Accounts Created

### 1. Web Application Service Account (`cloud-run-web-sa`)
**Purpose**: Runs the Invoice Ninja web application on Cloud Run

**Permissions**:
- Cloud SQL Client (connect to database)
- Secret Manager access (read secrets)
- Cloud Storage object admin (file uploads)
- Logging writer (send logs)
- Monitoring metric writer (send metrics)

**Why these permissions**:
- Cloud SQL: Application needs database access
- Secrets: Retrieve DB password, API keys at runtime
- Storage: Handle invoice PDFs, attachments
- Logging: Structured application logs
- Monitoring: Custom business metrics

### 2. Worker Service Account (`cloud-run-worker-sa`)
**Purpose**: Runs background queue workers

**Permissions**:
- Cloud SQL Client
- Secret Manager access
- Pub/Sub publisher/subscriber (job queuing)
- Cloud Storage admin
- Logging writer

**Why these permissions**:
- Pub/Sub: Process queued jobs (emails, invoices)
- Storage: Generate and store reports
- Same DB/secrets access as web app

### 3. CI/CD Deployer Service Account (`ci-cd-sa`)
**Purpose**: GitLab CI/CD pipeline deployments

**Permissions**:
- Cloud Run deployer (custom role - minimal deploy permissions)
- Artifact Registry writer (push Docker images)
- Cloud SQL admin (run database migrations)
- Service account user (deploy with specific SA)
- Secret Manager admin (manage secrets)

**Why these permissions**:
- Automated deployments without full admin access
- Create/update secrets during deployment
- Run schema migrations safely

### 4. Backup Service Account (`backup-sa`)
**Purpose**: Automated database backups

**Permissions**:
- Cloud SQL client
- Storage admin (backup storage bucket)

### 5. Monitoring Service Account (`monitoring-sa`)
**Purpose**: Observability and alerting

**Permissions**:
- Monitoring viewer
- Logging viewer

## Custom IAM Roles

### 1. Cloud Run Deployer
**Problem Solved**: Built-in roles are too permissive for CI/CD

**Permissions Included**:
- Create/update/delete Cloud Run services
- View operations and revisions
- Impersonate service accounts (to deploy with specific SA)

**Permissions Excluded**:
- ❌ Delete projects
- ❌ Modify IAM policies
- ❌ Manage other GCP resources

### 2. Secret Accessor
**Problem Solved**: Need read-only access to secrets

**Permissions Included**:
- Get secret values
- List secret versions

**Permissions Excluded**:
- ❌ Create or delete secrets
- ❌ Modify secret IAM policies

### 3. Cloud SQL Client
**Problem Solved**: Connect to Cloud SQL without admin rights

**Permissions Included**:
- Connect to instances
- Get instance details

**Permissions Excluded**:
- ❌ Create or delete instances
- ❌ Modify instance configuration
- ❌ Manage backups

## Workload Identity Federation (Optional)

**What**: Keyless authentication for GitLab CI/CD

**Why**: Avoid storing service account keys in GitLab variables

**How it works**:
1. GitLab issues OIDC token for each pipeline run
2. GCP validates token against Workload Identity Pool
3. GitLab can impersonate service account without keys
4. Token expires after pipeline completes

**Benefits**:
- No long-lived credentials
- Automatic key rotation
- Better audit trail
- Reduced security risk

**Setup**:
```bash
# Enable in Terraform
enable_workload_identity = true
gitlab_project_id = "12345678"

# In GitLab CI/CD, use OIDC instead of service account key
```

## Security Best Practices Implemented

1. **Least Privilege**: Each SA has only required permissions
2. **Custom Roles**: Granular control vs built-in roles
3. **Separation of Duties**: Different SAs for different workloads
4. **No Owner/Editor Roles**: Avoid super-admin access
5. **Workload Identity**: Keyless authentication option
6. **Audit Logging**: All IAM changes logged automatically

## IAM Policy Hierarchy

```
Organization
  └── Project (invoice-ninja-prod)
      ├── Service Accounts
      │   ├── web-sa → roles/cloudsql.client (custom)
      │   ├── worker-sa → roles/pubsub.subscriber
      │   └── cicd-sa → roles/cloudRunDeployer (custom)
      └── Resources
          ├── Cloud Run → uses web-sa
          ├── Cloud SQL → accessed by web-sa, worker-sa
          └── Secret Manager → accessed by web-sa, worker-sa
```

## Usage

```hcl
module "iam" {
  source = "../../modules/iam"

  project_id   = var.project_id
  project_name = var.project_name
  environment  = var.environment

  # Optional: Enable Workload Identity
  enable_workload_identity = true
  gitlab_project_id        = "12345678"
}

# Use outputs in other modules
resource "google_cloud_run_service" "web" {
  # ...
  template {
    spec {
      service_account_name = module.iam.web_service_account_email
    }
  }
}
```

## Verification

```bash
# List service accounts
gcloud iam service-accounts list

# Check service account permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:ACCOUNT_EMAIL"

# Test Workload Identity (if enabled)
gcloud iam workload-identity-pools list \
  --location=global
```

## Access Review Checklist

Run quarterly access reviews:

- [ ] Review all service account permissions
- [ ] Verify least privilege principle
- [ ] Check for unused service accounts
- [ ] Audit service account key usage (should be zero with WIF)
- [ ] Review custom role permissions
- [ ] Verify IAM conditions are still appropriate
- [ ] Check for over-privileged accounts
- [ ] Document any exceptions

## Troubleshooting

### Permission Denied Errors

```bash
# Check what permissions a service account has
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:SA_EMAIL" \
  --format="table(bindings.role)"

# Check custom role permissions
gcloud iam roles describe cloudRunDeployer --project=PROJECT_ID
```

### Service Account Impersonation Issues

```bash
# Verify service account user role
gcloud iam service-accounts get-iam-policy SA_EMAIL

# Test impersonation
gcloud run services list \
  --impersonate-service-account=SA_EMAIL
```

## Cost Considerations

IAM itself is free, but consider:
- Audit logs storage costs (usually minimal)
- Workload Identity Federation has no additional cost
- Service accounts are free (no limit)

## Compliance Mapping

| Control | Implementation |
|---------|----------------|
| ISO 27001 A.9.2 | Custom roles, least privilege |
| SOC 2 CC6.3 | Service account separation |
| SOC 2 CC6.1 | Workload Identity (keyless) |
| PCI DSS 7.1 | Access control policies |
| GDPR Art. 32 | Encryption, access controls |

## Further Reading

- [GCP IAM Best Practices](https://cloud.google.com/iam/docs/best-practices)
- [Service Account Best Practices](https://cloud.google.com/iam/docs/best-practices-service-accounts)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [Custom Roles](https://cloud.google.com/iam/docs/creating-custom-roles)
