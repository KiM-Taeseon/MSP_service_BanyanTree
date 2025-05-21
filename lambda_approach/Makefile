## Makefile for Building and Deploying


# Makefile
.PHONY: build-lambda deploy-lambda package-terraform upload-terraform invoke-lambda clean

# Variables
ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text)
REGION := us-east-1
ECR_REPOSITORY := terraform-provisioner-lambda
IMAGE_TAG := latest
CONFIG_BUCKET := terraform-configs-$(ACCOUNT_ID)

# Build Lambda container image
build-lambda:
	@echo "Building Lambda container image..."
	cd lambda && docker build -t $(ECR_REPOSITORY):$(IMAGE_TAG) .

# Login to ECR and push the image
push-lambda:
	@echo "Pushing Lambda container image to ECR..."
	aws ecr get-login-password --region $(REGION) | docker login --username AWS --password-stdin $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com
	docker tag $(ECR_REPOSITORY):$(IMAGE_TAG) $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/$(ECR_REPOSITORY):$(IMAGE_TAG)
	docker push $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/$(ECR_REPOSITORY):$(IMAGE_TAG)

# Package Terraform configuration
package-terraform:
	@echo "Packaging Terraform configuration..."
	cd terraform && zip -r ../terraform_config.zip .

# Upload Terraform configuration to S3
upload-terraform: package-terraform
	@echo "Uploading Terraform configuration to S3..."
	aws s3 cp terraform_config.zip s3://$(CONFIG_BUCKET)/terraform_config.zip

# Deploy Lambda infrastructure with Terraform
deploy-infrastructure:
	@echo "Deploying Lambda infrastructure with Terraform..."
	cd infrastructure && terraform init && terraform apply -auto-approve \
		-var="state_bucket_name=terraform-state-$(ACCOUNT_ID)" \
		-var="config_bucket_name=$(CONFIG_BUCKET)"

# Invoke Lambda function via API Gateway
invoke-lambda:
	@echo "Invoking Lambda function via API Gateway..."
	ENDPOINT=$$(cd infrastructure && terraform output -raw api_endpoint) && \
	curl -X POST $$ENDPOINT/provision \
		-H "Content-Type: application/json" \
		-d '{"command": "apply", "variables": {"instance_name": "custom-instance", "environment": "test"}}'

# Clean up
clean:
	@echo "Cleaning up..."
	rm -f terraform_config.zip