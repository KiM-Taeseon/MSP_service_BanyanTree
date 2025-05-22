#!/bin/bash

# Black Box Terraform Generator Script
# This is a placeholder implementation - replace with your actual logic
# Usage: ./generate-terraform.sh [project_name] [spec_file_path] [output_dir]

set -e

PROJECT_NAME=$1
SPEC_FILE_PATH=$2
OUTPUT_DIR=$3

# Validate parameters
if [ -z "$PROJECT_NAME" ] || [ -z "$SPEC_FILE_PATH" ] || [ -z "$OUTPUT_DIR" ]; then
    echo "Usage: $0 <project_name> <spec_file_path> <output_dir>"
    exit 1
fi

echo "🔧 TERRAFORM GENERATOR STARTING"
echo "==============================="
echo "Project Name: $PROJECT_NAME"
echo "Spec File: $SPEC_FILE_PATH"
echo "Output Directory: $OUTPUT_DIR"
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "==============================="

# Validate inputs
if [ ! -f "$SPEC_FILE_PATH" ]; then
    echo "❌ ERROR: Specification file not found: $SPEC_FILE_PATH"
    exit 1
fi

if [ ! -d "$OUTPUT_DIR" ]; then
    echo "❌ ERROR: Output directory not found: $OUTPUT_DIR"
    exit 1
fi

# Read and parse the infrastructure specification
echo "📋 Reading infrastructure specification..."
if ! SPEC_CONTENT=$(cat "$SPEC_FILE_PATH"); then
    echo "❌ ERROR: Failed to read specification file"
    exit 1
fi

# Validate JSON
if ! echo "$SPEC_CONTENT" | jq empty 2>/dev/null; then
    echo "❌ ERROR: Invalid JSON in specification file"
    exit 1
fi

# Extract key parameters from JSON spec
INFRA_TYPE=$(echo "$SPEC_CONTENT" | jq -r '.type // "generic"')
ENVIRONMENT=$(echo "$SPEC_CONTENT" | jq -r '.environment // "dev"')
REGION=$(echo "$SPEC_CONTENT" | jq -r '.region // "us-east-1"')

echo "📊 Parsed specification:"
echo "  Infrastructure Type: $INFRA_TYPE"
echo "  Environment: $ENVIRONMENT"  
echo "  Region: $REGION"

# Create Terraform version constraints
echo "📝 Generating versions.tf..."
cat > "$OUTPUT_DIR/versions.tf" <<EOF
# Terraform version constraints for $PROJECT_NAME
# Generated at: $(date -u '+%Y-%m-%d %H:%M:%S UTC')

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}
EOF

# Create main.tf based on infrastructure type
echo "🏗️  Generating main.tf..."
case "$INFRA_TYPE" in
  "vpc")
    generate_vpc_infrastructure
    ;;
  "web_application")
    generate_web_app_infrastructure
    ;;
  "data_processing")
    generate_data_infrastructure
    ;;
  *)
    generate_generic_infrastructure
    ;;
esac

# Create variables.tf
echo "📋 Generating variables.tf..."
generate_variables_file

# Create outputs.tf
echo "📤 Generating outputs.tf..."
generate_outputs_file

# Validate generated files
echo "✅ Validating generated files..."
GENERATED_FILES=(
    "$OUTPUT_DIR/versions.tf"
    "$OUTPUT_DIR/main.tf"
    "$OUTPUT_DIR/variables.tf"
    "$OUTPUT_DIR/outputs.tf"
)

for file in "${GENERATED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "❌ ERROR: Failed to generate $file"
        exit 1
    fi
    echo "  ✓ $(basename "$file") ($(wc -l < "$file") lines)"
done

echo ""
echo "🎉 TERRAFORM GENERATION COMPLETED"
echo "================================="
echo "Generated files for project: $PROJECT_NAME"
echo "Infrastructure type: $INFRA_TYPE"
echo "Output directory: $OUTPUT_DIR"
echo "✅ Ready for packaging and deployment"

exit 0

# Function to generate VPC infrastructure
generate_vpc_infrastructure() {
    local VPC_CIDR=$(echo "$SPEC_CONTENT" | jq -r '.vpc_cidr // "10.0.0.0/16"')
    
    cat > "$OUTPUT_DIR/main.tf" <<EOF
# VPC Infrastructure for $PROJECT_NAME
# Generated from specification at: $(date -u '+%Y-%m-%d %H:%M:%S UTC')

# Random suffix for unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

# Main VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name        = "\${var.project_name}-vpc-\${random_id.suffix.hex}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform-project-builder"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name        = "\${var.project_name}-igw-\${random_id.suffix.hex}"
    Environment = var.environment
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name        = "\${var.project_name}-public-\${count.index + 1}-\${random_id.suffix.hex}"
    Environment = var.environment
    Type        = "public"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = {
    Name        = "\${var.project_name}-private-\${count.index + 1}-\${random_id.suffix.hex}"
    Environment = var.environment
    Type        = "private"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = {
    Name        = "\${var.project_name}-public-rt-\${random_id.suffix.hex}"
    Environment = var.environment
  }
}

# Associate Public Subnets with Route Table
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}
EOF
}

# Function to generate web application infrastructure
generate_web_app_infrastructure() {
    cat > "$OUTPUT_DIR/main.tf" <<EOF
# Web Application Infrastructure for $PROJECT_NAME
# Generated from specification at: $(date -u '+%Y-%m-%d %H:%M:%S UTC')

# Random suffix for unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name        = "\${var.project_name}-vpc-\${random_id.suffix.hex}"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform-project-builder"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "\${var.project_name}-igw-\${random_id.suffix.hex}"
  }
}

# Public Subnets for Load Balancer
resource "aws_subnet" "public" {
  count = 2
  
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name = "\${var.project_name}-public-\${count.index + 1}-\${random_id.suffix.hex}"
    Type = "public"
  }
}

# Private Subnets for Application Servers
resource "aws_subnet" "private" {
  count = 2
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 2)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = {
    Name = "\${var.project_name}-private-\${count.index + 1}-\${random_id.suffix.hex}"
    Type = "private"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "\${var.project_name}-alb-\${random_id.suffix.hex}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
  
  tags = {
    Name        = "\${var.project_name}-alb"
    Environment = var.environment
  }
}

# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "\${var.project_name}-alb-sg-\${random_id.suffix.hex}"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "\${var.project_name}-alb-sg"
  }
}

# Launch Template for Auto Scaling
resource "aws_launch_template" "main" {
  name_prefix   = "\${var.project_name}-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  
  vpc_security_group_ids = [aws_security_group.app.id]
  
  user_data = base64encode(templatefile("\${path.module}/user_data.sh", {
    project_name = var.project_name
  }))
  
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "\${var.project_name}-instance"
      Environment = var.environment
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "main" {
  name                = "\${var.project_name}-asg-\${random_id.suffix.hex}"
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.main.arn]
  health_check_type   = "ELB"
  
  min_size         = var.min_instances
  max_size         = var.max_instances
  desired_capacity = var.desired_instances
  
  launch_template {
    id      = aws_launch_template.main.id
    version = "\$Latest"
  }
  
  tag {
    key                 = "Name"
    value               = "\${var.project_name}-asg"
    propagate_at_launch = false
  }
}

# Target Group for Load Balancer
resource "aws_lb_target_group" "main" {
  name     = "\${var.project_name}-tg-\${random_id.suffix.hex}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    unhealthy_threshold = 2
  }
  
  tags = {
    Name = "\${var.project_name}-tg"
  }
}

# Load Balancer Listener
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# Security Group for Application Instances
resource "aws_security_group" "app" {
  name        = "\${var.project_name}-app-sg-\${random_id.suffix.hex}"
  description = "Security group for application instances"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "\${var.project_name}-app-sg"
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
EOF

    # Create user data script for web application
    cat > "$OUTPUT_DIR/user_data.sh" <<EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Create a simple web page
cat > /var/www/html/index.html <<HTML
<!DOCTYPE html>
<html>
<head>
    <title>\${project_name} - Web Application</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background-color: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; text-align: center; }
        .info { background: #e8f4fd; padding: 20px; border-radius: 5px; margin: 20px 0; }
        .status { color: #27ae60; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 \${project_name}</h1>
        <div class="info">
            <h2>Application Status</h2>
            <p class="status">✅ Web server is running successfully!</p>
            <p><strong>Instance ID:</strong> <span id="instance-id">Loading...</span></p>
            <p><strong>Availability Zone:</strong> <span id="az">Loading...</span></p>
            <p><strong>Deploy Time:</strong> $(date)</p>
        </div>
        <div class="info">
            <h2>Generated by Terraform Project Builder</h2>
            <p>This infrastructure was generated from a JSON specification and deployed using the Terraform Runner system.</p>
        </div>
    </div>
    
    <script>
        // Get instance metadata
        fetch('http://169.254.169.254/latest/meta-data/instance-id')
            .then(response => response.text())
            .then(data => document.getElementById('instance-id').textContent = data)
            .catch(() => document.getElementById('instance-id').textContent = 'Not available');
            
        fetch('http://169.254.169.254/latest/meta-data/placement/availability-zone')
            .then(response => response.text())
            .then(data => document.getElementById('az').textContent = data)
            .catch(() => document.getElementById('az').textContent = 'Not available');
    </script>
</body>
</html>
HTML

# Create health check endpoint
cat > /var/www/html/health <<EOF
OK
EOF
EOF
}

# Function to generate data processing infrastructure
generate_data_infrastructure() {
    cat > "$OUTPUT_DIR/main.tf" <<EOF
# Data Processing Infrastructure for $PROJECT_NAME
# Generated from specification at: $(date -u '+%Y-%m-%d %H:%M:%S UTC')

# Random suffix for unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

# S3 Buckets for Data Storage
resource "aws_s3_bucket" "raw_data" {
  bucket = "\${var.project_name}-raw-data-\${random_id.suffix.hex}"
  
  tags = {
    Name        = "\${var.project_name}-raw-data"
    Environment = var.environment
    Purpose     = "raw-data-storage"
  }
}

resource "aws_s3_bucket" "processed_data" {
  bucket = "\${var.project_name}-processed-data-\${random_id.suffix.hex}"
  
  tags = {
    Name        = "\${var.project_name}-processed-data"
    Environment = var.environment
    Purpose     = "processed-data-storage"
  }
}

resource "aws_s3_bucket" "archive_data" {
  bucket = "\${var.project_name}-archive-data-\${random_id.suffix.hex}"
  
  tags = {
    Name        = "\${var.project_name}-archive-data"
    Environment = var.environment
    Purpose     = "archived-data-storage"
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "raw_data" {
  bucket = aws_s3_bucket.raw_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "processed_data" {
  bucket = aws_s3_bucket.processed_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

# DynamoDB Tables for Metadata
resource "aws_dynamodb_table" "processing_metadata" {
  name           = "\${var.project_name}-processing-metadata-\${random_id.suffix.hex}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "job_id"
  
  attribute {
    name = "job_id"
    type = "S"
  }
  
  tags = {
    Name        = "\${var.project_name}-processing-metadata"
    Environment = var.environment
  }
}

resource "aws_dynamodb_table" "data_catalog" {
  name           = "\${var.project_name}-data-catalog-\${random_id.suffix.hex}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "dataset_id"
  
  attribute {
    name = "dataset_id"
    type = "S"
  }
  
  tags = {
    Name        = "\${var.project_name}-data-catalog"
    Environment = var.environment
  }
}

# IAM Role for Lambda Functions
resource "aws_iam_role" "lambda_role" {
  name = "\${var.project_name}-lambda-role-\${random_id.suffix.hex}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda Functions
resource "aws_iam_role_policy" "lambda_policy" {
  name = "\${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "\${aws_s3_bucket.raw_data.arn}/*",
          "\${aws_s3_bucket.processed_data.arn}/*",
          "\${aws_s3_bucket.archive_data.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.processing_metadata.arn,
          aws_dynamodb_table.data_catalog.arn
        ]
      }
    ]
  })
}

# Lambda Function for Data Ingestion
resource "aws_lambda_function" "data_ingestion" {
  filename         = "lambda_placeholder.zip"
  function_name    = "\${var.project_name}-data-ingestion-\${random_id.suffix.hex}"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "python3.9"
  timeout         = 300
  
  tags = {
    Name        = "\${var.project_name}-data-ingestion"
    Environment = var.environment
  }
}

# Create placeholder Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "lambda_placeholder.zip"
  source {
    content = <<EOF
def handler(event, context):
    return {
        'statusCode': 200,
        'body': 'Data processing function - replace with actual implementation'
    }
EOF
    filename = "index.py"
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/\${aws_lambda_function.data_ingestion.function_name}"
  retention_in_days = var.log_retention_days
  
  tags = {
    Name        = "\${var.project_name}-lambda-logs"
    Environment = var.environment
  }
}
EOF
}

# Function to generate generic infrastructure
generate_generic_infrastructure() {
    cat > "$OUTPUT_DIR/main.tf" <<EOF
# Generic Infrastructure for $PROJECT_NAME
# Generated from specification at: $(date -u '+%Y-%m-%d %H:%M:%S UTC')

# Random suffix for unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

# Example S3 Bucket
resource "aws_s3_bucket" "main" {
  bucket = "\${var.project_name}-bucket-\${random_id.suffix.hex}"
  
  tags = {
    Name        = "\${var.project_name}-bucket"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform-project-builder"
    Generated   = "true"
    Timestamp   = "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Server Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Example DynamoDB Table
resource "aws_dynamodb_table" "main" {
  name           = "\${var.project_name}-table-\${random_id.suffix.hex}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  
  attribute {
    name = "id"
    type = "S"
  }
  
  tags = {
    Name        = "\${var.project_name}-table"
    Environment = var.environment
    Project     = var.project_name
  }
}
EOF
}

# Function to generate variables.tf
generate_variables_file() {
    cat > "$OUTPUT_DIR/variables.tf" <<EOF
# Variables for $PROJECT_NAME
# Generated at: $(date -u '+%Y-%m-%d %H:%M:%S UTC')

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "$PROJECT_NAME"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

# VPC-specific variables
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

# Instance-specific variables
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "min_instances" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 1
}

variable "max_instances" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 3
}

variable "desired_instances" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 2
}

variable "health_check_path" {
  description = "Health check path for load balancer"
  type        = string
  default     = "/health"
}

# Monitoring variables
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
EOF
}

# Function to generate outputs.tf
generate_outputs_file() {
    cat > "$OUTPUT_DIR/outputs.tf" <<EOF
# Outputs for $PROJECT_NAME
# Generated at: $(date -u '+%Y-%m-%d %H:%M:%S UTC')

output "project_name" {
  description = "Name of the project"
  value       = var.project_name
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

# Infrastructure-specific outputs (conditional based on what was created)
output "vpc_id" {
  description = "ID of the VPC"
  value       = try(aws_vpc.main.id, null)
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = try(aws_vpc.main.cidr_block, null)
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = try(aws_subnet.public[*].id, [])
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = try(aws_subnet.private[*].id, [])
}

output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = try(aws_lb.main.dns_name, null)
}

output "load_balancer_url" {
  description = "URL of the load balancer"
  value       = try("http://\${aws_lb.main.dns_name}", null)
}

output "s3_buckets" {
  description = "Names of created S3 buckets"
  value = {
    main           = try(aws_s3_bucket.main.id, null)
    raw_data       = try(aws_s3_bucket.raw_data.id, null)
    processed_data = try(aws_s3_bucket.processed_data.id, null)
    archive_data   = try(aws_s3_bucket.archive_data.id, null)
  }
}

output "dynamodb_tables" {
  description = "Names of created DynamoDB tables"
  value = {
    main                = try(aws_dynamodb_table.main.name, null)
    processing_metadata = try(aws_dynamodb_table.processing_metadata.name, null)
    data_catalog        = try(aws_dynamodb_table.data_catalog.name, null)
  }
}

output "lambda_functions" {
  description = "Names of created Lambda functions"
  value = {
    data_ingestion = try(aws_lambda_function.data_ingestion.function_name, null)
  }
}

# Resource summary
output "resource_summary" {
  description = "Summary of created resources"
  value = {
    vpc_created               = try(aws_vpc.main.id, null) != null
    load_balancer_created     = try(aws_lb.main.id, null) != null
    auto_scaling_group_created = try(aws_autoscaling_group.main.id, null) != null
    s3_buckets_count         = length([for bucket in [
      try(aws_s3_bucket.main.id, null),
      try(aws_s3_bucket.raw_data.id, null),
      try(aws_s3_bucket.processed_data.id, null),
      try(aws_s3_bucket.archive_data.id, null)
    ] : bucket if bucket != null])
    dynamodb_tables_count    = length([for table in [
      try(aws_dynamodb_table.main.name, null),
      try(aws_dynamodb_table.processing_metadata.name, null),
      try(aws_dynamodb_table.data_catalog.name, null)
    ] : table if table != null])
    generated_timestamp      = "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}
EOF
}