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
#AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${DEFAULT_AWS_REGION:-us-east-1}
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
WORKSPACE_ID="ws-WiwHV6fVASxSJhc9"
ORG_NAME="mahen-arch"

# Check if TFC_TOKEN is set
if [ -z "$TFC_TOKEN" ]; then
  echo "❌ Error: TFC_TOKEN environment variable is not set"
  echo "Please set it in your .env file or GitHub secrets"
  exit 1
fi

# Get the latest state version outputs
API_RESPONSE=$(curl -s \
  --header "Authorization: Bearer $TFC_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  "https://app.terraform.io/api/v2/workspaces/${WORKSPACE_ID}/current-state-version?include=outputs")

# Check if API call was successful
if [ -z "$API_RESPONSE" ]; then
  echo "❌ Error: Failed to fetch data from HCP Terraform API"
  exit 1
fi

# Check if there are any outputs
if ! echo "$API_RESPONSE" | jq -e '.included' > /dev/null 2>&1; then
  echo "❌ Error: No outputs found in HCP Terraform workspace"
  echo "Make sure terraform apply has been run successfully in the workspace"
  exit 1
fi

# Parse outputs
OUTPUTS=$(echo "$API_RESPONSE" | jq -r '.included[]? | select(.type=="state-version-outputs") | {(.attributes.name): .attributes.value} | to_entries[] | "\(.key)=\(.value)"')

# Parse individual outputs
API_URL=$(echo "$OUTPUTS" | grep "^api_gateway_url=" | cut -d'=' -f2-)
FRONTEND_BUCKET=$(echo "$OUTPUTS" | grep "^s3_frontend_bucket=" | cut -d'=' -f2-)
CLOUDFRONT_URL=$(echo "$OUTPUTS" | grep "^cloudfront_url=" | cut -d'=' -f2-)
CUSTOM_URL=$(echo "$OUTPUTS" | grep "^custom_domain_url=" | cut -d'=' -f2-)

echo "🔍 Debug: Parsed Outputs"
echo "API_URL: $API_URL"
echo "FRONTEND_BUCKET: $FRONTEND_BUCKET"
echo "CLOUDFRONT_URL: $CLOUDFRONT_URL"
echo "CUSTOM_URL: $CUSTOM_URL"


# Validate required outputs
if [ -z "$API_URL" ] || [ -z "$FRONTEND_BUCKET" ]; then
  echo "❌ Error: Required outputs not found (api_gateway_url or s3_frontend_bucket)"
  echo "Available outputs:"
  echo "$OUTPUTS"
  exit 1
fi

echo "✅ Successfully fetched outputs from HCP Terraform"



# 3. Build + deploy frontend
cd frontend

# Create production environment file with API URL
echo "📝 Setting API URL for production..."
echo "NEXT_PUBLIC_API_URL=$API_URL" > .env.production

npm install
npm run build

echo "📤 Deploying frontend to S3 bucket: $FRONTEND_BUCKET ..."
aws s3 sync ./out "s3://$FRONTEND_BUCKET/" --delete
cd ..

# 4. Invalidate CloudFront
echo "🔄 Invalidating CloudFront cache..."
if [ -n "$CLOUDFRONT_URL" ]; then
  # Extract domain from URL (remove https://)
  CF_DOMAIN=${CLOUDFRONT_URL#https://}
  
  # Find distribution ID by domain name (more reliable than origin)
  DISTRIBUTION_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?contains(Aliases.Items, '$CF_DOMAIN') || DomainName=='$CF_DOMAIN'].Id | [0]" --output text)
  
  if [ "$DISTRIBUTION_ID" != "None" ] && [ -n "$DISTRIBUTION_ID" ]; then
    echo "Found distribution ID: $DISTRIBUTION_ID"
    aws cloudfront create-invalidation --distribution-id "$DISTRIBUTION_ID" --paths "/*"
  else
    echo "⚠️ Could not find CloudFront distribution for $CLOUDFRONT_URL"
    # Fallback: try to find by origin bucket
    echo "Trying to find by origin bucket..."
    DISTRIBUTION_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Origins.Items[?contains(DomainName, '$FRONTEND_BUCKET')]].Id | [0]" --output text)
    if [ "$DISTRIBUTION_ID" != "None" ] && [ -n "$DISTRIBUTION_ID" ]; then
       echo "Found distribution ID: $DISTRIBUTION_ID"
       aws cloudfront create-invalidation --distribution-id "$DISTRIBUTION_ID" --paths "/*"
    else
       echo "❌ Failed to find distribution ID. Please invalidate manually."
    fi
  fi
fi


echo -e "\n✅ Deployment complete!"
echo "🌐 CloudFront URL : $CLOUDFRONT_URL"
if [ -n "$CUSTOM_URL" ]; then
  echo "🔗 Custom domain  : $CUSTOM_URL"
fi
echo "📡 API Gateway    : $API_URL"
