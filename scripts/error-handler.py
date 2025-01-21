import logging
import sys
import traceback
import json
import boto3

class ErrorHandler:
    def __init__(self, log_level=logging.INFO):
        self.logger = logging.getLogger('ErrorHandler')
        self.logger.setLevel(log_level)
        
        # Configure logging handler
        handler = logging.StreamHandler(sys.stdout)
        formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        handler.setFormatter(formatter)
        self.logger.addHandler(handler)
        
        # SNS client for notifications
        self.sns_client = boto3.client('sns')

    def handle_exception(self, exception, context=None):
        """
        Comprehensive exception handling with logging and notification
        
        :param exception: Exception object
        :param context: Additional context information
        """
        # Log full traceback
        error_details = {
            'type': type(exception).__name__,
            'message': str(exception),
            'traceback': traceback.format_exc(),
            'context': context or {}
        }
        
        # Log error
        self.logger.error(json.dumps(error_details, indent=2))
        
        # Send SNS notification
        self._send_error_notification(error_details)
        
        # Optional: Take recovery actions based on error type
        self._handle_recovery(exception)

    def _send_error_notification(self, error_details):
        """
        Send error notification via SNS
        """
        try:
            self.sns_client.publish(
                TopicArn='arn:aws:sns:us-west-2:123456789012:ErrorNotificationTopic',
                Message=json.dumps(error_details, indent=2),
                Subject='Microservice Deployment Error'
            )
        except Exception as e:
            self.logger.error(f"Failed to send SNS notification: {e}")

    def _handle_recovery(self, exception):
        """
        Implement recovery strategies based on exception type
        """
        if isinstance(exception, ConnectionError):
            # Retry mechanism
            self.logger.info("Attempting connection retry...")
        elif isinstance(exception, PermissionError):
            # Escalate or notify admin
            self.logger.warning("Permission error. Admin intervention required.")
        # Add more specific recovery strategies

def global_exception_handler(error_handler):
    """
    Decorator for global exception handling
    """
    def decorator(func):
        def wrapper(*args, **kwargs):
            try:
                return func(*args, **kwargs)
            except Exception as e:
                error_handler.handle_exception(e, context={
                    'function': func.__name__,
                    'args': args,
                    'kwargs': kwargs
                })
        return wrapper
    return decorator

def main():
    # Example usage
    error_handler = ErrorHandler()

    @global_exception_handler(error_handler)
    def risky_deployment_function():
        # Simulated deployment function with potential errors
        raise ConnectionError("Failed to connect to deployment service")

    risky_deployment_function()

if __name__ == '__main__':
    main()