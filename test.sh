#!/bin/bash

# Test script for EC2 Scheduler Lambda Function

set -e

echo "🧪 EC2 Scheduler Test Script"
echo "============================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

LAMBDA_FUNCTION_NAME=${1:-"ec2-scheduler"}

echo -e "${BLUE}Testing Lambda function: ${LAMBDA_FUNCTION_NAME}${NC}"
echo ""

# Function to test Lambda invocation
test_lambda() {
    local action=$1
    local test_name=$2
    
    echo -e "${YELLOW}Testing: ${test_name}${NC}"
    
    # Create test payload
    echo "{\"action\": \"${action}\"}" > test_payload.json
    
    # Invoke Lambda function
    if aws lambda invoke \
        --function-name "${LAMBDA_FUNCTION_NAME}" \
        --payload file://test_payload.json \
        --cli-binary-format raw-in-base64-out \
        response.json > invoke_result.json 2>&1; then
        
        echo -e "${GREEN}✅ Lambda invocation successful${NC}"
        
        # Show response
        echo "Response:"
        cat response.json | python3 -m json.tool 2>/dev/null || cat response.json
        echo ""
        
        # Show invocation result
        echo "Invocation details:"
        cat invoke_result.json
        echo ""
        
    else
        echo -e "${RED}❌ Lambda invocation failed${NC}"
        cat invoke_result.json
        echo ""
    fi
    
    # Cleanup
    rm -f test_payload.json response.json invoke_result.json
}

# Check if Lambda function exists
echo "🔍 Checking if Lambda function exists..."
if aws lambda get-function --function-name "${LAMBDA_FUNCTION_NAME}" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Lambda function '${LAMBDA_FUNCTION_NAME}' found${NC}"
else
    echo -e "${RED}❌ Lambda function '${LAMBDA_FUNCTION_NAME}' not found${NC}"
    echo "Please deploy the function first using: ./deploy.sh"
    exit 1
fi

echo ""

# Test start action
test_lambda "start" "Start instances action"

# Test stop action  
test_lambda "stop" "Stop instances action"

# Test invalid action
echo -e "${YELLOW}Testing: Invalid action (should fail gracefully)${NC}"
echo '{"action": "invalid"}' > test_payload.json

if aws lambda invoke \
    --function-name "${LAMBDA_FUNCTION_NAME}" \
    --payload file://test_payload.json \
    --cli-binary-format raw-in-base64-out \
    response.json > invoke_result.json 2>&1; then
    
    echo -e "${YELLOW}⚠️  Lambda invocation completed (checking for error handling)${NC}"
    echo "Response:"
    cat response.json | python3 -m json.tool 2>/dev/null || cat response.json
    echo ""
else
    echo -e "${RED}❌ Lambda invocation failed${NC}"
    cat invoke_result.json
fi

rm -f test_payload.json response.json invoke_result.json

echo ""
echo -e "${BLUE}📊 Additional Checks${NC}"
echo "==================="

# Check CloudWatch Log Group
echo "🔍 Checking CloudWatch Log Group..."
if aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/${LAMBDA_FUNCTION_NAME}" --query 'logGroups[0].logGroupName' --output text 2>/dev/null | grep -q "${LAMBDA_FUNCTION_NAME}"; then
    echo -e "${GREEN}✅ CloudWatch Log Group exists${NC}"
    
    echo ""
    echo "📋 Recent log events (last 10 minutes):"
    aws logs filter-log-events \
        --log-group-name "/aws/lambda/${LAMBDA_FUNCTION_NAME}" \
        --start-time $(($(date +%s - 600) * 1000)) \
        --query 'events[*].[timestamp,message]' \
        --output table 2>/dev/null || echo "No recent log events found"
else
    echo -e "${YELLOW}⚠️  CloudWatch Log Group not found or no recent activity${NC}"
fi

echo ""

# Check EventBridge rules
echo "🔍 Checking EventBridge rules..."
RULES=$(aws events list-rules --name-prefix "${LAMBDA_FUNCTION_NAME}" --query 'Rules[*].Name' --output text 2>/dev/null || echo "")

if [ -n "$RULES" ]; then
    echo -e "${GREEN}✅ EventBridge rules found:${NC}"
    for rule in $RULES; do
        echo "  - $rule"
        
        # Get rule details
        aws events describe-rule --name "$rule" --query '[ScheduleExpression,State]' --output text 2>/dev/null | while read schedule state; do
            echo "    Schedule: $schedule, State: $state"
        done
    done
else
    echo -e "${YELLOW}⚠️  No EventBridge rules found${NC}"
fi

echo ""
echo -e "${BLUE}💡 Tips:${NC}"
echo "======="
echo "1. To view real-time logs:"
echo "   aws logs tail /aws/lambda/${LAMBDA_FUNCTION_NAME} --follow"
echo ""
echo "2. To check which EC2 instances would be affected:"
echo "   aws ec2 describe-instances --filters 'Name=tag:AutoSchedule,Values=true' --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key==\`Name\`].Value|[0]]' --output table"
echo ""
echo "3. To manually trigger the scheduled events:"
echo "   aws events put-events --entries 'Source=test,DetailType=Manual Test,Detail={}'"
echo ""

echo -e "${GREEN}🎉 Testing completed!${NC}"
