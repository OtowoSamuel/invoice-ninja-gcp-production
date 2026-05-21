import re

with open('.gitlab-ci.yml', 'r') as f:
    content = f.read()

worker_jobs = """

deploy:worker:dev:
  stage: deploy
  extends: .gcloud_deploy_template
  needs:
    - build:worker
    - tf:apply:dev
  timeout: 15m
  resource_group: deploy-worker-dev
  variables:
    CLOUD_RUN_SERVICE_NAME: "invoice-ninja-worker"
    CLOUD_RUN_SERVICE_ACCOUNT: "${CLOUD_RUN_WEB_SA}"
    APP_ENV: "development"
    APP_DEBUG: "true"
    CACHE_DRIVER: "file"
    QUEUE_CONNECTION: "database"
    MIN_INSTANCES: "0"
    MAX_INSTANCES: "1"
    MEMORY_LIMIT: "512Mi"
    CPU_LIMIT: "1"
    APP_KEY_SECRET: "invoice-ninja-dev-app-key"
    DB_PASSWORD_SECRET: "invoice-ninja-dev-db-password"
    SMTP_PASSWORD_SECRET: "invoice-ninja-dev-smtp-password"
    STRIPE_KEY_SECRET: "invoice-ninja-dev-stripe-key"
  script:
    - |
      gcloud run deploy "$CLOUD_RUN_SERVICE_NAME" \
        --image "$WORKER_IMAGE:$CI_COMMIT_SHA" \
        --region "$GCP_REGION" \
        --platform managed \
        --no-allow-unauthenticated \
        --service-account "$CLOUD_RUN_SERVICE_ACCOUNT" \
        --vpc-connector "$VPC_CONNECTOR" \
        --add-cloudsql-instances "$CLOUD_SQL_CONNECTION_NAME" \
        --set-env-vars "APP_ENV=${APP_ENV},APP_DEBUG=${APP_DEBUG},DB_CONNECTION=pgsql,DB_HOST=/cloudsql/${CLOUD_SQL_CONNECTION_NAME},DB_PORT=${DB_PORT},DB_DATABASE=${DB_DATABASE_NAME},DB_USERNAME=${DB_USERNAME},CACHE_DRIVER=${CACHE_DRIVER},QUEUE_CONNECTION=${QUEUE_CONNECTION}" \
        --set-secrets "APP_KEY=${APP_KEY_SECRET}:latest,DB_PASSWORD=${DB_PASSWORD_SECRET}:latest,SMTP_PASSWORD=${SMTP_PASSWORD_SECRET}:latest,STRIPE_KEY=${STRIPE_KEY_SECRET}:latest" \
        --memory "$MEMORY_LIMIT" \
        --cpu "$CPU_LIMIT" \
        --min-instances "$MIN_INSTANCES" \
        --max-instances "$MAX_INSTANCES" \
        --no-cpu-throttling \
        --concurrency "$CONCURRENCY" \
        --timeout 300 \
        --quiet
  environment:
    name: dev-worker
  rules:
    - if: '$CI_COMMIT_BRANCH == "develop"'

deploy:worker:staging:
  stage: deploy
  extends: .gcloud_deploy_template
  needs:
    - build:worker
  timeout: 15m
  resource_group: deploy-worker-staging
  variables:
    CLOUD_RUN_SERVICE_NAME: "invoice-ninja-worker"
    CLOUD_RUN_SERVICE_ACCOUNT: "${CLOUD_RUN_WEB_SA}"
    APP_ENV: "staging"
    APP_DEBUG: "false"
    CACHE_DRIVER: "redis"
    QUEUE_CONNECTION: "redis"
    MIN_INSTANCES: "0"
    MAX_INSTANCES: "2"
    MEMORY_LIMIT: "512Mi"
    CPU_LIMIT: "1"
    APP_KEY_SECRET: "invoice-ninja-dev-app-key"
    DB_PASSWORD_SECRET: "invoice-ninja-dev-db-password"
    SMTP_PASSWORD_SECRET: "invoice-ninja-dev-smtp-password"
    STRIPE_KEY_SECRET: "invoice-ninja-dev-stripe-key"
  script:
    - |
      gcloud run deploy "$CLOUD_RUN_SERVICE_NAME" \
        --image "$WORKER_IMAGE:$CI_COMMIT_SHA" \
        --region "$GCP_REGION" \
        --platform managed \
        --no-allow-unauthenticated \
        --service-account "$CLOUD_RUN_SERVICE_ACCOUNT" \
        --vpc-connector "$VPC_CONNECTOR" \
        --add-cloudsql-instances "$CLOUD_SQL_CONNECTION_NAME" \
        --set-env-vars "APP_ENV=${APP_ENV},APP_DEBUG=${APP_DEBUG},DB_CONNECTION=pgsql,DB_HOST=/cloudsql/${CLOUD_SQL_CONNECTION_NAME},DB_PORT=${DB_PORT},DB_DATABASE=${DB_DATABASE_NAME},DB_USERNAME=${DB_USERNAME},CACHE_DRIVER=${CACHE_DRIVER},QUEUE_CONNECTION=${QUEUE_CONNECTION}" \
        --set-secrets "APP_KEY=${APP_KEY_SECRET}:latest,DB_PASSWORD=${DB_PASSWORD_SECRET}:latest,SMTP_PASSWORD=${SMTP_PASSWORD_SECRET}:latest,STRIPE_KEY=${STRIPE_KEY_SECRET}:latest" \
        --memory "$MEMORY_LIMIT" \
        --cpu "$CPU_LIMIT" \
        --min-instances "$MIN_INSTANCES" \
        --max-instances "$MAX_INSTANCES" \
        --no-cpu-throttling \
        --concurrency "$CONCURRENCY" \
        --timeout 300 \
        --quiet
  environment:
    name: staging-worker
  rules:
    - if: '$CI_COMMIT_BRANCH =~ /^release\/.*$/'
      when: manual
    - if: '$CI_COMMIT_BRANCH == "releases"'
      when: manual

deploy:worker:prod:
  stage: deploy
  extends: .gcloud_deploy_template
  needs:
    - build:worker
  timeout: 15m
  resource_group: deploy-worker-prod
  variables:
    CLOUD_RUN_SERVICE_NAME: "invoice-ninja-worker"
    CLOUD_RUN_SERVICE_ACCOUNT: "${CLOUD_RUN_WEB_SA}"
    APP_ENV: "production"
    APP_DEBUG: "false"
    CACHE_DRIVER: "redis"
    QUEUE_CONNECTION: "redis"
    MIN_INSTANCES: "0"
    MAX_INSTANCES: "5"
    MEMORY_LIMIT: "1Gi"
    CPU_LIMIT: "1"
    APP_KEY_SECRET: "invoice-ninja-dev-app-key"
    DB_PASSWORD_SECRET: "invoice-ninja-dev-db-password"
    SMTP_PASSWORD_SECRET: "invoice-ninja-dev-smtp-password"
    STRIPE_KEY_SECRET: "invoice-ninja-dev-stripe-key"
  script:
    - |
      gcloud run deploy "$CLOUD_RUN_SERVICE_NAME" \
        --image "$WORKER_IMAGE:$CI_COMMIT_SHA" \
        --region "$GCP_REGION" \
        --platform managed \
        --no-allow-unauthenticated \
        --service-account "$CLOUD_RUN_SERVICE_ACCOUNT" \
        --vpc-connector "$VPC_CONNECTOR" \
        --add-cloudsql-instances "$CLOUD_SQL_CONNECTION_NAME" \
        --set-env-vars "APP_ENV=${APP_ENV},APP_DEBUG=${APP_DEBUG},DB_CONNECTION=pgsql,DB_HOST=/cloudsql/${CLOUD_SQL_CONNECTION_NAME},DB_PORT=${DB_PORT},DB_DATABASE=${DB_DATABASE_NAME},DB_USERNAME=${DB_USERNAME},CACHE_DRIVER=${CACHE_DRIVER},QUEUE_CONNECTION=${QUEUE_CONNECTION}" \
        --set-secrets "APP_KEY=${APP_KEY_SECRET}:latest,DB_PASSWORD=${DB_PASSWORD_SECRET}:latest,SMTP_PASSWORD=${SMTP_PASSWORD_SECRET}:latest,STRIPE_KEY=${STRIPE_KEY_SECRET}:latest" \
        --memory "$MEMORY_LIMIT" \
        --cpu "$CPU_LIMIT" \
        --min-instances "$MIN_INSTANCES" \
        --max-instances "$MAX_INSTANCES" \
        --no-cpu-throttling \
        --concurrency "$CONCURRENCY" \
        --timeout 300 \
        --quiet
  environment:
    name: production-worker
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: manual
    - if: '$CI_COMMIT_TAG'
      when: manual
"""

# Insert after deploy:web:prod block. The block ends with "when: manual"
target_text = """  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: manual
    - if: '$CI_COMMIT_TAG'
      when: manual"""

new_content = content.replace(target_text, target_text + worker_jobs)

with open('.gitlab-ci.yml', 'w') as f:
    f.write(new_content)
