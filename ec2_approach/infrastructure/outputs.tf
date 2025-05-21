### infrastructure/outputs.tf
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.terraform_runner.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.terraform_eip.public_ip
}

output "webhook_endpoint" {
  description = "Endpoint URL for the Terraform webhook"
  value       = "http://${aws_eip.terraform_eip.public_ip}:8080/run-terraform"
}

output "state_bucket" {
  description = "S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "config_bucket" {
  description = "S3 bucket for Terraform configurations"
  value       = aws_s3_bucket.terraform_configs.bucket
}