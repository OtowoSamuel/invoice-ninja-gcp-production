import re

with open('.gitlab-ci.yml', 'r') as f:
    content = f.read()

# Find where the Terraform section starts
start_marker = "# ==============================================================================\n# TERRAFORM INFRASTRUCTURE PIPELINE\n# =============================================================================="
parts = content.split(start_marker)

if len(parts) < 2:
    print("Could not find terraform section")
    exit(1)

new_tf_section = """
.terraform_template:
  image:
    name: hashicorp/terraform:1.5
    entrypoint: [""]
  before_script:
    - cd terraform/environments/${ENV}
    - export GOOGLE_CREDENTIALS="${GCP_SERVICE_KEY}"
    - export TF_IN_AUTOMATION=true
    - |
      ALERT_EMAIL_VALUE="${GCP_ALERT_EMAIL:-${ALERT_EMAIL:-}}"
      if [ -z "${GCP_PROJECT_ID:-}" ] || [ -z "${ALERT_EMAIL_VALUE:-}" ]; then
        echo "GCP_PROJECT_ID and GCP_ALERT_EMAIL (or ALERT_EMAIL) must be set in GitLab CI/CD variables"
        exit 1
      fi
    - |
      cat > terraform.auto.tfvars <<EOF
      project_id = "${GCP_PROJECT_ID}"
      alert_email = "${ALERT_EMAIL_VALUE}"
      EOF
    - terraform init

tf:plan:dev:
  stage: infrastructure-plan
  extends: .terraform_template
  needs: []
  timeout: 10m
  variables:
    ENV: "dev"
  script:
    - terraform plan -input=false -out=tfplan
  artifacts:
    paths:
      - terraform/environments/dev/tfplan
    expire_in: 1 week
  environment:
    name: dev
    action: prepare
  rules:
    - if: '$CI_COMMIT_BRANCH == "develop"'
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'

tf:apply:dev:
  stage: infrastructure-apply
  extends: .terraform_template
  timeout: 30m
  resource_group: terraform-dev
  variables:
    ENV: "dev"
  script:
    - terraform apply -input=false -auto-approve tfplan
  dependencies:
    - tf:plan:dev
  environment:
    name: dev
  rules:
    - if: '$CI_COMMIT_BRANCH == "develop"'

tf:destroy:dev:
  stage: destroy
  extends: .terraform_template
  timeout: 30m
  resource_group: terraform-dev
  variables:
    ENV: "dev"
  script:
    - terraform destroy -input=false -auto-approve
  environment:
    name: dev
  rules:
    - if: '$CI_COMMIT_BRANCH == "develop"'
      when: manual

tf:plan:staging:
  stage: infrastructure-plan
  extends: .terraform_template
  needs: []
  timeout: 10m
  variables:
    ENV: "staging"
  script:
    - terraform plan -input=false -out=tfplan
  artifacts:
    paths:
      - terraform/environments/staging/tfplan
    expire_in: 1 week
  environment:
    name: staging
    action: prepare
  rules:
    - if: '$CI_COMMIT_BRANCH =~ /^release\/.*$/'
    - if: '$CI_COMMIT_BRANCH == "releases"'

tf:apply:staging:
  stage: infrastructure-apply
  extends: .terraform_template
  timeout: 30m
  resource_group: terraform-staging
  variables:
    ENV: "staging"
  script:
    - terraform apply -input=false -auto-approve tfplan
  dependencies:
    - tf:plan:staging
  environment:
    name: staging
  rules:
    - if: '$CI_COMMIT_BRANCH =~ /^release\/.*$/'
      when: manual
    - if: '$CI_COMMIT_BRANCH == "releases"'
      when: manual

tf:destroy:staging:
  stage: destroy
  extends: .terraform_template
  timeout: 30m
  resource_group: terraform-staging
  variables:
    ENV: "staging"
  script:
    - terraform destroy -input=false -auto-approve
  environment:
    name: staging
  rules:
    - if: '$CI_COMMIT_BRANCH =~ /^release\/.*$/'
      when: manual
    - if: '$CI_COMMIT_BRANCH == "releases"'
      when: manual

tf:plan:prod:
  stage: infrastructure-plan
  extends: .terraform_template
  needs: []
  timeout: 10m
  variables:
    ENV: "prod"
  script:
    - terraform plan -input=false -out=tfplan
  artifacts:
    paths:
      - terraform/environments/prod/tfplan
    expire_in: 1 week
  environment:
    name: production
    action: prepare
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'

tf:apply:prod:
  stage: infrastructure-apply
  extends: .terraform_template
  timeout: 30m
  resource_group: terraform-prod
  variables:
    ENV: "prod"
  script:
    - terraform apply -input=false -auto-approve tfplan
  dependencies:
    - tf:plan:prod
  environment:
    name: production
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: manual
"""

with open('.gitlab-ci.yml', 'w') as f:
    f.write(parts[0] + start_marker + "\n" + new_tf_section)
