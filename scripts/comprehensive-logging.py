import logging
import json
import sys
import traceback
from pythonjsonlogger import jsonlogger
import boto3
from botocore.exceptions import ClientError

class ComprehensiveLogger:
    def __init__(self, log_level=logging.INFO, service_name='microservice'):
        """
        Initialize a comprehensive logging system
        
        :param log_level: Logging level
        :param service_name: Name of the service being logged
        """
        self.service_name = service_name
        self.logger = logging.getLogger(service_name)
        self.logger.setLevel(log_level)
        
        # Clear existing handlers
        self.logger.handlers.clear()
        
        # JSON formatter for structured logging
        json_handler = logging.StreamHandler(sys.stdout)
        formatter = jsonlogger.JsonFormatter(
            '%(asctime)s %(levelname)s %(name)s %(message)s %(exc_info)s',
            json_ensure_ascii=False
        )
        json_handler.setFormatter(formatter)
        self.logger.addHandler(json_handler)
        
        # CloudWatch Logs client
        self.cloudwatch_logs = boto3.client('logs')
        
        # Log group and stream names
        self.log_group = f'/aws/microservice/{service_name}'
        self.log_stream = f'{service_name}-log-stream'
        
        # Create log group and stream
        self._create_log_group_and_stream()

    def _create_log_group_and_stream(self):
        """
        Create CloudWatch log group and stream
        """
        try:
            # Create log group
            self.cloudwatch_logs.create_log_group(
                logGroupName=self.log_group
            )
            
            # Create log stream
            self.cloudwatch_logs.create_log_stream(
                logGroupName=self.log_group,
                logStreamName=self.log_stream
            )
        except self.cloudwatch_logs.exceptions.ResourceAlreadyExistsException:
            pass

    def log_event(self, message, level='info', extra_context=None):
        """
        Log an event with optional extra context
        
        :param message: Log message
        :param level: Logging level
        :param extra_context: Additional context dictionary
        """
        log_data = {
            'service': self.service_name,
            'message': message
        }
        
        if extra_context:
            log_data.update(extra_context)
        
        # Log to console
        log_method = getattr(self.logger, level.lower(), self.logger.info)
        log_method(json.dumps(log_data))
        
        # Log to CloudWatch
        self._send_to_cloudwatch(log_data, level)

    def _send_to_cloudwatch(self, log_data, level):
        """
        Send log event to CloudWatch
        
        :param log_data: Log data dictionary
        :param level: Log level
        """
        try:
            self.cloudwatch_logs.put_log_events(
                logGroupName=self.log_group,
                logStreamName=self.log_stream,
                logEvents=[
                    {
                        'timestamp': int(datetime.now().timestamp() * 1000),
                        'message': json.dumps(log_data)
                    }
                ]
            )
        except ClientError as e:
            print(f"CloudWatch logging error: {e}")

    def log_exception(self, exception, context=None):
        """
        Log detailed exception information
        
        :param exception: Exception object
        :param context: Additional context information
        """
        error_details = {
            'type': type(exception).__name__,
            'message': str(exception),
            'traceback': traceback.format_exc(),
            'context': context or {}
        }
        
        self.log_event(
            message=f"Exception: {error_details['type']}",
            level='error',
            extra_context=error_details
        )

def main():
    # Example usage
    logger = ComprehensiveLogger(service_name='deployment-service')
    
    try:
        # Simulated deployment process
        logger.log_event("Starting deployment", extra_context={'version': '1.2.3'})
        
        # Simulate an error
        raise ValueError("Deployment configuration error")
    
    except Exception as e:
        logger.log_exception(e, context={'deployment_id': 'DEPLOY-2025-01-20'})

if __name__ == '__main__':
    main()