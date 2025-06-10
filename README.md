# EC2 Scheduler Lambda Function

This project provides an automated EC2 instance scheduler that starts and stops instances based on a configurable weekly timetable. It's designed to help reduce AWS costs by automatically shutting down instances during off-hours.

## Features

- **Automated scheduling**: Start/stop EC2 instances at configured times
- **Flexible configuration**: Tag-based or instance ID-based targeting
- **Weekly schedule**: Different schedules for each day of the week
- **CloudWatch integration**: Automatic logging and monitoring
- **Cost optimization**: Reduces AWS costs by stopping instances during off-hours
- **Multi-region support**: Deploy to any AWS region or multiple regions

## Default Schedule

The current configuration includes:
- **Monday-Friday**: Start at 8:00 AM, Stop at 6:00 PM (UTC)
- **Saturday**: Start at 10:00 AM, Stop at 4:00 PM (UTC) 
- **Sunday**: No operations (instances remain in their current state)

## Architecture

```
CloudWatch Events (EventBridge) → Lambda Function → EC2 API
                                      ↓
                                CloudWatch Logs
```

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform installed (version 1.0+)
3. Appropriate AWS permissions for:
   - Lambda functions
   - EC2 instances
   - IAM roles and policies
   - CloudWatch Events/EventBridge
   - CloudWatch Logs

## Region Configuration

**Important**: The Lambda function operates within a **single AWS region** and can only manage EC2 instances in that same region. AWS services are region-specific, so cross-region management requires separate deployments.

### Default Region
- **Default**: `us-east-1`
- **Configurable**: Can be changed via Terraform variables
- **Scope**: Lambda manages only EC2 instances in the specified region

## Quick Start

### 1. Choose Your Region

The Lambda function will be deployed to and manage instances in a single AWS region. Choose your target region:

**Option A: Use default region (us-east-1)**
```bash
# No additional configuration needed
```

**Option B: Specify a different region**
```bash
# Create terraform.tfvars file
echo 'aws_region = "eu-west-1"' > terraform.tfvars

# Or copy from example and edit
cp terraform.tfvars.example terraform.tfvars
# Edit the file to set your preferred region
```

**Option C: Use command line**
```bash
terraform apply -var="aws_region=eu-west-1"
```

### 2. Tag Your Instances

Tag the EC2 instances you want to manage **in the target region**:

```bash
aws ec2 create-tags --resources i-your-instance-id --tags Key=AutoSchedule,Value=true --region your-target-region
```

### 3. Deploy the Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Deploy
terraform apply
```

### 4. Verify Deployment

Check the created resources:

```bash
# View Lambda function
aws lambda get-function --function-name ec2-scheduler

# View CloudWatch Event rules
aws events list-rules --name-prefix ec2-scheduler
```

## Multi-Region Deployment

If you need to manage EC2 instances across multiple AWS regions, you'll need to deploy separate Lambda functions in each region.

### Option 1: Manual Multi-Region Deployment

Deploy to each region separately:

```bash
# Deploy to us-east-1
echo 'aws_region = "us-east-1"' > terraform.tfvars
terraform apply

# Deploy to eu-west-1 (in a separate directory)
mkdir eu-west-1-deployment
cd eu-west-1-deployment
cp ../lambda_function.py ../main.tf .
echo 'aws_region = "eu-west-1"' > terraform.tfvars
echo 'lambda_function_name = "ec2-scheduler-eu-west-1"' >> terraform.tfvars
terraform init && terraform apply

# Repeat for additional regions
```

### Option 2: Automated Multi-Region Deployment

Use the provided multi-region deployment script:

```bash
# Edit regions in the script
./deploy-multi-region.sh
```

This will deploy the scheduler to multiple regions automatically with region-specific naming.

### Multi-Region Considerations

- **Separate Lambda functions**: Each region requires its own Lambda deployment
- **Region-specific tagging**: Tag instances in each region separately
- **Independent schedules**: Each region can have different schedules if needed
- **Cost implications**: Multiple Lambda functions incur separate costs
- **Management complexity**: Monitor and maintain each deployment independently

## Region-Specific Configuration

### Region Selection

The AWS region is controlled by the `aws_region` variable in `main.tf`:

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"  # Change this default if needed
}
```

You can override this in several ways:

1. **terraform.tfvars file**:
   ```hcl
   aws_region = "eu-west-1"
   lambda_function_name = "ec2-scheduler-eu"
   ```

2. **Environment variable**:
   ```bash
   export TF_VAR_aws_region="ap-southeast-1"
   terraform apply
   ```

3. **Command line**:
   ```bash
   terraform apply -var="aws_region=us-west-2"
   ```

### Available Regions

The scheduler can be deployed to any AWS region that supports:
- AWS Lambda
- Amazon EC2
- Amazon CloudWatch Events/EventBridge
- Amazon CloudWatch Logs

Popular regions include:
- `us-east-1` (N. Virginia)
- `us-west-2` (Oregon)
- `eu-west-1` (Ireland)
- `eu-central-1` (Frankfurt)
- `ap-southeast-1` (Singapore)
- `ap-northeast-1` (Tokyo)

## Configuration

### Instance Selection

You can configure which instances to manage in two ways:

#### Option A: Tag-based Selection (Recommended)

Edit `INSTANCE_CONFIG` in `lambda_function.py`:

```python
INSTANCE_CONFIG = {
    'tags': {
        'AutoSchedule': 'true',
        'Environment': 'development'  # Optional additional filtering
    }
}
```

#### Option B: Specific Instance IDs

```python
INSTANCE_CONFIG = {
    'instance_ids': ['i-1234567890abcdef0', 'i-0987654321fedcba0']
}
```

### Schedule Configuration

Modify the `WEEKLY_SCHEDULE` in `lambda_function.py`:

```python
WEEKLY_SCHEDULE = {
    'monday': {'start': '09:00', 'stop': '17:00'},    # 9 AM - 5 PM
    'tuesday': {'start': '09:00', 'stop': '17:00'},
    'wednesday': {'start': '09:00', 'stop': '17:00'},
    'thursday': {'start': '09:00', 'stop': '17:00'},
    'friday': {'start': '09:00', 'stop': '17:00'},
    'saturday': None,  # No operations on Saturday
    'sunday': None     # No operations on Sunday
}
```

**Note**: All times are in 24-hour format and UTC timezone.

### CloudWatch Events Schedule

If you modify the Lambda schedule, update the corresponding Terraform cron expressions:

```hcl
# Example: Change to 9:00 AM start time
resource "aws_cloudwatch_event_rule" "start_instances_weekday" {
  schedule_expression = "cron(0 9 ? * MON-FRI *)"
}
```

## Testing

### Manual Testing

Test the Lambda function manually in your target region:

```bash
# Test starting instances
aws lambda invoke \
  --function-name ec2-scheduler \
  --payload '{"action": "start"}' \
  --region your-target-region \
  response.json

# Test stopping instances  
aws lambda invoke \
  --function-name ec2-scheduler \
  --payload '{"action": "stop"}' \
  --region your-target-region \
  response.json
```

### Monitor Logs

View Lambda execution logs:
```bash
aws logs tail /aws/lambda/ec2-scheduler --follow --region your-target-region
```

### Verify Regional Deployment

Check which region your Lambda is deployed in:
```bash
aws lambda get-function --function-name ec2-scheduler --region your-target-region
```

List instances that will be managed:
```bash
aws ec2 describe-instances \
  --filters 'Name=tag:AutoSchedule,Values=true' \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Placement.AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' \
  --output table \
  --region your-target-region
```

## Timezone Considerations

- All times in the configuration are in UTC
- The Lambda function operates in UTC regardless of the AWS region
- To use local time, adjust the cron expressions in Terraform
- Consider daylight saving time changes in your region
- **Region timezone does not affect schedule** - all schedules run on UTC

Example timezone adjustments:
```bash
# For EST (UTC-5), start at 8 AM EST = 1 PM UTC
schedule_expression = "cron(0 13 ? * MON-FRI *)"

# For CET (UTC+1), start at 8 AM CET = 7 AM UTC  
schedule_expression = "cron(0 7 ? * MON-FRI *)"
```

## Security

- IAM policy follows the principle of least privilege
- Only grants necessary EC2 permissions
- Uses tag-based filtering to limit scope
- All actions are logged to CloudWatch

## Cost Optimization

This scheduler can significantly reduce your AWS costs by:
- Automatically stopping instances during off-hours
- Preventing instances from running when not needed
- Providing detailed logs for cost analysis

## Troubleshooting

### Common Issues

1. **Instances not starting/stopping**:
   - Check CloudWatch logs for error messages
   - Verify instance tags match the configuration
   - Ensure Lambda has necessary EC2 permissions
   - **Confirm instances are in the same region as Lambda**

2. **Schedule not triggering**:
   - Verify CloudWatch Event rules are enabled
   - Check timezone settings (all times are UTC)
   - Review Lambda permissions for EventBridge
   - **Ensure EventBridge rules are in the correct region**

3. **Permission errors**:
   - Ensure IAM role has required EC2 permissions
   - **Check if instances are in the same region as Lambda**
   - Verify AWS CLI is configured for the correct region

4. **Cross-region issues**:
   - Lambda cannot manage instances in different regions
   - Deploy separate Lambda functions for each region
   - Ensure AWS CLI commands specify the correct region

### Viewing Resources

List created resources in specific region:
```bash
# View Lambda function
aws lambda get-function --function-name ec2-scheduler --region your-region

# View CloudWatch Event rules
aws events list-rules --name-prefix ec2-scheduler --region your-region

# View IAM role (IAM is global, but check from any region)
aws iam get-role --role-name ec2-scheduler-role

# List managed instances in the region
aws ec2 describe-instances \
  --filters 'Name=tag:AutoSchedule,Values=true' \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,Placement.AvailabilityZone]' \
  --output table \
  --region your-region
```

## Cleanup

To remove all resources from a specific region:
```bash
# Make sure you're in the correct directory and region
terraform destroy

# For multi-region deployments, clean up each region separately
cd deployment-us-east-1 && terraform destroy
cd ../deployment-eu-west-1 && terraform destroy
```

**Note**: Terraform state is region-specific, so you must run `terraform destroy` from the same directory and with the same region configuration used for deployment.

## Security Best Practices

1. **Principle of least privilege**: The IAM policy only grants necessary EC2 permissions
2. **Resource tagging**: Use tags to limit which instances can be managed
3. **Logging**: All actions are logged to CloudWatch for audit purposes
4. **Region isolation**: Lambda only affects instances in the same AWS region

## Customization Options

### Advanced Scheduling

For more complex schedules, you can:
- Add multiple CloudWatch Event rules for different time periods
- Implement holiday calendars in the Lambda function
- Add support for different schedules per environment tag

### Notifications

Add SNS notifications for start/stop actions:
```python
import boto3
sns = boto3.client('sns')

# In your Lambda function
sns.publish(
    TopicArn='arn:aws:sns:region:account:topic-name',
    Message=f'EC2 Scheduler: {action} completed for {len(instances)} instances'
)
```

### Multi-Region Support

Deploy the same infrastructure in multiple regions by running Terraform with different provider configurations.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License.
