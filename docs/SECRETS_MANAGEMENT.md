# =============================================================================
# Secrets Management Configuration
# Documentation for secret organization and management
# =============================================================================

# Secret Structure
```
secrets/
├── database/
│   ├── db-password (automatic rotation every 90 days)
│   ├── db-root-password
│   └── db-connection-string
├── application/
│   ├── app-key (Laravel encryption key)
│   ├── jwt-secret
│   └── session-secret
├── external-services/
│   ├── smtp-password
│   ├── smtp-username
│   ├── stripe-api-key
│   ├── stripe-webhook-secret
│   ├── paypal-client-id
│   └── paypal-client-secret
├── redis/
│   └── redis-password (automatic rotation every 90 days)
└── certificates/
    ├── ssl-certificate
    └── ssl-private-key
```

## Secret Naming Convention
- Format: `{environment}-{category}-{name}`
- Example: `prod-db-password`, `staging-app-key`

## Secret Versioning Strategy
- **latest**: Always points to the current active version
- **previous**: Keep at least 2 versions for rollback
- **Retention**: Maintain versions for 30 days minimum

## Automatic Rotation Schedule
| Secret | Rotation Period | Method |
|--------|----------------|--------|
| db-password | 90 days | Cloud Function + SQL Admin API |
| redis-password | 90 days | Cloud Function + Memorystore API |
| app-key | Manual | Deploy new version |
| API keys | Manual/As needed | Provider-specific |

## Access Control Matrix

| Service Account | Secrets Access |
|----------------|---------------|
| cloud-run-web | app-key, db-password, smtp-*, stripe-*, paypal-* |
| cloud-run-worker | app-key, db-password, redis-password, smtp-* |
| ci-cd-deployer | None (reads from CI/CD variables) |
| backup | db-root-password |
| monitoring | None |

## Emergency Secret Revocation Procedure

1. **Immediate Actions**:
   ```bash
   # Disable the compromised secret version
   gcloud secrets versions disable VERSION --secret=SECRET_NAME
   
   # Create new secret version
   echo "new_secret_value" | gcloud secrets versions add SECRET_NAME --data-file=-
   ```

2. **Update Applications**:
   ```bash
   # Cloud Run will automatically pick up new secret version
   # Or force update:
   gcloud run services update SERVICE_NAME \
     --update-secrets=SECRET_KEY=SECRET_NAME:latest
   ```

3. **Verify and Monitor**:
   ```bash
   # Check audit logs for secret access
   gcloud logging read "protoPayload.serviceName=secretmanager.googleapis.com" \
     --limit=100 --format=json
   ```

## Secret Creation Scripts

### Create Database Password
```bash
#!/bin/bash
PROJECT_ID="invoice-ninja-prod"
ENVIRONMENT="prod"

# Generate secure password
DB_PASSWORD=$(openssl rand -base64 32)

# Create secret
echo -n "$DB_PASSWORD" | gcloud secrets create "${ENVIRONMENT}-db-password" \
  --project="$PROJECT_ID" \
  --replication-policy="automatic" \
  --data-file=-

# Grant access to service accounts
gcloud secrets add-iam-policy-binding "${ENVIRONMENT}-db-password" \
  --project="$PROJECT_ID" \
  --member="serviceAccount:${ENVIRONMENT}-web-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### Create Application Key
```bash
#!/bin/bash
PROJECT_ID="invoice-ninja-prod"
ENVIRONMENT="prod"

# Generate Laravel app key
APP_KEY=$(php artisan key:generate --show)

# Create secret
echo -n "$APP_KEY" | gcloud secrets create "${ENVIRONMENT}-app-key" \
  --project="$PROJECT_ID" \
  --replication-policy="automatic" \
  --data-file=-
```

## Integration with Cloud Run

### Environment Variables Approach
```yaml
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: prod-db-password
        key: latest
```

### Volume Mount Approach (for files)
```yaml
volumes:
  - name: secrets
    secret:
      secretName: ssl-certificates
      items:
        - key: certificate
          path: server.crt
        - key: private-key
          path: server.key
```

## Monitoring & Alerting

### Secret Access Monitoring
```bash
# Create log-based metric for secret access
gcloud logging metrics create secret-access-count \
  --description="Count of secret accesses" \
  --log-filter='protoPayload.serviceName="secretmanager.googleapis.com"
    AND protoPayload.methodName="google.cloud.secretmanager.v1.SecretManagerService.AccessSecretVersion"'
```

### Alert on Unauthorized Access
```bash
# Create alert policy
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="Unauthorized Secret Access" \
  --condition-display-name="Secret access from unknown SA" \
  --condition-filter='resource.type="secretmanager.googleapis.com/Secret"
    AND protoPayload.status.code!=0'
```

## Compliance & Audit

### Regular Audit Checklist
- [ ] Review service account access to secrets
- [ ] Verify secret rotation schedule compliance
- [ ] Check for unused secrets (candidates for deletion)
- [ ] Audit secret version history
- [ ] Review secret access logs for anomalies

### Audit Script
```bash
#!/bin/bash
# List all secrets and their IAM bindings
for SECRET in $(gcloud secrets list --format="value(name)"); do
    echo "Secret: $SECRET"
    gcloud secrets get-iam-policy "$SECRET" --format=json | jq '.bindings'
    echo "---"
done
```
