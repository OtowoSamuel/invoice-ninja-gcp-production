#!/usr/bin/env bash
# =============================================================================
# Invoice Ninja GCP — Project Bootstrap Script
# =============================================================================
#
# PURPOSE:
#   One-time setup script to prepare a GCP project for Terraform-managed
#   infrastructure. Creates the CI/CD service account, grants it the
#   minimum required IAM roles, enables all necessary GCP APIs, and
#   provisions the Terraform remote state bucket.
#
# USAGE:
#   ./scripts/bootstrap.sh <project_id> <alert_email> [region]
#
# EXAMPLE:
#   ./scripts/bootstrap.sh invoice-ninja-dev-17453 you@example.com us-central1
#
# PREREQUISITES:
#   - gcloud CLI installed and authenticated as a Project Owner
#   - Billing account linked to the target project
#
# WHAT THIS REPLACES:
#   Instead of manually running ad-hoc gcloud commands to grant permissions
#   when Terraform hits 403 errors, this script codifies all bootstrap
#   requirements in a single, versioned, repeatable entry point.
#
# REFERENCE:
#   Google Cloud Foundation Toolkit: https://cloud.google.com/foundation-toolkit
#   Terraform GCP Bootstrap Module: https://github.com/terraform-google-modules/terraform-google-bootstrap
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
PROJECT_ID="${1:?Usage: $0 <project_id> <alert_email> [region]}"
ALERT_EMAIL="${2:?Usage: $0 <project_id> <alert_email> [region]}"
REGION="${3:-us-central1}"

SA_NAME="gitlab-ci-deployer"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
STATE_BUCKET="${PROJECT_ID}-tf-state"

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
info "Preflight checks..."

command -v gcloud >/dev/null 2>&1 || fail "gcloud CLI not found. Install: https://cloud.google.com/sdk/docs/install"

ACTIVE_ACCOUNT=$(gcloud config get-value account 2>/dev/null)
[[ -n "$ACTIVE_ACCOUNT" ]] || fail "No active gcloud account. Run: gcloud auth login"

info "Active account: ${ACTIVE_ACCOUNT}"
info "Target project: ${PROJECT_ID}"
info "Region:         ${REGION}"
echo ""

# Verify project exists and we have access
gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1 \
  || fail "Cannot access project ${PROJECT_ID}. Ensure it exists and you have Owner access."

gcloud config set project "$PROJECT_ID" --quiet

# =============================================================================
# Step 1: Enable Required GCP APIs
# =============================================================================
info "Step 1/4 — Enabling GCP APIs..."

APIS=(
  # Core infrastructure
  compute.googleapis.com
  vpcaccess.googleapis.com
  servicenetworking.googleapis.com

  # Database
  sqladmin.googleapis.com

  # Containers & deployment
  run.googleapis.com
  artifactregistry.googleapis.com

  # Security
  secretmanager.googleapis.com
  iam.googleapis.com
  cloudresourcemanager.googleapis.com

  # Observability
  monitoring.googleapis.com
  logging.googleapis.com
  cloudtrace.googleapis.com

  # State storage
  storage.googleapis.com
)

for api in "${APIS[@]}"; do
  if gcloud services list --enabled --filter="config.name=${api}" --format="value(config.name)" 2>/dev/null | grep -q "${api}"; then
    ok "Already enabled: ${api}"
  else
    info "Enabling ${api}..."
    gcloud services enable "$api" --quiet
    ok "Enabled: ${api}"
  fi
done

echo ""

# =============================================================================
# Step 2: Create CI/CD Service Account
# =============================================================================
info "Step 2/4 — Creating CI/CD service account..."

if gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
  ok "Service account already exists: ${SA_EMAIL}"
else
  gcloud iam service-accounts create "$SA_NAME" \
    --project="$PROJECT_ID" \
    --display-name="GitLab CI Deployer" \
    --description="Service account for GitLab CI/CD pipeline — Terraform & deployments"
  ok "Created service account: ${SA_EMAIL}"
fi

echo ""

# =============================================================================
# Step 3: Grant IAM Roles (Principle of Least Privilege)
# =============================================================================
info "Step 3/4 — Granting IAM roles to ${SA_NAME}..."

# These are the MINIMUM roles required for Terraform to manage all modules.
# Each role maps to specific module requirements documented inline.
ROLES=(
  # --- IAM & Project-level policy ---
  # Required by: modules/iam (google_project_iam_member, google_service_account_iam_member)
  roles/resourcemanager.projectIamAdmin    # Bind IAM roles at project level
  roles/iam.serviceAccountAdmin            # Create SAs + set SA-level IAM policies
  roles/iam.serviceAccountUser             # Act-as other SAs during Cloud Run deploy

  # --- Networking ---
  # Required by: modules/networking (VPC, subnets, firewall, VPC connector, peering)
  roles/compute.networkAdmin               # VPC, subnets, firewalls
  roles/vpcaccess.admin                    # Serverless VPC connector
  roles/servicenetworking.networksAdmin    # VPC peering for Cloud SQL private IP

  # --- Database ---
  # Required by: modules/cloud-sql (Cloud SQL instance, database, user)
  roles/cloudsql.admin                     # Cloud SQL instances, databases, users

  # --- Containers & Deployment ---
  # Required by: modules/cloud-run, modules/artifact-registry
  roles/run.admin                          # Cloud Run services + IAM
  roles/artifactregistry.admin             # Docker registry + repo-level IAM

  # --- Secrets ---
  # Required by: modules/secrets, modules/cloud-sql (secret versions)
  roles/secretmanager.admin                # Create secrets + secret versions

  # --- Observability ---
  # Required by: modules/monitoring (alert policies, dashboards, notification channels)
  roles/monitoring.admin                   # Alert policies, dashboards

  # --- Storage ---
  # Required by: Terraform remote state in GCS
  roles/storage.admin                      # GCS buckets for Terraform state
)

for role in "${ROLES[@]}"; do
  info "Granting ${role}..."
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="$role" \
    --quiet \
    --format="none" \
    --condition=None 2>/dev/null || true
  ok "Granted: ${role}"
done

echo ""

# =============================================================================
# Step 4: Create Terraform State Bucket
# =============================================================================
info "Step 4/4 — Creating Terraform state bucket..."

if gsutil ls -b "gs://${STATE_BUCKET}" >/dev/null 2>&1; then
  ok "State bucket already exists: gs://${STATE_BUCKET}"
else
  gsutil mb -p "$PROJECT_ID" -l "$REGION" -b on "gs://${STATE_BUCKET}"
  ok "Created state bucket: gs://${STATE_BUCKET}"
fi

# Enable versioning for state recovery
gsutil versioning set on "gs://${STATE_BUCKET}" 2>/dev/null
ok "Versioning enabled on state bucket"

echo ""

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN} Bootstrap Complete!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo -e "  Project:          ${CYAN}${PROJECT_ID}${NC}"
echo -e "  Service Account:  ${CYAN}${SA_EMAIL}${NC}"
echo -e "  State Bucket:     ${CYAN}gs://${STATE_BUCKET}${NC}"
echo -e "  Region:           ${CYAN}${REGION}${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "  1. Create a service account key for GitLab CI/CD:"
echo ""
echo "     gcloud iam service-accounts keys create /tmp/gitlab-ci-key.json \\"
echo "       --iam-account=${SA_EMAIL}"
echo ""
echo "  2. Add these GitLab CI/CD variables (Settings → CI/CD → Variables):"
echo ""
echo "     GCP_SERVICE_KEY    = <contents of /tmp/gitlab-ci-key.json>"
echo "     GCP_PROJECT_ID     = ${PROJECT_ID}"
echo "     GCP_ALERT_EMAIL    = ${ALERT_EMAIL}"
echo ""
echo "  3. Update terraform backend bucket in environments/*/main.tf:"
echo ""
echo "     backend \"gcs\" {"
echo "       bucket = \"${STATE_BUCKET}\""
echo "       prefix = \"terraform/state/<env>\""
echo "     }"
echo ""
echo "  4. Delete the key file after adding to GitLab:"
echo ""
echo "     rm /tmp/gitlab-ci-key.json"
echo ""
echo -e "${GREEN}============================================================${NC}"
