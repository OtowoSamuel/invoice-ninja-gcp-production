# Development Workflow

Quick reference for working on this project.

## Daily Workflow

```bash
# 1. Pull latest changes
git pull origin main

# 2. Create feature branch
git checkout -b feature/my-feature

# 3. Make changes
# ... edit files ...

# 4. Test locally
docker-compose up
terraform fmt -recursive
terraform validate

# 5. Commit changes
git add .
git commit -m "feat: add new feature"

# 6. Push and create MR
git push origin feature/my-feature
```

## Directory Guide

| Directory | Purpose | When to Edit |
|-----------|---------|--------------|
| `terraform/` | Infrastructure code | Adding/changing GCP resources |
| `docker/` | Container configs | Changing build process |
| `.gitlab-ci.yml` | CI/CD pipeline | Changing deployment flow |
| `docs/` | Documentation | Learning, runbooks, ADRs |
| `scripts/` | Automation | Deploy, backup scripts |
| `invoiceninja/` | Application | Rarely (managed separately) |

## Testing Checklist

Before committing infrastructure changes:

- [ ] `terraform fmt -recursive`
- [ ] `terraform validate`
- [ ] `terraform plan` (review output)
- [ ] Test in dev environment first

## Deployment Process

1. **Dev**: Auto-deploy on commit to `develop` branch
2. **Staging**: Auto-deploy on commit to `main` branch
3. **Prod**: Manual approval required after staging

## Learning Path Progress

Track your progress in `docs/LEARNING_PATH.md`:
- Day 1: Foundation ✅
- Day 2: Security (In Progress)
- Day 3: Operations (Upcoming)
- Day 4: Documentation (Upcoming)

## Quick Commands

```bash
# Terraform
cd terraform/environments/dev
terraform init
terraform plan
terraform apply

# Docker
docker-compose up -d
docker-compose logs -f
docker-compose down

# GCP
gcloud config set project YOUR_PROJECT_ID
gcloud services list --enabled
gcloud run services list

# Git
git status
git log --oneline --graph
git branch -a
```

## Need Help?

- Terraform: Check `terraform/README.md`
- Architecture: Check `docs/ARCHITECTURE.md`
- Learning: Check `docs/LEARNING_PATH.md`
- Invoice Ninja: Check `docs/INVOICE_NINJA_MANAGEMENT.md`
