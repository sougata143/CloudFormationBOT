import logging
import json
import socket
import traceback
from pythonjsonlogger import jsonlogger
import boto3

class AdvancedLogger:
    def __init__(self, service_name='microservice'):
        """
        Initialize advanced logging with JSON formatting and CloudWatch integration
        
        :param service_name: Name of the service for log identification
        """
        self.service_name = service_name
        self.logger = logging.getLogger(service_name)
        self.logger.setLevel(logging.INFO)
        
        # JSON formatter
        formatter = jsonlogger.JsonFormatter(
            '%(asctime)s %(levelname)s %(name)s %(message)s %(pathname)s %(lineno)d'
        )
        
        # Console handler
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(formatter)
        self.logger.addHandler(console_handler)
        
        # CloudWatch logging
        self.cloudwatch_client = boto3.client('logs')
        self.log_group = f'/microservices/{service_name}'
        self.log_stream = socket.gethostname()
        
        # Create log group and stream
        self._create_cloudwatch_resources()

    def _create_cloudwatch_resources(self):
        """
        Create CloudWatch log group and stream
        """
        try:
            # Create log group
            self.cloudwatch_client.create_log_group(
                logGroupName=self.log_group
            )
        except self.cloudwatch_client.exceptions.ResourceAlreadyExistsException:
            pass

        try:
            # Create log stream
            self.cloudwatch_client.create_log_stream(
                logGroupName=self.log_group,
                logStreamName=self.log_stream
            )
        except self.cloudwatch_client.exceptions.ResourceAlreadyExistsException:
            pass

    def log_to_cloudwatch(self, log_level, message, extra_data=None):
        """
        Send log to CloudWatch
        
        :param log_level: Logging level
        :param message: Log message
        :param extra_data: Additional context data
        """
        log_event = {
            'logLevel': log_level,
            'message': message,
            'serviceName': self.service_name,
            'hostname': socket.gethostname()
        }
        
        if extra_data:
            log_event.update(extra_data)
        
        try:
            self.cloudwatch_client.put_log_events(
                logGroupName=self.log_group,
                logStreamName=self.log_stream,
                logEvents=[
                    {
                        'timestamp': int(datetime.now().timestamp() * 1000),
                        'message': json.dumps(log_event)
                    }
                ]
            )
        except Exception as e:
            print(f"CloudWatch logging error: {e}")

    def info(self, message, extra_data=None):
        """Log info message"""
        self.logger.info(message)
        self.log_to_cloudwatch('INFO', message, extra_data)

    def error(self, message, exception=None, extra_data=None):
        """Log error message with optional exception details"""
        error_details = {
            'errorMessage': message,
            'stackTrace': traceback.format_exc() if exception else None
        }
        
        if extra_data:
            error_details.update(extra_data)
        
        self.logger.error(message, exc_info=exception)
        self.log_to_cloudwatch('ERROR', message, error_details)

def main():
    # Example usage
    logger = AdvancedLogger(service_name='user-authentication')
    
    try:
        # Simulated authentication process
        user_id = 'user123'
        logger.info('User login attempt', {'userId': user_id})
        
        # Simulated error
        raise ValueError("Authentication failed")
    
    except Exception as e:
        logger.error('Authentication error', exception=e, 
                     extra_data={'userId': user_id})

if __name__ == '__main__':
    main()