#!/bin/bash

########################################
# Docker Build & Test Script
# LEARNING: How to test Docker images locally
########################################

set -e  # Exit on error

echo "=========================================="
echo "Docker Multi-Stage Build Testing"
echo "=========================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

########################################
# STEP 1: Build Web Image
########################################
echo -e "\n${YELLOW}STEP 1: Building web image...${NC}"
echo "LEARNING: Multi-stage build compiles in stages, only final stage is kept"

time docker build \
  -f docker/web/Dockerfile \
  -t invoiceninja-web:local \
  --target production \
  .

echo -e "${GREEN}✓ Web image built${NC}"

# Check image size (should be ~200-300MB with Alpine)
echo -e "\n${YELLOW}Image size:${NC}"
docker images | grep invoiceninja-web

########################################
# STEP 2: Build Worker Image
########################################
echo -e "\n${YELLOW}STEP 2: Building worker image...${NC}"

time docker build \
  -f docker/worker/Dockerfile \
  -t invoiceninja-worker:local \
  --target production \
  .

echo -e "${GREEN}✓ Worker image built${NC}"

# Check image size
echo -e "\n${YELLOW}Image size:${NC}"
docker images | grep invoiceninja-worker

########################################
# STEP 3: Security Scan (Optional)
########################################
echo -e "\n${YELLOW}STEP 3: Security scanning...${NC}"
echo "LEARNING: Always scan images for vulnerabilities before production"

# Check if Trivy is installed
if command -v trivy &> /dev/null; then
    echo "Scanning web image..."
    trivy image --severity HIGH,CRITICAL invoiceninja-web:local || true
else
    echo "Trivy not installed. Install with:"
    echo "  brew install trivy  (macOS)"
    echo "  apt install trivy   (Debian/Ubuntu)"
fi

########################################
# STEP 4: Test with Docker Compose
########################################
echo -e "\n${YELLOW}STEP 4: Starting services with docker-compose...${NC}"
echo "LEARNING: docker-compose manages multi-container apps"

# Start in detached mode
docker-compose up -d

echo -e "\n${GREEN}✓ Services started${NC}"
echo ""
echo "=========================================="
echo "Access Points:"
echo "=========================================="
echo "Web App:      http://localhost:8000"
echo "MailHog UI:   http://localhost:8025"
echo "PostgreSQL:   localhost:5432"
echo "Redis:        localhost:6379"
echo ""
echo "=========================================="
echo "Useful Commands:"
echo "=========================================="
echo "View logs:       docker-compose logs -f"
echo "Check status:    docker-compose ps"
echo "Run migrations:  docker-compose exec web php artisan migrate"
echo "Generate key:    docker-compose exec web php artisan key:generate"
echo "Enter shell:     docker-compose exec web sh"
echo "Stop all:        docker-compose down"
echo ""

########################################
# STEP 5: Health Checks
########################################
echo -e "${YELLOW}Waiting for services to be healthy...${NC}"
sleep 10

echo -e "\n${YELLOW}Service health status:${NC}"
docker-compose ps

echo ""
echo -e "${GREEN}=========================================="
echo "Build and deployment successful!"
echo "==========================================${NC}"

########################################
# LEARNING SUMMARY
########################################
echo ""
echo "=========================================="
echo "KEY DOCKER CONCEPTS YOU JUST LEARNED:"
echo "=========================================="
echo ""
echo "1. MULTI-STAGE BUILDS"
echo "   - Separate build stages keep final image small"
echo "   - composer-build → node-build → production"
echo "   - Only 'production' stage ends up in final image"
echo ""
echo "2. LAYER CACHING"
echo "   - Copy dependency files first (composer.json)"
echo "   - If unchanged, Docker reuses cached layers"
echo "   - Result: 10x faster builds on code changes"
echo ""
echo "3. SECURITY"
echo "   - Non-root user (invoiceninja:1000)"
echo "   - .dockerignore prevents secrets in image"
echo "   - Alpine Linux (minimal attack surface)"
echo "   - Security scanning with Trivy"
echo ""
echo "4. HEALTH CHECKS"
echo "   - Docker/K8s uses these to detect unhealthy containers"
echo "   - Web: HTTP endpoint check"
echo "   - Worker: Queue status check"
echo ""
echo "5. SIGNAL HANDLING"
echo "   - SIGTERM = graceful shutdown request"
echo "   - SIGKILL = force kill (data loss risk)"
echo "   - Workers finish current job before exit"
echo ""
echo "6. DOCKER COMPOSE"
echo "   - Manages multi-service apps"
echo "   - Networks isolate services"
echo "   - Volumes persist data"
echo "   - depends_on with healthcheck = proper startup order"
echo ""
echo "=========================================="
