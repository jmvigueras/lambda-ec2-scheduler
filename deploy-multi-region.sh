#!/bin/bash

# Multi-region deployment script
# Deploy EC2 scheduler to multiple AWS regions

set -e

echo "🌍 Multi-Region EC2 Scheduler Deployment"
echo "========================================"

# Define regions to deploy to
REGIONS=("eu-west-1" "eu-south-2")

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

for region in "${REGIONS[@]}"; do
    echo ""
    echo -e "${YELLOW}🚀 Deploying to region: ${region}${NC}"
    echo "================================"
    
    # Create region-specific directory
    REGION_DIR="deployment-${region}"
    mkdir -p "${REGION_DIR}"
    
    # Copy files to region directory
    cp lambda_function.py main.tf "${REGION_DIR}/"
    
    # Create region-specific terraform.tfvars
    cat > "${REGION_DIR}/terraform.tfvars" << EOL
aws_region = "${region}"
lambda_function_name = "ec2-scheduler-${region}"
EOL
    
    # Deploy to this region
    cd "${REGION_DIR}"
    terraform init
    terraform apply -auto-approve
    
    echo -e "${GREEN}✅ Deployment to ${region} completed${NC}"
    cd ..
done

echo ""
echo -e "${GREEN}🎉 All regions deployed successfully!${NC}"
echo ""
echo "To manage instances in each region, tag them with 'AutoSchedule=true'"
