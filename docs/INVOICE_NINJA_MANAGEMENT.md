# Managing the Invoice Ninja Application

## About the `invoiceninja/` Directory

The `invoiceninja/` directory contains the actual Invoice Ninja Laravel application. You have two options for managing it:

### Option 1: Git Submodule (Recommended)
Keep it as a separate Git repository that you can update independently.

```bash
# Remove current directory
rm -rf invoiceninja/

# Add as submodule
git submodule add https://github.com/invoiceninja/invoiceninja.git invoiceninja
git submodule update --init --recursive

# Later, to update Invoice Ninja
cd invoiceninja
git pull origin master
cd ..
git add invoiceninja
git commit -m "Update Invoice Ninja to latest version"
```

### Option 2: Direct Copy (Simpler)
Keep the current directory but remove its `.git` folder to make it part of your repo.

```bash
# Remove Invoice Ninja's git history
rm -rf invoiceninja/.git

# Now it's just regular files in your repo
git add invoiceninja/
git commit -m "Add Invoice Ninja application"
```

## What to Remove from Invoice Ninja

### Remove GitHub Actions (Not needed - you're using GitLab)
```bash
rm -rf invoiceninja/.github/
```

### Remove Their CI/CD Configs
```bash
# If they exist
rm -f invoiceninja/.gitlab-ci.yml
rm -f invoiceninja/.travis.yml
rm -f invoiceninja/azure-pipelines.yml
```

### Keep Everything Else
- `composer.json` - PHP dependencies (needed)
- `package.json` - Frontend dependencies (needed)
- `artisan` - Laravel CLI (needed)
- `app/`, `config/`, `database/`, `resources/` - Application code (needed)

## Customization Files You'll Add

Create these in the root (not in `invoiceninja/`):

```bash
# Your custom configuration
invoiceninja/.env.dev       # Dev environment config
invoiceninja/.env.staging   # Staging environment config
invoiceninja/.env.prod      # Production environment config
```

## Docker Strategy

Your Dockerfiles will:
1. Copy files FROM `invoiceninja/` directory
2. Install dependencies (composer, npm)
3. Build production-ready container
4. Run the application

Example in `docker/web/Dockerfile`:
```dockerfile
FROM php:8.2-fpm

# Copy application code
COPY invoiceninja/ /var/www/html/

# Install dependencies
RUN composer install --no-dev --optimize-autoloader
```

## Updating Invoice Ninja

### If Using Submodule:
```bash
cd invoiceninja
git checkout master
git pull
cd ..
git add invoiceninja
git commit -m "Update Invoice Ninja"
```

### If Using Direct Copy:
```bash
# Download latest release
cd /tmp
git clone https://github.com/invoiceninja/invoiceninja.git
cd invoiceninja
git checkout master

# Copy to your repo (careful - this overwrites)
rsync -av --exclude='.git' \
  /tmp/invoiceninja/ \
  /path/to/your/repo/invoiceninja/
```

## Summary

**Current State**: `invoiceninja/` is a full git clone
**Recommendation**: Convert to submodule (Option 1)
**What to Delete**: `.github/` folder and any CI config files
**What to Keep**: Everything else (the actual application)

---

Next step: Decide which option you want, and I can help you set it up!
