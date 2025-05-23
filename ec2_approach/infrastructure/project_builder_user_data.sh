#!/bin/bash

# Project Builder EC2 User Data Script

# Update system
yum update -y

# Install required packages
yum install -y wget unzip python3 python3-pip git jq util-linux zip

# Install Terraform (needed for validation)
TERRAFORM_VERSION="1.6.6"
wget https://releases.hashicorp.com/terraform/$TERRAFORM_VERSION/terraform_$TERRAFORM_VERSION_linux_amd64.zip
unzip terraform_$TERRAFORM_VERSION_linux_amd64.zip
mv terraform /usr/local/bin/
rm terraform_$TERRAFORM_VERSION_linux_amd64.zip

# Set up environment variables
cat > /etc/environment <<EOF
CONFIG_BUCKET=terraform-configs-runner-157931043046 
AWS_REGION=ap-northeast-2
EOF

# Create project-builder user
useradd projectbuilder
mkdir -p /home/projectbuilder/.aws
mkdir -p /home/projectbuilder/projects
mkdir -p /home/projectbuilder/logs
chown -R projectbuilder:projectbuilder /home/projectbuilder

# Install AWS CLI
pip3 install awscli --upgrade

# Create project builder script directory
mkdir -p /opt/project-builder

# Clone the project-builder repository
echo "Cloning project-builder repository..."
cd /tmp
git clone https://github.com/kuzwolka/terra-builder.git
cd terra-builder

# Copy files to appropriate locations
cp webhook-server.py /opt/project-builder/
cp build-and-upload.sh /opt/project-builder/
cp -r scripts /home/projectbuilder/
cp -r terraform_templates /home/templates/
cp systemd/project-builder-webhook.service /etc/systemd/system/

# Make scripts executable
chmod +x /opt/project-builder/webhook-server.py
chmod +x /opt/project-builder/build-and-upload.sh
chmod +x /home/projectbuilder/scripts/generate-terraform.sh

# Set correct permissions
chown -R projectbuilder:projectbuilder /home/projectbuilder
chown -R projectbuilder:projectbuilder /opt/project-builder
chown -R projectbuilder:projectbuilder /home/templates

# Clean up
cd /
rm -rf /tmp/project-builder

# Enable and start the service
systemctl daemon-reload
systemctl enable project-builder-webhook
systemctl start project-builder-webhook