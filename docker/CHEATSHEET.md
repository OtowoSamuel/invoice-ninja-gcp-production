# 🚀 Docker Quick Reference - Copy & Paste Ready

## Common Commands

### Build & Run
```bash
# Build image
docker build -t myapp:latest .

# Run container
docker run -d -p 8000:8080 myapp:latest

# Run with environment variables
docker run -d -e DB_HOST=localhost myapp:latest

# Run with volume mount
docker run -d -v $(pwd):/app myapp:latest

# Run interactive shell
docker run -it myapp:latest sh
```

### Compose
```bash
# Start all services
docker-compose up -d

# Rebuild and start
docker-compose up --build

# Stop all services
docker-compose down

# View logs
docker-compose logs -f [service]

# Execute command in container
docker-compose exec web php artisan migrate

# Scale service
docker-compose up -d --scale worker=3
```

### Inspect & Debug
```bash
# List containers
docker ps

# List images
docker images

# Container logs
docker logs -f <container-id>

# Execute command in running container
docker exec -it <container-id> sh

# Inspect container
docker inspect <container-id>

# View resource usage
docker stats

# View image layers
docker history myapp:latest

# Explore image layers (requires dive)
dive myapp:latest
```

### Cleanup
```bash
# Remove stopped containers
docker container prune

# Remove unused images
docker image prune

# Remove unused volumes
docker volume prune

# Remove everything (DANGER!)
docker system prune -a

# Remove specific image
docker rmi myapp:latest

# Force remove running container
docker rm -f <container-id>
```

---

## Dockerfile Patterns

### Multi-Stage Build Template
```dockerfile
# Stage 1: Build
FROM node:18 AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: Production
FROM node:18-alpine AS production
WORKDIR /app
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
USER node
CMD ["node", "dist/main.js"]
```

### PHP Laravel Template
```dockerfile
# Composer stage
FROM composer:2 AS composer
WORKDIR /app
COPY composer.* ./
RUN composer install --no-dev
COPY . .

# Production
FROM php:8.2-fpm-alpine
RUN apk add --no-cache nginx supervisor
COPY --from=composer /app/vendor ./vendor
COPY . .
USER www-data
CMD ["/usr/bin/supervisord"]
```

### Python Flask Template
```dockerfile
# Build
FROM python:3.11 AS build
WORKDIR /app
COPY requirements.txt .
RUN pip install --user -r requirements.txt

# Production
FROM python:3.11-slim
WORKDIR /app
COPY --from=build /root/.local /root/.local
COPY . .
RUN adduser --disabled-password app
USER app
CMD ["python", "app.py"]
```

### Go Template
```dockerfile
# Build
FROM golang:1.21 AS build
WORKDIR /app
COPY go.* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /app/main

# Production
FROM alpine:3.18
RUN apk add --no-cache ca-certificates
COPY --from=build /app/main /main
RUN adduser -D app
USER app
CMD ["/main"]
```

---

## docker-compose.yml Template

```yaml
version: '3.8'

networks:
  app-network:
    driver: bridge

volumes:
  db-data:
  redis-data:

services:
  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
    volumes:
      - db-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user"]
      interval: 10s

  redis:
    image: redis:7-alpine
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s

  web:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8000:8080"
    environment:
      DB_HOST: db
      REDIS_HOST: redis
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - app-network
```

---

## .dockerignore Template

```gitignore
# Version control
.git
.gitignore

# Dependencies
node_modules
vendor
__pycache__
*.pyc

# Build artifacts
dist
build
*.o
*.so

# Environment
.env
.env.*
*.key
*.pem

# IDE
.vscode
.idea
*.swp

# OS
.DS_Store
Thumbs.db

# Documentation
README.md
docs/
*.md
```

---

## Health Check Examples

### HTTP Health Check
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1
```

### Database Connection Check
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s \
  CMD psql -U user -d db -c "SELECT 1" || exit 1
```

### Queue Worker Check
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s \
  CMD php artisan queue:health || exit 1
```

### Process Check
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s \
  CMD pgrep -f "python app.py" || exit 1
```

---

## Security Best Practices

### Create Non-Root User
```dockerfile
# Alpine Linux
RUN addgroup -g 1000 app && \
    adduser -D -u 1000 -G app app
USER app

# Debian/Ubuntu
RUN groupadd -g 1000 app && \
    useradd -r -u 1000 -g app app
USER app

# Use existing user
USER node  # Node.js
USER www-data  # PHP
```

### Scan for Vulnerabilities
```bash
# Install Trivy
brew install trivy  # macOS
apt install trivy   # Ubuntu

# Scan image
trivy image myapp:latest

# Fail on HIGH/CRITICAL
trivy image --exit-code 1 \
  --severity HIGH,CRITICAL \
  myapp:latest

# Generate report
trivy image -f json -o report.json myapp:latest
```

### Secrets Management
```bash
# Docker secrets (Swarm)
echo "secret_value" | docker secret create app_key -

# Kubernetes secrets
kubectl create secret generic app-key \
  --from-literal=key=secret_value

# Environment variables (dev only!)
docker run -e APP_KEY=dev_key myapp:latest
```

---

## Performance Optimization

### Reduce Image Size
```dockerfile
# Use Alpine Linux
FROM node:18-alpine  # ~40MB vs ~900MB

# Multi-stage build
FROM builder AS build
FROM alpine AS production

# Remove build dependencies
RUN apk add --virtual .build-deps gcc \
    && ... \
    && apk del .build-deps

# Combine RUN commands
RUN apt-get update && \
    apt-get install -y package && \
    rm -rf /var/lib/apt/lists/*
```

### Speed Up Builds
```dockerfile
# Cache dependencies separately
COPY package.json package-lock.json ./
RUN npm ci
COPY . .

# Use BuildKit
# export DOCKER_BUILDKIT=1

# Use cache mounts
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
```

---

## Troubleshooting

### Container Won't Start
```bash
# Check logs
docker logs <container-id>

# Run with interactive shell
docker run -it myapp:latest sh

# Override entrypoint
docker run -it --entrypoint sh myapp:latest
```

### Build Failures
```bash
# Clear build cache
docker builder prune

# Build with no cache
docker build --no-cache -t myapp:latest .

# Build specific stage
docker build --target build -t myapp:build .
```

### Network Issues
```bash
# List networks
docker network ls

# Inspect network
docker network inspect bridge

# Create custom network
docker network create myapp-network

# Connect container to network
docker network connect myapp-network container-id
```

### Volume Issues
```bash
# List volumes
docker volume ls

# Inspect volume
docker volume inspect db-data

# Remove volume
docker volume rm db-data

# Backup volume
docker run --rm -v db-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/backup.tar.gz /data
```

---

## CI/CD Integration

### GitLab CI
```yaml
docker-build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
```

### GitHub Actions
```yaml
- name: Build Docker image
  run: |
    docker build -t myapp:latest .
    docker tag myapp:latest ${{ secrets.REGISTRY }}/myapp:${{ github.sha }}
    docker push ${{ secrets.REGISTRY }}/myapp:${{ github.sha }}
```

### Cloud Run Deployment
```bash
# Build and push
docker build -t gcr.io/project/app:v1 .
docker push gcr.io/project/app:v1

# Deploy
gcloud run deploy app \
  --image gcr.io/project/app:v1 \
  --platform managed \
  --region us-central1
```

---

## Quick Debugging

```bash
# Why is my container slow?
docker stats <container-id>

# Why is my image so big?
docker history --no-trunc myapp:latest

# What files are in my image?
docker run --rm -it myapp:latest ls -lah

# What's using disk space?
docker system df

# What ports are exposed?
docker port <container-id>

# What environment variables?
docker exec <container-id> env

# Test without cache
docker build --no-cache -t test .
```

---

## Pro Tips

1. **Always use specific versions, not `latest`**
   ```dockerfile
   FROM node:18.16.0-alpine3.17  # Good
   FROM node:latest              # Bad
   ```

2. **Combine RUN commands to reduce layers**
   ```dockerfile
   RUN apt-get update && apt-get install -y \
       package1 \
       package2 \
       && rm -rf /var/lib/apt/lists/*
   ```

3. **Use .dockerignore aggressively**
   - Faster builds
   - Smaller context
   - Better security

4. **Label your images**
   ```dockerfile
   LABEL maintainer="you@example.com"
   LABEL version="1.0.0"
   LABEL description="My app"
   ```

5. **Use health checks everywhere**
   - Auto-restart unhealthy containers
   - Load balancer integration
   - Better monitoring

---

**Bookmark this file for quick reference! 🚀**
