## Lambda Function (Python)

# lambda/function.py
import os
import subprocess
import json
import boto3
import logging
import tempfile
import shutil
from pathlib import Path

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# S3 client for accessing Terraform files
s3 = boto3.client('s3')

# Configuration
TERRAFORM_VERSION = "1.6.6"
STATE_BUCKET = os.environ.get('STATE_BUCKET')
STATE_KEY = os.environ.get('STATE_KEY')
LOCK_TABLE = os.environ.get('LOCK_TABLE')
TF_CONFIG_BUCKET = os.environ.get('TF_CONFIG_BUCKET')
TF_CONFIG_KEY = os.environ.get('TF_CONFIG_KEY')

def download_terraform_binary():
    """Download Terraform binary and make it executable"""
    tf_url = f"https://releases.hashicorp.com/terraform/{TERRAFORM_VERSION}/terraform_{TERRAFORM_VERSION}_linux_amd64.zip"
    
    # Download and extract Terraform
    subprocess.run(['curl', '-o', '/tmp/terraform.zip', tf_url], check=True)
    subprocess.run(['unzip', '-o', '/tmp/terraform.zip', '-d', '/tmp'], check=True)
    subprocess.run(['chmod', '+x', '/tmp/terraform'])
    
    return '/tmp/terraform'

def download_terraform_config(bucket, key, target_dir):
    """Download Terraform configuration from S3"""
    # Download and extract the Terraform config archive
    download_path = f"/tmp/terraform_config.zip"
    s3.download_file(bucket, key, download_path)
    
    # Extract the archive
    subprocess.run(['unzip', '-o', download_path, '-d', target_dir], check=True)
    logger.info(f"Downloaded and extracted Terraform config to {target_dir}")

def run_terraform(tf_path, working_dir, command, variables=None):
    """Run Terraform command in the specified directory"""
    # Change to the working directory
    os.chdir(working_dir)
    
    # Prepare backend config
    backend_config = [
        f'-backend-config=bucket={STATE_BUCKET}',
        f'-backend-config=key={STATE_KEY}',
        f'-backend-config=region={os.environ.get("AWS_REGION", "us-east-1")}',
        f'-backend-config=dynamodb_table={LOCK_TABLE}'
    ]
    
    # Initialize Terraform
    init_cmd = [tf_path, 'init'] + backend_config
    logger.info(f"Initializing Terraform: {' '.join(init_cmd)}")
    result = subprocess.run(init_cmd, capture_output=True, text=True)
    logger.info(f"Terraform init stdout: {result.stdout}")
    if result.returncode != 0:
        logger.error(f"Terraform init failed: {result.stderr}")
        raise Exception("Terraform initialization failed")
    
    # Prepare var arguments if provided
    var_args = []
    if variables:
        for key, value in variables.items():
            var_args.extend(['-var', f'{key}={value}'])
    
    # Run the requested Terraform command
    tf_cmd = [tf_path, command] + var_args
    if command == 'apply' or command == 'destroy':
        tf_cmd.append('-auto-approve')
    
    logger.info(f"Running Terraform command: {' '.join(tf_cmd)}")
    result = subprocess.run(tf_cmd, capture_output=True, text=True)
    
    logger.info(f"Terraform {command} stdout: {result.stdout}")
    if result.returncode != 0:
        logger.error(f"Terraform {command} failed: {result.stderr}")
        raise Exception(f"Terraform {command} failed")
    
    return result.stdout

def lambda_handler(event, context):
    """Lambda handler function"""
    try:
        # Extract parameters from the event
        command = event.get('command', 'apply')  # Default to 'apply'
        variables = event.get('variables', {})
        
        # Create a temporary directory for Terraform operations
        with tempfile.TemporaryDirectory() as temp_dir:
            # Download Terraform binary
            tf_path = download_terraform_binary()
            
            # Download Terraform configuration
            download_terraform_config(TF_CONFIG_BUCKET, TF_CONFIG_KEY, temp_dir)
            
            # Run Terraform
            output = run_terraform(tf_path, temp_dir, command, variables)
            
            # Parse outputs if requested
            outputs = {}
            if command == 'apply' or command == 'output':
                try:
                    output_result = subprocess.run(
                        [tf_path, 'output', '-json'],
                        capture_output=True, text=True, check=True
                    )
                    outputs = json.loads(output_result.stdout)
                except Exception as e:
                    logger.warning(f"Failed to parse Terraform outputs: {str(e)}")
            
            return {
                'statusCode': 200,
                'body': {
                    'message': f"Terraform {command} executed successfully",
                    'output': output,
                    'outputs': outputs
                }
            }
            
    except Exception as e:
        logger.error(f"Error executing Terraform: {str(e)}")
        return {
            'statusCode': 500,
            'body': {
                'message': f"Error executing Terraform: {str(e)}"
            }
        }