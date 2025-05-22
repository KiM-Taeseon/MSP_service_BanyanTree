#!/bin/bash

# Project Builder EC2 User Data Script

# Update system
yum update -y

# Install required packages
yum install -y wget unzip python3 python3-pip git jq util-linux zip

# Set up environment variables
cat > /etc/environment <<EOF
CONFIG_BUCKET=${config_bucket}
AWS_REGION=${aws_region}
EOF

# Create project-builder user
useradd projectbuilder
mkdir -p /home/projectbuilder/.aws
mkdir -p /home/projectbuilder/projects
mkdir -p /home/projectbuilder/logs
mkdir -p /home/projectbuilder/scripts
chown -R projectbuilder:projectbuilder /home/projectbuilder

# Install AWS CLI
pip3 install awscli --upgrade

# Create project builder script directory
mkdir -p /opt/project-builder

# Create the project builder webhook server
cat > /opt/project-builder/webhook-server.py <<'EOF'
#!/usr/bin/env python3

import http.server
import socketserver
import json
import subprocess
import os
import sys
import time
import threading
import tempfile
from urllib.parse import parse_qs, urlparse

PORT = 8081

class ProjectBuilderRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/build-project':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            try:
                request = json.loads(post_data.decode('utf-8'))
                
                # Extract parameters
                project_name = request.get('project_name')
                infrastructure_spec = request.get('infrastructure_spec', {})
                
                if not project_name:
                    self.send_error(400, "Missing project_name parameter")
                    return
                
                if not infrastructure_spec:
                    self.send_error(400, "Missing infrastructure_spec parameter")
                    return
                
                # Generate a unique build ID
                build_id = str(int(time.time()))
                
                # Run project builder in a separate thread
                threading.Thread(target=self.build_project, 
                                 args=(project_name, infrastructure_spec, build_id)).start()
                
                # Send response
                self.send_response(202)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                response = {
                    'status': 'accepted',
                    'message': f'Project build for {project_name} started',
                    'build_id': build_id,
                    'log_file': f'/home/projectbuilder/logs/build-{project_name}-{build_id}.log'
                }
                self.wfile.write(json.dumps(response).encode())
                
            except json.JSONDecodeError:
                self.send_error(400, "Invalid JSON in request body")
            except Exception as e:
                self.send_error(500, str(e))
        elif self.path == '/health':
            # Health check endpoint
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {'status': 'healthy', 'service': 'project-builder'}
            self.wfile.write(json.dumps(response).encode())
        else:
            self.send_error(404, "Not found")
    
    def build_project(self, project_name, infrastructure_spec, build_id):
        try:
            # Create temporary file for infrastructure spec
            with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as temp_file:
                json.dump(infrastructure_spec, temp_file, indent=2)
                spec_file_path = temp_file.name
            
            # Run the project builder script
            subprocess.run([
                '/opt/project-builder/build-and-upload.sh',
                project_name,
                spec_file_path,
                build_id
            ], check=True)
            
            # Clean up temporary file
            os.unlink(spec_file_path)
            
        except subprocess.CalledProcessError as e:
            print(f"Error building project: {e}", file=sys.stderr)
        except Exception as e:
            print(f"Unexpected error: {e}", file=sys.stderr)
    
    def log_message(self, format, *args):
        # Override to add timestamp
        sys.stderr.write("%s - %s - %s\n" %
                         (self.log_date_time_string(),
                          self.address_string(),
                          format % args))

def run_server():
    with socketserver.TCPServer(("", PORT), ProjectBuilderRequestHandler) as httpd:
        print(f"Serving Project Builder webhook at port {PORT}")
        httpd.serve_forever()

if __name__ == "__main__":
    run_server()
EOF

chmod +x /opt/project-builder/webhook-server.py

# Create the build and upload script
cat > /opt/project-builder/build-and-upload.sh <<'EOF'
#!/bin/bash

# Project Builder and Upload Script
# Usage: ./build-and-upload.sh [project_name] [spec_file_path] [build_id]

set -e

# Get parameters
PROJECT_NAME=$1
SPEC_FILE_PATH=$2
BUILD_ID=$3

# Load environment variables
source /etc/environment

# Set up logging
LOG_FILE="/home/projectbuilder/logs/build-$PROJECT_NAME-$BUILD_ID.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "==== Project Builder ====="
echo "Build ID: $BUILD_ID"
echo "Project: $PROJECT_NAME"
echo "Spec File: $SPEC_FILE_PATH"
echo "Timestamp: $(date)"
echo "=========================="

# Create project directory
PROJECT_DIR="/home/projectbuilder/projects/$PROJECT_NAME-$BUILD_ID"
mkdir -p "$PROJECT_DIR"

echo "Created project directory: $PROJECT_DIR"

# Copy the infrastructure spec for reference
cp "$SPEC_FILE_PATH" "$PROJECT_DIR/infrastructure_spec.json"

echo "Infrastructure specification:"
cat "$PROJECT_DIR/infrastructure_spec.json"
echo ""

# Call the black box script to generate Terraform files
echo "Calling terraform generator script..."
/home/projectbuilder/scripts/generate-terraform.sh "$PROJECT_NAME" "$SPEC_FILE_PATH" "$PROJECT_DIR"

echo "Terraform files generated. Project structure:"
find "$PROJECT_DIR" -name "*.tf" -o -name "*.json" | head -20

# Validate that essential Terraform files were created
if [ ! -f "$PROJECT_DIR/main.tf" ]; then
    echo "ERROR: main.tf not found. Terraform generation may have failed."
    exit 1
fi

# Package the project
echo "Packaging project..."
cd "$PROJECT_DIR"
zip -r "../$PROJECT_NAME.zip" . -x "infrastructure_spec.json"
cd ..

# Upload to S3
echo "Uploading project to S3..."
aws s3 cp "$PROJECT_NAME.zip" "s3://$CONFIG_BUCKET/" --region "$AWS_REGION"

# Verify upload
if aws s3 ls "s3://$CONFIG_BUCKET/$PROJECT_NAME.zip" --region "$AWS_REGION" > /dev/null 2>&1; then
    echo "✅ Project successfully uploaded to s3://$CONFIG_BUCKET/$PROJECT_NAME.zip"
else
    echo "❌ Failed to upload project to S3"
    exit 1
fi

# Clean up
echo "Cleaning up temporary files..."
rm -rf "$PROJECT_DIR"
rm -f "$PROJECT_NAME.zip"

echo "🎉 Project build and upload completed successfully!"
echo "Project '$PROJECT_NAME' is now available for Terraform provisioning."

exit 0
EOF

chmod +x /opt/project-builder/build-and-upload.sh

# Create a placeholder black box script (to be replaced with actual implementation)
mkdir -p /home/projectbuilder/scripts
cat > /home/projectbuilder/scripts/generate-terraform.sh <<'EOF'
#!/bin/bash

# Black Box Terraform Generator Script
# This is a placeholder - replace with your actual implementation
# Usage: ./generate-terraform.sh [project_name] [spec_file_path] [output_dir]

PROJECT_NAME=$1
SPEC_FILE_PATH=$2
OUTPUT_DIR=$3

echo "🔧 Generating Terraform files for project: $PROJECT_NAME"
echo "📋 Using specification: $SPEC_FILE_PATH"
echo "📁 Output directory: $OUTPUT_DIR"

# Read the infrastructure specification
SPEC_CONTENT=$(cat "$SPEC_FILE_PATH")
echo "Infrastructure specification loaded"

# Create basic main.tf (placeholder implementation)
cat > "$OUTPUT_DIR/main.tf" <<EOT
# Generated Terraform configuration for $PROJECT_NAME
# Generated at: $(date)

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# This is a placeholder implementation
# Replace this script with your actual Terraform generation logic

# Example: Parse JSON and generate resources based on specification
# The actual implementation would parse the JSON specification
# and generate appropriate Terraform resources

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "$PROJECT_NAME"
}

# Placeholder resource (replace with actual generated resources)
resource "aws_s3_bucket" "placeholder" {
  bucket = "\${var.project_name}-placeholder-\${random_id.suffix.hex}"
  
  tags = {
    Name      = "\${var.project_name}-placeholder"
    Generated = "true"
    Timestamp = "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}
EOT

# Create variables.tf
cat > "$OUTPUT_DIR/variables.tf" <<EOT
# Generated variables for $PROJECT_NAME

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# Add more variables based on your specification parsing logic
EOT

# Create outputs.tf
cat > "$OUTPUT_DIR/outputs.tf" <<EOT
# Generated outputs for $PROJECT_NAME

output "project_name" {
  description = "Name of the project"
  value       = var.project_name
}

output "placeholder_bucket_name" {
  description = "Name of the placeholder S3 bucket"
  value       = aws_s3_bucket.placeholder.id
}

# Add more outputs based on your generated resources
EOT

echo "✅ Terraform files generated successfully"
echo "Generated files:"
ls -la "$OUTPUT_DIR"/*.tf

EOF

chmod +x /home/projectbuilder/scripts/generate-terraform.sh
chown -R projectbuilder:projectbuilder /home/projectbuilder/scripts

# Create systemd service file for project builder
cat > /etc/systemd/system/project-builder-webhook.service <<EOF
[Unit]
Description=Project Builder Webhook Server
After=network.target

[Service]
User=projectbuilder
Group=projectbuilder
WorkingDirectory=/home/projectbuilder
ExecStart=/usr/bin/python3 /opt/project-builder/webhook-server.py
Restart=always
Environment=PATH=/usr/local/bin:/usr/bin:/bin
EnvironmentFile=/etc/environment

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable project-builder-webhook
systemctl start project-builder-webhook

# Set correct permissions
chown -R projectbuilder:projectbuilder /opt/project-builder