## Sample Terraform Configuration to be Applied by Lambda


# terraform/main.tf
provider "aws" {
  region = var.aws_region
}

terraform {
  backend "s3" {
    # This will be configured by the Lambda function
  }
}

# Sample EC2 instance
resource "aws_instance" "example" {
  ami           = var.ami_id
  instance_type = var.instance_type
  
  tags = {
    Name        = var.instance_name
    Environment = var.environment
    ManagedBy   = "Lambda-Terraform"
  }
}