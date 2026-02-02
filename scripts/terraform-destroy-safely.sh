#!/bin/bash
# Safe Terraform Destroy Script for Invoice Ninja GCP
# Handles known race condition with Cloud SQL + VPC Service Networking
#
# Usage: bash scripts/terraform-destroy-safely.sh
# 
# What it does:
# 1. Attempts normal terraform destroy
# 2. If VPC connection deletion fails (expected), waits for Cloud SQL to finish
# 3. Removes VPC connection from state
# 4. Completes the destroy

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔥 Starting safe Terraform destroy...${NC}\n"

# Check if we're in the right directory
if [ ! -f "terraform.tfstate" ] && [ ! -f ".terraform/terraform.tfstate" ]; then
    echo -e "${RED}❌ Error: terraform.tfstate not found. Run from terraform environments directory.${NC}"
    exit 1
fi

# Step 1: Normal destroy attempt
echo -e "${YELLOW}Step 1: Running terraform destroy...${NC}"
if terraform destroy -auto-approve 2>&1 | tee /tmp/tf_destroy.log; then
    echo -e "${GREEN}✅ Destroy succeeded!${NC}"
    exit 0
fi

# Step 2: Check if we hit the known VPC connection error
if grep -q "Producer services.*still using this connection" /tmp/tf_destroy.log; then
    echo -e "${YELLOW}⚠️  VPC connection deletion blocked (expected GCP race condition)${NC}\n"
    
    # Step 3: Wait for Cloud SQL to finish deleting
    echo -e "${YELLOW}Step 2: Cloud SQL is still being deleted asynchronously...${NC}"
    echo -e "${YELLOW}Waiting 15 minutes for Cloud SQL deletion to complete...${NC}\n"
    
    for i in {1..90}; do
        echo -ne "\r${YELLOW}⏳ Waiting... $(($i * 10)) seconds elapsed${NC}"
        sleep 10
    done
    echo -e "\n"
    
    # Step 4: Verify Cloud SQL is actually deleted
    echo -e "${YELLOW}Step 3: Verifying Cloud SQL deletion...${NC}"
    if ! gcloud sql instances list --filter="name:invoice-ninja-dev-db" --format="table(name)" 2>/dev/null | grep -q "invoice-ninja-dev-db"; then
        echo -e "${GREEN}✅ Cloud SQL is deleted${NC}\n"
    else
        echo -e "${RED}⚠️  Cloud SQL still exists, continuing anyway...${NC}\n"
    fi
    
    # Step 5: Remove VPC connection from state
    echo -e "${YELLOW}Step 4: Removing VPC connection from Terraform state...${NC}"
    if terraform state rm module.networking.google_service_networking_connection.private_vpc_connection; then
        echo -e "${GREEN}✅ Removed from state${NC}\n"
    else
        echo -e "${RED}❌ Failed to remove from state${NC}"
        exit 1
    fi
    
    # Step 6: Complete the destroy
    echo -e "${YELLOW}Step 5: Completing terraform destroy...${NC}"
    if terraform destroy -auto-approve; then
        echo -e "${GREEN}✅ Destroy complete!${NC}"
        exit 0
    else
        echo -e "${RED}❌ Final destroy failed${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Destroy failed with unexpected error${NC}"
    cat /tmp/tf_destroy.log
    exit 1
fi
