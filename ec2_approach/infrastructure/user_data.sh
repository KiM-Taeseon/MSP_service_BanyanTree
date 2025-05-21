### infrastructure/user_data.sh
#!/bin/bash

# Update system
yum update -y

# Install required packages
yum install -y wget unzip python3 python3-pip git jq

# Set up environment variables
cat > /etc/environment <<EOF
STATE_BUCKET=${state_bucket}
CONFIG_BUCKET=${config_bucket}
LOCK_TABLE=${lock_table}
AWS_REGION=${aws_region}
EOF

# Create terraform user
useradd terraform
mkdir -p /home/terraform/.aws
mkdir -p /home/terraform/projects
mkdir -p /home/terraform/logs
chown -R terraform:terraform /home/terraform

# Install Terraform
TERRAFORM_VERSION="1.6.6"
wget https://releases.hashicorp.com/terraform/$TERRAFORM_VERSION/terraform_$TERRAFORM_VERSION_linux_amd64.zip
unzip terraform_$TERRAFORM_VERSION_linux_amd64.zip
mv terraform /usr/local/bin/
rm terraform_$TERRAFORM_VERSION_linux_amd64.zip

# Install AWS CLI
pip3 install awscli --upgrade

# Create runner script directory
mkdir -p /opt/terraform-runner

# Copy all the files from S3 (in production, you would upload these files to S3 first)
# For now, we'll create them directly

# Create the run-terraform.sh script
cat > /opt/terraform-runner/run-terraform.sh <<'EOF'
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
EOF

chmod +x /opt/terraform-runner/run-terraform.sh

# Create the webhook server script
cat > /opt/terraform-runner/webhook-server.py <<'EOF'
#!/usr/bin/env python3

import http.server
import socketserver
import json
import subprocess
import os
import sys
import time
import threading
from urllib.parse import parse_qs, urlparse

PORT = 8080

class TerraformRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/run-terraform':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            try:
                request = json.loads(post_data.decode('utf-8'))
                
                # Extract parameters
                project_name = request.get('project_name')
                command = request.get('command', 'plan')
                variables = request.get('variables', {})
                
                if not project_name:
                    self.send_error(400, "Missing project_name parameter")
                    return
                
                # Convert variables to JSON string
                variables_json = json.dumps(variables)
                
                # Run terraform in a separate thread
                threading.Thread(target=self.run_terraform, 
                                 args=(project_name, command, variables_json)).start()
                
                # Send response
                self.send_response(202)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                response = {
                    'status': 'accepted',
                    'message': f'Terraform {command} for {project_name} started',
                    'log_file': f'/home/terraform/logs/terraform-{project_name}-*.log'
                }
                self.wfile.write(json.dumps(response).encode())
                
            except json.JSONDecodeError:
                self.send_error(400, "Invalid JSON in request body")
            except Exception as e:
                self.send_error(500, str(e))
        else:
            self.send_error(404, "Not found")
    
    def run_terraform(self, project_name, command, variables_json):
        try:
            subprocess.run([
                '/opt/terraform-runner/run-terraform.sh',
                project_name,
                command,
                variables_json
            ], check=True)
        except subprocess.CalledProcessError as e:
            print(f"Error running Terraform: {e}", file=sys.stderr)
    
    def log_message(self, format, *args):
        # Override to add timestamp
        sys.stderr.write("%s - %s - %s\n" %
                         (self.log_date_time_string(),
                          self.address_string(),
                          format % args))

def run_server():
    with socketserver.TCPServer(("", PORT), TerraformRequestHandler) as httpd:
        print(f"Serving webhook at port {PORT}")
        httpd.serve_forever()

if __name__ == "__main__":
    run_server()
EOF

chmod +x /opt/terraform-runner/webhook-server.py

# Create systemd service file
cat > /etc/systemd/system/terraform-webhook.service <<EOF
[Unit]
Description=Terraform Webhook Server
After=network.target

[Service]
User=terraform
Group=terraform
WorkingDirectory=/home/terraform
ExecStart=/usr/bin/python3 /opt/terraform-runner/webhook-server.py
Restart=always
Environment=PATH=/usr/local/bin:/usr/bin:/bin
EnvironmentFile=/etc/environment

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable terraform-webhook
systemctl start terraform-webhook

# Set correct permissions
chown -R terraform:terraform /opt/terraform-runner