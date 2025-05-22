## Deployment Scripts

### deploy.sh
#!/bin/bash

# Script to deploy the Terraform Runner infrastructure

set -e

# Variables
STATE_BUCKET="terraform-state-runner-$(aws sts get-caller-identity --query Account --output text)"
CONFIG_BUCKET="terraform-configs-runner-$(aws sts get-caller-identity --query Account --output text)"
AWS_REGION="us-east-1"
KEY_NAME="your-ssh-key" # Replace with your SSH key name

# Create S3 buckets if they don't exist
echo "Creating S3 buckets..."
aws s3 mb s3://$STATE_BUCKET --region $AWS_REGION || true
aws s3 mb s3://$CONFIG_BUCKET --region $AWS_REGION || true

# Deploy infrastructure
echo "Deploying infrastructure..."
cd infrastructure
terraform init
terraform apply -auto-approve \
  -var="state_bucket_name=$STATE_BUCKET" \
  -var="config_bucket_name=$CONFIG_BUCKET" \
  -var="key_name=$KEY_NAME"

# Get the instance public IP
INSTANCE_IP=$(terraform output -raw instance_public_ip)
echo "Instance deployed with IP: $INSTANCE_IP"

# Package and upload the example project
echo "Packaging and uploading example project..."
cd ../terraform-projects/example-project
zip -r ../../example-project.zip .
cd ../..
aws s3 cp example-project.zip s3://$CONFIG_BUCKET/

echo "Deployment complete!"
echo "To trigger a Terraform run, use:"
echo "curl -X POST http://$INSTANCE_IP:8080/run-terraform \\"
echo "     -H \"Content-Type: application/json\" \\"
echo "     -d '{\"project_name\": \"example-project\", \"command\": \"apply\", \"variables\": {\"vpc_name\": \"custom-vpc\"}}'"