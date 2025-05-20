## Terraform Configuration for Creating the Lambda Infrastructure


# infrastructure/main.tf
provider "aws" {
  region = var.aws_region
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name
  
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 bucket for Terraform configurations
resource "aws_s3_bucket" "terraform_configs" {
  bucket = var.config_bucket_name
  
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_configs" {
  bucket = aws_s3_bucket.terraform_configs.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# ECR repository for Lambda container image
resource "aws_ecr_repository" "lambda_repo" {
  name                 = "terraform-provisioner-lambda"
  image_tag_mutability = "MUTABLE"
}

# Lambda function
resource "aws_lambda_function" "terraform_provisioner" {
  function_name = "terraform-provisioner"
  role          = aws_iam_role.lambda_exec.arn
  timeout       = 900  # 15 minutes (maximum)
  memory_size   = 1024
  
  # For container image
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.lambda_repo.repository_url}:latest"
  
  environment {
    variables = {
      STATE_BUCKET     = aws_s3_bucket.terraform_state.bucket
      STATE_KEY        = "terraform.tfstate"
      LOCK_TABLE       = aws_dynamodb_table.terraform_locks.name
      TF_CONFIG_BUCKET = aws_s3_bucket.terraform_configs.bucket
      TF_CONFIG_KEY    = "terraform_config.zip"
    }
  }
}

# API Gateway to trigger Lambda
resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "terraform-provisioner-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda_stage" {
  api_id      = aws_apigatewayv2_api.lambda_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.lambda_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.terraform_provisioner.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.lambda_api.id
  route_key = "POST /provision"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.terraform_provisioner.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*"
}