#!/bin/bash
# Fixed deploy.sh - Let Terraform manage all resources

set -e

# Get current AWS account and region
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="ap-northeast-2"
KEY_NAME="banyan_key"

# Variables
STATE_BUCKET="terraform-state-runner-$ACCOUNT_ID"
CONFIG_BUCKET="terraform-configs-runner-$ACCOUNT_ID"

echo "🚀 Deploying Terraform Runner + Project Builder Infrastructure"
echo "============================================================"
echo "Account ID: $ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo "State Bucket: $STATE_BUCKET"
echo "Config Bucket: $CONFIG_BUCKET"
echo ""

# Validate prerequisites
echo "🔍 Validating prerequisites..."

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ ERROR: AWS CLI not configured. Run 'aws configure' first."
    exit 1
fi

# Check if SSH key exists
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" > /dev/null 2>&1; then
    echo "❌ ERROR: SSH key '$KEY_NAME' not found in region $AWS_REGION"
    echo "Create it with: aws ec2 create-key-pair --key-name $KEY_NAME --region $AWS_REGION"
    exit 1
fi

# Deploy infrastructure with Terraform (no manual S3 creation)
echo "🏗️  Deploying infrastructure with Terraform..."
cd infrastructure

# Initialize Terraform
echo "📋 Initializing Terraform..."
if ! terraform init; then
    echo "❌ Terraform initialization failed"
    exit 1
fi

# Validate configuration
echo "🔍 Validating Terraform configuration..."
if ! terraform validate; then
    echo "❌ Terraform configuration validation failed"
    exit 1
fi

# Plan deployment
echo "📋 Planning deployment..."
if ! terraform plan \
    -var="state_bucket_name=$STATE_BUCKET" \
    -var="config_bucket_name=$CONFIG_BUCKET" \
    -var="key_name=$KEY_NAME" \
    -out=tfplan; then
    echo "❌ Terraform planning failed"
    exit 1
fi

# Apply with confirmation
echo "🚀 Applying infrastructure..."
if ! terraform apply tfplan; then
    echo "❌ Terraform apply failed"
    exit 1
fi

# Validate deployment
echo "✅ Validating deployment..."
if ! terraform output instance_public_ip > /dev/null 2>&1; then
    echo "❌ Deployment validation failed - missing outputs"
    exit 1
fi

# Get outputs
TERRAFORM_RUNNER_IP=$(terraform output -raw instance_public_ip)
PROJECT_BUILDER_IP=$(terraform output -raw project_builder_public_ip)

echo ""
echo "✅ Deployment completed successfully!"
echo "======================================"
echo ""
echo "🔧 Terraform Runner: http://$TERRAFORM_RUNNER_IP:8080"
echo "🏭 Project Builder:   http://$PROJECT_BUILDER_IP:8081"
echo ""
echo "⏳ Services are starting up (may take 2-3 minutes)..."
echo "Check status with:"
echo "  curl http://$PROJECT_BUILDER_IP:8081/health"
echo ""
echo "📋 Resources created:"
echo "   State Bucket: $STATE_BUCKET"
echo "   Config Bucket: $CONFIG_BUCKET"
echo "   Terraform Runner IP: $TERRAFORM_RUNNER_IP"
echo "   Project Builder IP: $PROJECT_BUILDER_IP"