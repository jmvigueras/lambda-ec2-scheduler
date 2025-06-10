#!/bin/bash

# EC2 Scheduler Deployment Script
# This script helps deploy the EC2 scheduler Lambda function

set -e

echo "🚀 EC2 Scheduler Deployment Script"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ Terraform is not installed. Please install it first.${NC}"
    exit 1
fi

# Check AWS credentials
echo "🔐 Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured. Please run 'aws configure' first.${NC}"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region || echo "us-east-1")
echo -e "${GREEN}✅ AWS credentials valid. Account: ${ACCOUNT_ID}, Region: ${REGION}${NC}"

# Function to prompt for confirmation
confirm() {
    read -p "$1 (y/N): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Display current configuration
echo ""
echo "📋 Current Configuration:"
echo "========================"
echo "AWS Region: ${REGION}"
echo "Lambda Function: ec2-scheduler"
echo "Schedule: Mon-Fri 8:00-18:00, Sat 10:00-16:00 (UTC)"
echo ""

# Ask if user wants to continue
if ! confirm "Do you want to proceed with deployment?"; then
    echo -e "${YELLOW}⏸️  Deployment cancelled.${NC}"
    exit 0
fi

# Check if terraform.tfvars exists, if not create from example
if [ ! -f "terraform.tfvars" ]; then
    echo "📝 Creating terraform.tfvars from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo -e "${YELLOW}⚠️  Please review and customize terraform.tfvars if needed.${NC}"
fi

# Initialize Terraform
echo ""
echo "🔧 Initializing Terraform..."
terraform init

# Validate Terraform configuration
echo "✅ Validating Terraform configuration..."
terraform validate

# Show Terraform plan
echo ""
echo "📊 Terraform Plan:"
echo "=================="
terraform plan

echo ""
if ! confirm "Do you want to apply these changes?"; then
    echo -e "${YELLOW}⏸️  Deployment cancelled.${NC}"
    exit 0
fi

# Apply Terraform configuration
echo ""
echo "🚀 Deploying infrastructure..."
terraform apply -auto-approve

# Get outputs
LAMBDA_NAME=$(terraform output -raw lambda_function_name 2>/dev/null || echo "ec2-scheduler")
LAMBDA_ARN=$(terraform output -raw lambda_function_arn 2>/dev/null || echo "N/A")

echo ""
echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo "=================================="
echo "Lambda Function: ${LAMBDA_NAME}"
echo "Lambda ARN: ${LAMBDA_ARN}"
echo ""

echo "📚 Next Steps:"
echo "============="
echo "1. Tag your EC2 instances with 'AutoSchedule=true'"
echo "   aws ec2 create-tags --resources i-instanceid --tags Key=AutoSchedule,Value=true"
echo ""
echo "2. Test the function manually:"
echo "   aws lambda invoke --function-name ${LAMBDA_NAME} --payload '{\"action\": \"start\"}' response.json"
echo ""
echo "3. Monitor logs:"
echo "   aws logs tail /aws/lambda/${LAMBDA_NAME} --follow"
echo ""
echo "4. View CloudWatch Event rules:"
echo "   aws events list-rules --name-prefix ${LAMBDA_NAME}"
echo ""

echo -e "${GREEN}✅ Setup complete! Your EC2 instances will now be automatically scheduled.${NC}"
