# EC2 Scheduler Lambda Function

This project provides an automated EC2 instance scheduler that starts and stops instances based on a configurable weekly timetable. It's designed to help reduce AWS costs by automatically shutting down instances during off-hours.

## Features

- **Automated scheduling**: Start/stop EC2 instances at configured times
- **Flexible configuration**: Tag-based or instance ID-based targeting
- **Weekly schedule**: Different schedules for each day of the week
- **CloudWatch integration**: Automatic logging and monitoring
- **Cost optimization**: Reduces AWS costs by stopping instances during off-hours

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

## Quick Start

### 1. Tag Your Instances

Tag the EC2 instances you want to manage:

```bash
aws ec2 create-tags --resources i-your-instance-id --tags Key=AutoSchedule,Value=true
```

### 2. Deploy the Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Deploy
terraform apply
```

### 3. Verify Deployment

Check the created resources:

```bash
# View Lambda function
aws lambda get-function --function-name ec2-scheduler

# View CloudWatch Event rules
aws events list-rules --name-prefix ec2-scheduler
```

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

Test the Lambda function manually:

```bash
# Test starting instances
aws lambda invoke \
  --function-name ec2-scheduler \
  --payload '{"action": "start"}' \
  response.json

# Test stopping instances  
aws lambda invoke \
  --function-name ec2-scheduler \
  --payload '{"action": "stop"}' \
  response.json
```

### Monitor Logs

View Lambda execution logs:

```bash
aws logs tail /aws/lambda/ec2-scheduler --follow
```

## Timezone Considerations

- All times in the configuration are in UTC
- To use local time, adjust the cron expressions in Terraform
- Consider daylight saving time changes in your region

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

2. **Schedule not triggering**:
   - Verify CloudWatch Event rules are enabled
   - Check timezone settings (all times are UTC)
   - Review Lambda permissions for EventBridge

3. **Permission errors**:
   - Ensure IAM role has required EC2 permissions
   - Check if instances are in the same region as Lambda

## Cleanup

To remove all resources:

```bash
terraform destroy
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License.
