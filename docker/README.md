# Docker Setup - Learning Guide

## 🎯 What You Just Learned

This Docker setup demonstrates **production-ready containerization** with all the best practices used by senior DevOps engineers.

---

## 📚 Core Concepts Explained

### 1️⃣ Multi-Stage Builds (The Secret to Small Images)

```dockerfile
FROM composer:2.6 AS composer-build  # Stage 1: Build
FROM node:18 AS node-build           # Stage 2: Frontend
FROM php:8.2-fpm-alpine AS production  # Stage 3: Final (only this goes to production)
```

**Why?**
- Build tools (npm, composer, gcc) are HUGE (~500MB)
- Production only needs compiled code (~150MB)
- Result: 70% smaller images, faster deployments

**How it works:**
1. Stage 1 compiles PHP dependencies
2. Stage 2 builds frontend assets
3. Stage 3 copies ONLY compiled artifacts
4. Docker discards stages 1 & 2

---

### 2️⃣ Layer Caching (The Speed Hack)

```dockerfile
# ❌ SLOW: Copy everything, then install
COPY . /app
RUN composer install  # Re-runs every code change

# ✅ FAST: Copy deps first, then code
COPY composer.json composer.lock ./
RUN composer install  # Cached if deps unchanged
COPY . /app  # Only this layer changes
```

**Why?**
- Docker caches each instruction layer
- If input files unchanged → reuse cached layer
- Result: 10x faster builds

**Mental Model:**
Think of layers like a stack of pancakes. If bottom pancake (dependencies) unchanged, reuse it. Only remake top pancakes (your code).

---

### 3️⃣ Security Hardening (Never Run as Root!)

```dockerfile
# Create non-root user
RUN adduser -D -u 1000 invoiceninja
USER invoiceninja  # Switch to non-root
```

**Why?**
- If attacker exploits your app, they're just `invoiceninja` user
- Can't install malware, modify system files, or access other containers
- **Senior-level requirement**: All production containers run as non-root

**Attack scenario prevented:**
```bash
# Attacker gets shell in container
$ whoami
invoiceninja  # Not root! Limited damage

$ apt install hacking-tool
Permission denied  # Can't install anything!
```

---

### 4️⃣ Signal Handling (Graceful Shutdown)

```dockerfile
# Worker needs pcntl extension
RUN docker-php-ext-install pcntl
```

```conf
# Supervisor config
stopwaitsecs=60  # Wait 60s for graceful shutdown
stopsignal=TERM  # Send SIGTERM (not SIGKILL)
```

**Why?**
- SIGTERM = "please stop gracefully"
- Worker finishes current job, then exits
- SIGKILL = "die now" (job lost, data corruption risk)

**Real-world scenario:**
```bash
# Without graceful shutdown:
$ docker stop worker
# Job processing payment → KILLED → customer charged but order not created

# With graceful shutdown:
$ docker stop worker
# Worker finishes payment job (30s) → exits cleanly → customer happy
```

---

### 5️⃣ Health Checks (Auto-Healing)

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s \
  CMD php artisan queue:health || exit 1
```

**Why?**
- Docker/Kubernetes monitors container health
- Unhealthy containers auto-restart
- Load balancers stop sending traffic to unhealthy containers

**How it works:**
```bash
# Every 30 seconds, Docker runs:
$ php artisan queue:health
# If command fails (exit code != 0), container marked unhealthy
# After 3 failures, Docker restarts container
```

---

### 6️⃣ .dockerignore (The Build Optimizer)

```dockerignore
.git/          # 200MB of git history
node_modules/  # 300MB (rebuilt in Docker anyway)
vendor/        # 100MB (rebuilt in Docker anyway)
tests/         # Not needed in production
```

**Impact:**
- Without: 600MB sent to Docker daemon
- With: 50MB sent to Docker daemon
- Result: 12x faster builds

---

## 🏗️ Architecture: Web vs Worker

### Web Container
- **Purpose**: Handle HTTP requests
- **Process**: Nginx + PHP-FPM
- **Port**: 8080 (non-privileged)
- **Scaling**: Horizontal (many instances)

### Worker Container
- **Purpose**: Process background jobs
- **Process**: Laravel queue worker
- **Port**: None (no HTTP)
- **Scaling**: Based on queue depth

**Why separate containers?**
- Scale independently (more workers for heavy jobs)
- Different resource limits (workers need more CPU)
- Different restart policies (workers can take longer to shutdown)

---

## 🐳 Docker Compose Magic

```yaml
depends_on:
  db:
    condition: service_healthy  # Wait for DB to be ready
```

**Why?**
- Without: Web starts, DB still booting → connection errors
- With: Docker waits for `pg_isready` to succeed → no errors

**Learning Point:**
`depends_on` without `condition` just ensures start ORDER, not READINESS. Always use `service_healthy` in production!

---

## 🔥 Quick Start

### 1. Build and Test Locally
```bash
# Build images
docker-compose build

# Start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f web
```

### 2. Initialize Application
```bash
# Generate app key
docker-compose exec web php artisan key:generate

# Run migrations
docker-compose exec web php artisan migrate

# Create admin user
docker-compose exec web php artisan ninja:create-account
```

### 3. Access Services
- **Web App**: http://localhost:8000
- **MailHog** (emails): http://localhost:8025
- **Database**: localhost:5432 (psql, TablePlus, etc.)

---

## 🧪 Testing Your Understanding

### Exercise 1: Build Image Analysis
```bash
# Build web image
docker build -f docker/web/Dockerfile -t test:web .

# Inspect layers
docker history test:web

# Question: How many layers? Which ones are largest?
```

### Exercise 2: Layer Caching Test
```bash
# First build (all layers)
time docker build -f docker/web/Dockerfile -t test:v1 .

# Change one line of code in invoiceninja/
echo "// comment" >> invoiceninja/routes/web.php

# Rebuild
time docker build -f docker/web/Dockerfile -t test:v2 .

# Question: How much faster was the second build?
```

### Exercise 3: Security Scan
```bash
# Install Trivy
brew install trivy  # or apt install trivy

# Scan for vulnerabilities
trivy image test:web

# Question: Are there any HIGH/CRITICAL vulnerabilities?
```

### Exercise 4: Graceful Shutdown Test
```bash
# Start worker
docker-compose up -d worker

# Send SIGTERM
docker-compose stop worker

# Watch logs (should finish current job)
docker-compose logs -f worker
```

---

## 🎓 Senior-Level Patterns You Learned

| Pattern | Why It Matters | Job Interview Impact |
|---------|---------------|---------------------|
| Multi-stage builds | 70% smaller images | ✅ Shows cost optimization |
| Non-root user | Security compliance | ✅ Required for enterprise |
| Layer caching | 10x faster CI/CD | ✅ Shows performance thinking |
| Graceful shutdown | Zero-downtime deploys | ✅ Production-readiness |
| Health checks | Auto-healing systems | ✅ Kubernetes knowledge |
| .dockerignore | Build optimization | ✅ Attention to detail |

---

## 🚀 Next Steps

1. **Push to Registry**
   ```bash
   # Tag for Google Artifact Registry
   docker tag invoiceninja-web:local \
     gcr.io/YOUR-PROJECT/invoiceninja-web:v1
   
   # Push
   docker push gcr.io/YOUR-PROJECT/invoiceninja-web:v1
   ```

2. **Run Security Scans in CI**
   - Trivy for vulnerabilities
   - Hadolint for Dockerfile linting
   - Dockle for best practices

3. **Implement in Production**
   - Cloud Run will use these exact images
   - Add resource limits (CPU/memory)
   - Configure auto-scaling

---

## 📖 Further Reading

- [Docker Multi-Stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [Best Practices for Writing Dockerfiles](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Container Security Checklist](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)

---

## 🤝 How to Do This On Your Own (Any Project)

### Step-by-Step Recipe

**1. Identify Build Requirements**
```bash
# What does your app need to build?
- Language runtime (PHP, Node, Python, Go)
- Build tools (composer, npm, cargo)
- System dependencies (libpng, libxml)
```

**2. Design Multi-Stage Dockerfile**
```dockerfile
# Stage 1: Dependencies
FROM <language>:<version> AS deps
COPY <lockfile> .
RUN <install-deps>

# Stage 2: Build
FROM deps AS build
COPY . .
RUN <compile>

# Stage 3: Production
FROM <language>:<version>-alpine AS prod
COPY --from=build <artifacts> .
USER <non-root>
CMD [<start-command>]
```

**3. Optimize**
- Add .dockerignore
- Order COPY by change frequency
- Use Alpine Linux
- Remove build dependencies

**4. Secure**
- Create non-root user
- Don't copy secrets
- Scan for vulnerabilities
- Use specific version tags (not `latest`)

**5. Test**
- Build locally
- Run with docker-compose
- Check image size
- Verify health checks

---

## 💡 Key Takeaway

**You don't memorize Dockerfiles—you understand the PATTERNS:**

1. **Multi-stage** = smaller images
2. **Layer order** = faster builds
3. **Non-root** = better security
4. **Health checks** = auto-healing
5. **Graceful shutdown** = zero downtime

Apply these patterns to ANY application!

