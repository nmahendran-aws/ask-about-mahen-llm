#!/bin/bash
set -e

ENVIRONMENT=${1:-dev}          # dev | test | prod
PROJECT_NAME=${2:-ask-about-mahen}

# Load environment variables from .env if it exists
if [ -f "$(dirname "$0")/../.env" ]; then
  export $(cat "$(dirname "$0")/../.env" | grep -v '^#' | xargs)
fi

echo "🚀 Deploying ${PROJECT_NAME} to ${ENVIRONMENT}..."

# 1. Build Lambda package
cd "$(dirname "$0")/.."        # project root
echo "📦 Building Lambda package..."
(cd backend && uv run deploy.py)

# 2. Terraform workspace & apply
# cd terraform
# AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
# AWS_REGION=${DEFAULT_AWS_REGION:-us-east-1}
# terraform init -input=false

# if ! terraform workspace list | grep -q "$ENVIRONMENT"; then
#   terraform workspace new "$ENVIRONMENT"
# else
#   terraform workspace select "$ENVIRONMENT"
# fi

# # Use prod.tfvars for production environment
# if [ "$ENVIRONMENT" = "prod" ]; then
#   TF_APPLY_CMD=(terraform apply -var-file=prod.tfvars -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" -auto-approve)
# else
#   TF_APPLY_CMD=(terraform apply -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" -auto-approve)
# fi

# echo "🎯 Applying Terraform..."
# "${TF_APPLY_CMD[@]}"

# Fetch outputs from HCP Terraform workspace
echo "📥 Fetching outputs from HCP Terraform workspace..."
WORKSPACE_NAME="ask-about-mahen-llm"
ORG_NAME="mahen-arch"

# Get the latest state version outputs
OUTPUTS=$(curl -s \
  --header "Authorization: Bearer $TFC_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  "https://app.terraform.io/api/v2/workspaces/${ORG_NAME}/${WORKSPACE_NAME}/current-state-version?include=outputs" \
  | jq -r '.included[] | select(.type=="state-version-outputs") | {(.attributes.name): .attributes.value} | to_entries[] | "\(.key)=\(.value)"')

# Parse outputs
API_URL=$(echo "$OUTPUTS" | grep "^api_gateway_url=" | cut -d'=' -f2-)
FRONTEND_BUCKET=$(echo "$OUTPUTS" | grep "^s3_frontend_bucket=" | cut -d'=' -f2-)
CLOUDFRONT_URL=$(echo "$OUTPUTS" | grep "^cloudfront_url=" | cut -d'=' -f2-)
CUSTOM_URL=$(echo "$OUTPUTS" | grep "^custom_domain_url=" | cut -d'=' -f2-)


# 3. Build + deploy frontend
cd ../frontend

# Create production environment file with API URL
echo "📝 Setting API URL for production..."
echo "NEXT_PUBLIC_API_URL=$API_URL" > .env.production

npm install
npm run build

echo "📤 Deploying frontend to S3 bucket: $FRONTEND_BUCKET ..."
aws s3 sync ./out "s3://$FRONTEND_BUCKET/" --delete
cd ..

echo -e "\n✅ Deployment complete!"
echo "🌐 CloudFront URL : $CLOUDFRONT_URL"
if [ -n "$CUSTOM_URL" ]; then
  echo "🔗 Custom domain  : $CUSTOM_URL"
fi
echo "📡 API Gateway    : $API_URL"
