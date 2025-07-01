#!/bin/bash

# Simple CloudFormation deployment script
STACK_NAME="ec2-scheduler-stack"
TEMPLATE_FILE="ec2-scheduler-cloudformation.yaml"
PARAMETERS_FILE="parameters.json"
REGION="${1:-eu-west-1}"

echo "Deploying EC2 Scheduler CloudFormation Stack"
echo "Stack: $STACK_NAME"
echo "Region: $REGION"
echo "Template: $TEMPLATE_FILE"
echo ""

# Check if stack exists
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" &> /dev/null; then
    echo "Stack exists. Updating..."
    aws cloudformation update-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://"$TEMPLATE_FILE" \
        --parameters file://"$PARAMETERS_FILE" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$REGION"
else
    echo "Creating new stack..."
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://"$TEMPLATE_FILE" \
        --parameters file://"$PARAMETERS_FILE" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$REGION"
fi

echo ""
echo "To monitor progress:"
echo "aws cloudformation describe-stack-events --stack-name $STACK_NAME --region $REGION"
echo ""
echo "To delete:"
echo "aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION"
