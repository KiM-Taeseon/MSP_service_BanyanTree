## IAM Configuration for Lambda


# infrastructure/iam.tf
# IAM role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "terraform-provisioner-lambda-role"

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

# Policy for Lambda to access necessary resources
resource "aws_iam_policy" "lambda_terraform_policy" {
  name        = "terraform-provisioner-lambda-policy"
  description = "Policy for Lambda to provision resources using Terraform"

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
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.terraform_state.arn}",
          "${aws_s3_bucket.terraform_state.arn}/*",
          "${aws_s3_bucket.terraform_configs.arn}",
          "${aws_s3_bucket.terraform_configs.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "${aws_dynamodb_table.terraform_locks.arn}"
      },
      # This is a broad permission for demonstration
      # In production, you should limit to only needed permissions
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "s3:*",
          "rds:*",
          "dynamodb:*",
          "iam:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "lambda_terraform" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_terraform_policy.arn
}