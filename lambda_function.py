import json
import boto3
from datetime import datetime, timezone
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize EC2 client
ec2 = boto3.client('ec2')

# Weekly schedule configuration
# Format: 'day': {'start': 'HH:MM', 'stop': 'HH:MM'}
# Days: monday, tuesday, wednesday, thursday, friday, saturday, sunday
WEEKLY_SCHEDULE = {
    'monday': {'start': '08:00', 'stop': '18:00'},
    'tuesday': {'start': '08:00', 'stop': '18:00'},
    'wednesday': {'start': '08:00', 'stop': '18:00'},
    'thursday': {'start': '08:00', 'stop': '18:00'},
    'friday': {'start': '08:00', 'stop': '18:00'},
    'saturday': {'start': '10:00', 'stop': '16:00'},
    'sunday': None  # No operations on Sunday
}

# Instance configuration
INSTANCE_CONFIG = {
    # Tag-based filtering - instances with these tags will be managed
    'tags': {
        'AutoSchedule': 'true',
        # 'Environment': 'dev'  # Optional: additional tag filtering
    },
    
    # Or specify instance IDs directly (comment out tags above if using this)
    # 'instance_ids': ['i-1234567890abcdef0', 'i-0987654321fedcba0']
}

def lambda_handler(event, context):
    """
    Main Lambda handler function
    
    Event should contain:
    - action: 'start' or 'stop'
    - timezone: optional timezone (default: UTC)
    """
    
    try:
        # Get action from event
        action = event.get('action')
        if not action:
            action = determine_action_from_schedule()
        
        if not action:
            logger.info("No action needed based on current schedule")
            return {
                'statusCode': 200,
                'body': json.dumps('No action needed')
            }
        
        # Get instances to manage
        instances = get_managed_instances()
        
        if not instances:
            logger.info("No instances found matching the criteria")
            return {
                'statusCode': 200,
                'body': json.dumps('No instances found')
            }
        
        # Perform the action
        if action == 'start':
            result = start_instances(instances)
        elif action == 'stop':
            result = stop_instances(instances)
        else:
            raise ValueError(f"Invalid action: {action}")
        
        logger.info(f"Action '{action}' completed successfully for {len(instances)} instances")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'action': action,
                'instances_affected': len(instances),
                'instance_ids': instances,
                'result': result
            })
        }
        
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }

def determine_action_from_schedule():
    """
    Determine what action to take based on current time and weekly schedule
    """
    now = datetime.now(timezone.utc)
    current_day = now.strftime('%A').lower()
    current_time = now.strftime('%H:%M')
    
    logger.info(f"Current day: {current_day}, Current time: {current_time}")
    
    if current_day not in WEEKLY_SCHEDULE or WEEKLY_SCHEDULE[current_day] is None:
        return None
    
    day_schedule = WEEKLY_SCHEDULE[current_day]
    start_time = day_schedule.get('start')
    stop_time = day_schedule.get('stop')
    
    # This is a simplified logic - in practice, you'd trigger this function
    # at specific times via CloudWatch Events
    if current_time == start_time:
        return 'start'
    elif current_time == stop_time:
        return 'stop'
    
    return None

def get_managed_instances():
    """
    Get list of instances to manage based on configuration
    """
    instances = []
    
    try:
        if 'instance_ids' in INSTANCE_CONFIG:
            # Use specific instance IDs
            instances = INSTANCE_CONFIG['instance_ids']
            logger.info(f"Using configured instance IDs: {instances}")
            
        elif 'tags' in INSTANCE_CONFIG:
            # Filter by tags
            filters = []
            for key, value in INSTANCE_CONFIG['tags'].items():
                filters.append({
                    'Name': f'tag:{key}',
                    'Values': [value]
                })
            
            # Add filter to exclude terminated instances
            filters.append({
                'Name': 'instance-state-name',
                'Values': ['running', 'stopped', 'stopping', 'pending']
            })
            
            response = ec2.describe_instances(Filters=filters)
            
            for reservation in response['Reservations']:
                for instance in reservation['Instances']:
                    instances.append(instance['InstanceId'])
            
            logger.info(f"Found {len(instances)} instances matching tag criteria")
        
        return instances
        
    except Exception as e:
        logger.error(f"Error getting managed instances: {str(e)}")
        raise

def start_instances(instance_ids):
    """
    Start the specified instances
    """
    try:
        if not instance_ids:
            return "No instances to start"
        
        # Check current state first
        response = ec2.describe_instances(InstanceIds=instance_ids)
        instances_to_start = []
        
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                state = instance['State']['Name']
                instance_id = instance['InstanceId']
                
                if state == 'stopped':
                    instances_to_start.append(instance_id)
                    logger.info(f"Instance {instance_id} is stopped, will start")
                else:
                    logger.info(f"Instance {instance_id} is in state '{state}', skipping")
        
        if instances_to_start:
            result = ec2.start_instances(InstanceIds=instances_to_start)
            logger.info(f"Started instances: {instances_to_start}")
            return result
        else:
            return "No instances needed to be started"
            
    except Exception as e:
        logger.error(f"Error starting instances: {str(e)}")
        raise

def stop_instances(instance_ids):
    """
    Stop the specified instances
    """
    try:
        if not instance_ids:
            return "No instances to stop"
        
        # Check current state first
        response = ec2.describe_instances(InstanceIds=instance_ids)
        instances_to_stop = []
        
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                state = instance['State']['Name']
                instance_id = instance['InstanceId']
                
                if state == 'running':
                    instances_to_stop.append(instance_id)
                    logger.info(f"Instance {instance_id} is running, will stop")
                else:
                    logger.info(f"Instance {instance_id} is in state '{state}', skipping")
        
        if instances_to_stop:
            result = ec2.stop_instances(InstanceIds=instances_to_stop)
            logger.info(f"Stopped instances: {instances_to_stop}")
            return result
        else:
            return "No instances needed to be stopped"
            
    except Exception as e:
        logger.error(f"Error stopping instances: {str(e)}")
        raise
