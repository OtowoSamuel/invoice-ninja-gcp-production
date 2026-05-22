# GitLab CI/CD Variables Setup Guide

## Problem: Masked Variables Cannot Contain Whitespace

GitLab's masked variable feature rejects JSON files because they contain whitespace (newlines, spaces). The solution is to **base64 encode** the service account keys.

---

## Step 1: Encode Your Service Account Keys

Run these commands to encode your keys:

### Staging Key
```bash
base64 -i /Users/admin/.gemini/antigravity/brain/3c5bd2f7-78d2-4e5e-a825-19ca1ef402bc/scratch/invoice-ninja-stg-17453-key.json | tr -d '\n'
```

### Production Key
```bash
base64 -i /Users/admin/.gemini/antigravity/brain/3c5bd2f7-78d2-4e5e-a825-19ca1ef402bc/scratch/invoice-ninja-prd-17453-key.json | tr -d '\n'
```

**Copy the entire output** from each command (it will be a very long single-line string).

---

## Step 2: Add Variables in GitLab

Go to: **GitLab → Your Project → Settings → CI/CD → Variables → Expand → Add Variable**

Add these **9 variables** (3 per environment):

### Development Environment

| Field | Value |
|-------|-------|
| **Key** | `GCP_PROJECT_ID` |
| **Value** | `invoice-ninja-dev-17453` |
| **Type** | Variable |
| **Environment scope** | `dev` |
| **Protect variable** | ✅ Checked |
| **Mask variable** | ⬜ Unchecked (not sensitive) |

| Field | Value |
|-------|-------|
| **Key** | `GCP_SERVICE_KEY` |
| **Value** | *(your existing dev key - if not base64, re-encode it)* |
| **Type** | Variable |
| **Environment scope** | `dev` |
| **Protect variable** | ✅ Checked |
| **Mask variable** | ✅ Checked |
| **Hide variable** | ✅ Checked (if available) |

| Field | Value |
|-------|-------|
| **Key** | `GCP_ALERT_EMAIL` |
| **Value** | `your-email@domain.com` |
| **Type** | Variable |
| **Environment scope** | `dev` |
| **Protect variable** | ✅ Checked |
| **Mask variable** | ⬜ Unchecked |

---

### Staging Environment

| Field | Value |
|-------|-------|
| **Key** | `GCP_PROJECT_ID` |
| **Value** | `invoice-ninja-stg-17453` |
| **Type** | Variable |
| **Environment scope** | `staging` |
| **Protect variable** | ✅ Checked |
| **Mask variable** | ⬜ Unchecked |

| Field | Value |
|-------|-------|
| **Key** | `GCP_SERVICE_KEY` |
| **Value** | *(paste base64-encoded staging key from Step 1)* |
| **Type** | Variable |
| **Environment scope** | `staging` |
| **Protect variable** | ✅ Checked |
| **Mask variable** | ✅ Checked |
| **Hide variable** | ✅ Checked (if available) |

| Field | Value |
|-------|-------|
| **Key** | `GCP_ALERT_EMAIL` |
| **Value** | `your-email@domain.com` |
| **Type** | Variable |
| **Environment scope** | `staging` |
| **Protect variable** | ✅ Checked |
| **Mask variable** | ⬜ Unchecked |

---

### Production Environment

| Field | Value |
|-------|-------|
| **Key** | `GCP_PROJECT_ID` |
| **Value** | `invoice-ninja-prd-17453` |
| **Type** | Variable |
| **Environment scope** | `production` |
| **Protect variable** | ✅ Checked |
| **Mask variable** | ⬜ Unchecked |

| Field | Value |
|-------|-------|
| **Key** | `GCP_SERVICE_KEY` |
| **Value** | *(paste base64-encoded production key from Step 1)* |
| **Type** | Variable |
| **Environment scope** | `production` |
| **Protect variable** | ✅ Checked |
| **Mask variable** | ✅ Checked |
| **Hide variable** | ✅ Checked (if available) |

| Field | Value |
|-------|-------|
| **Key** | `GCP_ALERT_EMAIL` |
| **Value** | `your-email@domain.com` |
| **Type** | Variable |
| **Environment scope** | `production` |
| **Protect variable** | ✅ Checked |
| **Mask variable** | ⬜ Unchecked |

---

## 🔒 Security Best Practices

### For `GCP_SERVICE_KEY`:
- ✅ **Always use "Masked"** - Hides value in pipeline logs
- ✅ **Always use "Hide variable"** (if available) - Cannot be revealed in UI after saving
- ✅ **Always use "Protect variable"** - Only available on protected branches (main, develop, releases)
- ❌ **Never use "Visible"** - Would expose the key in all job logs

### Why This Matters:
The `GCP_SERVICE_KEY` grants **Owner-level access** to your entire GCP project. If leaked:
- Anyone could delete all your Cloud Run services
- Access your database and customer data
- Rack up thousands in GCP charges
- Compromise your entire infrastructure

Treat it like a password to your bank account.

---

## How the Pipeline Decodes Keys

The `.gitlab-ci.yml` has been updated to automatically decode base64 keys:

### For Docker builds:
```bash
echo "$GCP_SERVICE_KEY" | base64 -d | docker login -u _json_key --password-stdin "https://${REGISTRY_URL}"
```

### For Cloud Run deployments:
```bash
echo "$GCP_SERVICE_KEY" | base64 -d > /tmp/gcp-service-key.json
gcloud auth activate-service-account --key-file=/tmp/gcp-service-key.json
```

### For Terraform:
```bash
echo "$GCP_SERVICE_KEY" | base64 -d > /tmp/gcp-credentials.json
export GOOGLE_CREDENTIALS="$(cat /tmp/gcp-credentials.json)"
```

---

## Verification

After adding all variables, your GitLab CI/CD Variables page should show:

```
GCP_PROJECT_ID       (dev)         invoice-ninja-dev-17453
GCP_SERVICE_KEY      (dev)         [masked]
GCP_ALERT_EMAIL      (dev)         your-email@domain.com

GCP_PROJECT_ID       (staging)     invoice-ninja-stg-17453
GCP_SERVICE_KEY      (staging)     [masked]
GCP_ALERT_EMAIL      (staging)     your-email@domain.com

GCP_PROJECT_ID       (production)  invoice-ninja-prd-17453
GCP_SERVICE_KEY      (production)  [masked]
GCP_ALERT_EMAIL      (production)  your-email@domain.com
```

All variables should have the 🔒 (protected) icon.

---

## Troubleshooting

### "Unable to create masked variable because: The value cannot contain the following characters: whitespace characters"
- You forgot to base64 encode the key
- Run the base64 command from Step 1 again

### "Invalid credentials" in pipeline
- The base64 string was truncated when copying
- Make sure you copied the **entire** output including the `tr -d '\n'` part
- The string should be very long (several thousand characters)

### Pipeline can't find the variable
- Check the **Environment scope** matches your job's environment
- Verify **Protect variable** is checked
- Ensure you're running on a protected branch (develop, main, releases)
