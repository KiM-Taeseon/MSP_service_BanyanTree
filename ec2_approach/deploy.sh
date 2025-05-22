#!/bin/bash

# Script to deploy the Single-User Terraform Runner + Project Builder infrastructure

set -e

# Variables
STATE_BUCKET="terraform-state-runner-$(aws sts get-caller-identity --query Account --output text)"
CONFIG_BUCKET="terraform-configs-runner-$(aws sts get-caller-identity --query Account --output text)"
AWS_REGION="ap-northeast-2"
KEY_NAME="your-ssh-key" # Replace with your SSH key name

echo "🚀 Deploying Terraform Runner + Project Builder Infrastructure"
echo "============================================================"

# Create S3 buckets if they don't exist
echo "📦 Creating S3 buckets..."
aws s3 mb s3://$STATE_BUCKET --region $AWS_REGION || true
aws s3 mb s3://$CONFIG_BUCKET --region $AWS_REGION || true

# Deploy infrastructure
echo "🏗️  Deploying infrastructure..."
cd infrastructure
terraform init
terraform apply -auto-approve \
  -var="state_bucket_name=$STATE_BUCKET" \
  -var="config_bucket_name=$CONFIG_BUCKET" \
  -var="key_name=$KEY_NAME"

# Get the instance public IPs
TERRAFORM_RUNNER_IP=$(terraform output -raw instance_public_ip)
PROJECT_BUILDER_IP=$(terraform output -raw project_builder_public_ip)

echo ""
echo "✅ Deployment complete!"
echo "======================="
echo ""
echo "🔧 Terraform Runner:"
echo "   IP: $TERRAFORM_RUNNER_IP"
echo "   Endpoint: http://$TERRAFORM_RUNNER_IP:8080/run-terraform"
echo ""
echo "🏭 Project Builder:"
echo "   IP: $PROJECT_BUILDER_IP"
echo "   Endpoint: http://$PROJECT_BUILDER_IP:8081/build-project"
echo "   Health Check: http://$PROJECT_BUILDER_IP:8081/health"
echo ""
echo "📁 S3 Buckets:"
echo "   State: s3://$STATE_BUCKET"
echo "   Configs: s3://$CONFIG_BUCKET"
echo ""

# Package and upload the example project
echo "📦 Packaging and uploading example project..."
cd ../terraform-projects/example-project
zip -r ../../example-project.zip .
cd ../..
aws s3 cp example-project.zip s3://$CONFIG_BUCKET/
rm example-project.zip

echo ""
echo "🎉 System is ready!"
echo "=================="
echo ""
echo "📋 Complete Workflow:"
echo "1. Build Project:"
echo "   curl -X POST http://$PROJECT_BUILDER_IP:8081/build-project \\"
echo "        -H \"Content-Type: application/json\" \\"
echo "        -d '{"
echo "              \"project_name\": \"my-custom-project\","
echo "              \"infrastructure_spec\": {"
echo "                \"vpc_cidr\": \"10.0.0.0/16\","
echo "                \"subnets\": [\"10.0.1.0/24\", \"10.0.2.0/24\"],"
echo "                \"instances\": [{\"type\": \"t3.micro\", \"count\": 2}]"
echo "              }"
echo "            }'"
echo ""
echo "2. Deploy Infrastructure:"
echo "   curl -X POST http://$TERRAFORM_RUNNER_IP:8080/run-terraform \\"
echo "        -H \"Content-Type: application/json\" \\"
echo "        -d '{"
echo "              \"project_name\": \"my-custom-project\","
echo "              \"command\": \"apply\","
echo "              \"variables\": {\"environment\": \"production\"}"
echo "            }'"
echo ""
echo "🔍 Monitoring:"
echo "   SSH to Terraform Runner: ssh -i $KEY_NAME.pem ec2-user@$TERRAFORM_RUNNER_IP"
echo "   SSH to Project Builder:  ssh -i $KEY_NAME.pem ec2-user@$PROJECT_BUILDER_IP"
echo "   Terraform Runner logs:   /home/terraform/logs/"
echo "   Project Builder logs:    /home/projectbuilder/logs/"