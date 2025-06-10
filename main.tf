# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "ec2-scheduler"
}

# Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.lambda_function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for Lambda to manage EC2 instances
resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.lambda_function_name}-policy"
  description = "Policy for EC2 scheduler Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:DescribeInstanceStatus"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  policy_arn = aws_iam_policy.lambda_policy.arn
  role       = aws_iam_role.lambda_role.name
}

# Create a ZIP file for the Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"
  source {
    content = file("${path.module}/lambda_function.py")
    filename = "lambda_function.py"
  }
}

# Lambda function
resource "aws_lambda_function" "ec2_scheduler" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.lambda_function_name
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 60
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_policy_attachment,
    aws_cloudwatch_log_group.lambda_logs,
  ]
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 14
}

# EventBridge rules for starting instances (Monday-Friday at 8:00 AM, Saturday at 10:00 AM)
resource "aws_cloudwatch_event_rule" "start_instances_weekday" {
  name        = "${var.lambda_function_name}-start-weekday"
  description = "Start EC2 instances on weekdays at 8:00 AM UTC"
  
  schedule_expression = "cron(0 8 ? * MON-FRI *)"
}

resource "aws_cloudwatch_event_rule" "start_instances_saturday" {
  name        = "${var.lambda_function_name}-start-saturday"
  description = "Start EC2 instances on Saturday at 10:00 AM UTC"
  
  schedule_expression = "cron(0 10 ? * SAT *)"
}

# EventBridge rules for stopping instances (Monday-Friday at 6:00 PM, Saturday at 4:00 PM)
resource "aws_cloudwatch_event_rule" "stop_instances_weekday" {
  name        = "${var.lambda_function_name}-stop-weekday"
  description = "Stop EC2 instances on weekdays at 6:00 PM UTC"
  
  schedule_expression = "cron(0 18 ? * MON-FRI *)"
}

resource "aws_cloudwatch_event_rule" "stop_instances_saturday" {
  name        = "${var.lambda_function_name}-stop-saturday"
  description = "Stop EC2 instances on Saturday at 4:00 PM UTC"
  
  schedule_expression = "cron(0 16 ? * SAT *)"
}

# EventBridge targets for starting instances
resource "aws_cloudwatch_event_target" "start_lambda_weekday" {
  rule      = aws_cloudwatch_event_rule.start_instances_weekday.name
  target_id = "StartInstancesWeekday"
  arn       = aws_lambda_function.ec2_scheduler.arn

  input = jsonencode({
    action = "start"
  })
}

resource "aws_cloudwatch_event_target" "start_lambda_saturday" {
  rule      = aws_cloudwatch_event_rule.start_instances_saturday.name
  target_id = "StartInstancesSaturday"
  arn       = aws_lambda_function.ec2_scheduler.arn

  input = jsonencode({
    action = "start"
  })
}

# EventBridge targets for stopping instances
resource "aws_cloudwatch_event_target" "stop_lambda_weekday" {
  rule      = aws_cloudwatch_event_rule.stop_instances_weekday.name
  target_id = "StopInstancesWeekday"
  arn       = aws_lambda_function.ec2_scheduler.arn

  input = jsonencode({
    action = "stop"
  })
}

resource "aws_cloudwatch_event_target" "stop_lambda_saturday" {
  rule      = aws_cloudwatch_event_rule.stop_instances_saturday.name
  target_id = "StopInstancesSaturday"
  arn       = aws_lambda_function.ec2_scheduler.arn

  input = jsonencode({
    action = "stop"
  })
}

# Lambda permissions for EventBridge
resource "aws_lambda_permission" "allow_eventbridge_start_weekday" {
  statement_id  = "AllowExecutionFromEventBridgeStartWeekday"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_instances_weekday.arn
}

resource "aws_lambda_permission" "allow_eventbridge_start_saturday" {
  statement_id  = "AllowExecutionFromEventBridgeStartSaturday"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_instances_saturday.arn
}

resource "aws_lambda_permission" "allow_eventbridge_stop_weekday" {
  statement_id  = "AllowExecutionFromEventBridgeStopWeekday"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_instances_weekday.arn
}

resource "aws_lambda_permission" "allow_eventbridge_stop_saturday" {
  statement_id  = "AllowExecutionFromEventBridgeStopSaturday"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_scheduler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_instances_saturday.arn
}

# Outputs
output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.ec2_scheduler.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.ec2_scheduler.arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group for Lambda function"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}
