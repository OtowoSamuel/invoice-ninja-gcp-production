# =============================================================================
# IAM Audit & Access Review
# Script to review service account permissions and access patterns
# =============================================================================

#!/bin/bash

set -e

PROJECT_ID="${1:-invoice-ninja-prod}"
ENVIRONMENT="${2:-prod}"

echo "===================================="
echo "IAM Audit Report for ${PROJECT_ID}"
echo "Environment: ${ENVIRONMENT}"
echo "Date: $(date)"
echo "===================================="

# List all service accounts
echo -e "\n📋 Service Accounts:"
gcloud iam service-accounts list --project="${PROJECT_ID}" --format="table(email,displayName)"

# Check service account keys
echo -e "\n🔑 Service Account Keys:"
for SA in $(gcloud iam service-accounts list --project="${PROJECT_ID}" --format="value(email)"); do
    echo "Service Account: $SA"
    gcloud iam service-accounts keys list --iam-account="$SA" --project="${PROJECT_ID}" --format="table(name,validAfterTime,validBeforeTime)"
done

# List IAM policy bindings
echo -e "\n🔐 IAM Policy Bindings:"
gcloud projects get-iam-policy "${PROJECT_ID}" --flatten="bindings[].members" --format="table(bindings.role,bindings.members)"

# Check audit logs configuration
echo -e "\n📊 Audit Logs Configuration:"
gcloud projects get-iam-policy "${PROJECT_ID}" --format=json | jq '.auditConfigs'

# List recent IAM changes (last 7 days)
echo -e "\n📜 Recent IAM Changes (last 7 days):"
gcloud logging read "protoPayload.serviceName=iam.googleapis.com AND timestamp>=\\\"$(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)\\\"" \
    --project="${PROJECT_ID}" \
    --limit=50 \
    --format="table(timestamp,protoPayload.methodName,protoPayload.authenticationInfo.principalEmail)"

echo -e "\n✅ Audit complete!"
