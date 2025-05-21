## Terraform Runner Script

### terraform-runner/run-terraform.sh
#!/bin/bash

# Terraform Runner Script
# Usage: ./run-terraform.sh [project_name] [command] [variables_json]

set -e

# Get parameters
PROJECT_NAME=$1
COMMAND=$2
VARIABLES_JSON=$3

# Load environment variables
source /etc/environment

# Set up logging
LOG_FILE="/home/terraform/logs/terraform-$PROJECT_NAME-$(date +%Y%m%d%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==== Terraform Runner ====="
echo "Project: $PROJECT_NAME"
echo "Command: $COMMAND"
echo "Variables: $VARIABLES_JSON"
echo "=========================="

# Create project directory if it doesn't exist
WORK_DIR="/home/terraform/projects/$PROJECT_NAME"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Download the project from S3
echo "Downloading project from S3..."
aws s3 cp "s3://$CONFIG_BUCKET/$PROJECT_NAME.zip" ./project.zip
unzip -o project.zip
rm project.zip

# Prepare backend config
cat > backend.tf <<EOT
terraform {
  backend "s3" {
    bucket         = "$STATE_BUCKET"
    key            = "$PROJECT_NAME/terraform.tfstate"
    region         = "$AWS_REGION"
    dynamodb_table = "$LOCK_TABLE"
    encrypt        = true
  }
}
EOT

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Create terraform.tfvars.json if variables provided
if [ ! -z "$VARIABLES_JSON" ]; then
  echo "Creating variables file..."
  echo "$VARIABLES_JSON" > terraform.tfvars.json
fi

# Run the requested command
echo "Running Terraform $COMMAND..."
case "$COMMAND" in
  "plan")
    terraform plan -out=tfplan
    ;;
  "apply")
    terraform apply -auto-approve
    ;;
  "destroy")
    terraform destroy -auto-approve
    ;;
  "output")
    terraform output -json
    ;;
  *)
    echo "Unknown command: $COMMAND"
    exit 1
    ;;
esac

echo "Terraform execution completed successfully!"
exit 0