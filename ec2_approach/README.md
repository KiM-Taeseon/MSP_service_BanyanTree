### README.md


## Complete Project Structure

With all files organized correctly, your final project structure should look like this:

```
ec2-terraform-provisioner/
├── deploy.sh                   # Main deployment script
├── upload-project.sh           # Script to upload Terraform projects
├── run-example.sh              # Script to run the example project
├── clean-up.sh                 # Script to clean up resources
│
├── infrastructure/             # IaC to set up the EC2 instance
│   ├── main.tf                 # Main EC2 and networking configuration
│   ├── storage.tf              # S3 buckets and DynamoDB table
│   ├── security.tf             # Security groups and IAM roles
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values
│   └── user_data.sh            # EC2 user data script
│
├── terraform-runner/           # Script files for the EC2 instance
│   ├── run-terraform.sh        # Main script to execute Terraform commands
│   ├── webhook-server.py       # Web server to accept Terraform commands
│   └── systemd/                # Systemd service files
│       └── terraform-webhook.service  # Service definition
│
└── terraform-projects/         # Example Terraform projects
    └── example-project/        # A sample infrastructure project
        ├── main.tf             # Main Terraform configuration
        ├── variables.tf        # Input variables
        └── outputs.tf          # Output values
```

This structure organizes the project into logical components, making it easier to understand and maintain. The deployment scripts handle the initial setup, while the runner scripts on the EC2 instance manage the Terraform operations.

# EC2 Terraform Provisioner

A solution for running Terraform operations on an EC2 instance via a webhook.

## Features

- Dedicated EC2 instance for Terraform operations
- Webhook API for triggering Terraform commands
- S3 storage for Terraform state and project files
- DynamoDB for state locking
- Proper IAM permissions for secure operations

## Project Structure

```
ec2-terraform-provisioner/
├── infrastructure/             # IaC to set up the EC2 instance and related resources
│   ├── main.tf                 # Main EC2 and networking configuration
│   ├── storage.tf              # S3 buckets and DynamoDB table
│   ├── security.tf             # Security groups and IAM roles
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values
│   └── user_data.sh            # EC2 user data script
├── terraform-runner/           # Script files to be deployed to EC2
│   ├── run-terraform.sh        # Main script to execute Terraform commands
│   ├── webhook-server.py       # Simple web server to accept Terraform commands
│   └── systemd/                # Systemd service files
│       └── terraform-webhook.service  # Service definition
├── terraform-projects/         # Example Terraform projects to be deployed
│   └── example-project/        # A sample infrastructure project
│       ├── main.tf             # Main Terraform configuration
│       ├── variables.tf        # Input variables
│       └── outputs.tf          # Output values
└── deploy.sh                   # Deployment script
```

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform CLI (for initial setup)
- SSH key pair in AWS

## How It Works

1. **Deployment**: The infrastructure is set up using Terraform, including an EC2 instance, S3 buckets, and a DynamoDB table.

2. **Initialization**: When the EC2 instance launches, it runs the `user_data.sh` script that:
   - Installs Terraform and required tools
   - Sets up the webhook server and Terraform runner script
   - Configures a systemd service to run the webhook

3. **Project Deployment**: Terraform projects are packaged as ZIP files and uploaded to the S3 bucket.

4. **Execution**: The webhook server accepts HTTP requests to run Terraform commands, which are executed by the runner script.

## Setup Instructions

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/ec2-terraform-provisioner.git
   cd ec2-terraform-provisioner
   ```

2. Deploy the infrastructure:
   ```
   ./deploy.sh
   ```

3. Upload a Terraform project:
   ```
   ./upload-project.sh path/to/your/terraform/project your-project-name
   ```

4. Trigger Terraform operations via the webhook:
   ```
   curl -X POST http://<EC2_IP>:8080/run-terraform \
        -H "Content-Type: application/json" \
        -d '{
              "project_name": "your-project-name",
              "command": "apply",
              "variables": {
                "key1": "value1",
                "key2": "value2"
              }
            }'
   ```

## Security Considerations

- Restrict SSH and webhook access using security groups
- Use private subnets with NAT gateway for production
- Limit IAM permissions to only what is necessary
- Consider adding authentication to the webhook
- Set up CloudWatch alarms for monitoring

## Benefits over Lambda Approach

- No 15-minute execution time limit
- Larger disk space for operations
- More memory available
- Persistent filesystem for caching
- Simpler implementation (no container required)
- Can run longer-running Terraform operations
- Easier to debug (SSH access available)

## Customization

### Scaling Considerations

For production workloads with multiple users or high usage:
- Consider using an Auto Scaling Group with multiple instances
- Add a load balancer in front of the instances
- Implement proper authentication for the webhook
- Set up monitoring and alerting

### Adding Authentication

The current implementation has no authentication. To add basic authentication:
1. Modify the webhook server to check for authorization headers
2. Store credentials in AWS Secrets Manager or as environment variables
3. Update the security group to use HTTPS instead of HTTP

## Troubleshooting

- SSH into the EC2 instance to check logs:
  ```
  ssh -i your-key.pem ec2-user@<EC2_IP>
  ```

- View webhook logs:
  ```
  sudo journalctl -u terraform-webhook
  ```

- Check Terraform execution logs:
  ```
  ls -la /home/terraform/logs/
  ```

## License

MIT