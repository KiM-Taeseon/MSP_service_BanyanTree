#!/bin/bash

# Update system
yum update -y

# Install required packages
yum install -y wget unzip python3 python3-pip git jq util-linux

# Set up environment variables
cat > /etc/environment <<EOF
STATE_BUCKET=terraform-state-runner-157931043046
CONFIG_BUCKET=terraform-configs-runner-157931043046 
AWS_REGION=ap-northeast-2
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

# Clone the terraform-runner repository
echo "Cloning terraform-runner repository..."
cd /tmp
git clone https://github.com/kuzwolka/terra-runner.git
cd terra-runner

# Copy files to appropriate locations
cp run-terraform.sh /opt/terraform-runner/
cp webhook-server.py /opt/terraform-runner/
cp systemd/terraform-webhook.service /etc/systemd/system/

# Make scripts executable
chmod +x /opt/terraform-runner/run-terraform.sh
chmod +x /opt/terraform-runner/webhook-server.py

# Clean up
cd /
rm -rf /tmp/terraform-runner

# Enable and start the service
systemctl daemon-reload
systemctl enable terraform-webhook
systemctl start terraform-webhook

# Set correct permissions
chown -R terraform:terraform /opt/terraform-runner