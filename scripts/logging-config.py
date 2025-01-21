import logging
import sys
import json
from pythonjsonlogger import jsonlogger

def setup_json_logging(log_level=logging.INFO):
    """
    Configure structured JSON logging
    """
    logger = logging.getLogger()
    logger.setLevel(log_level)

    # Remove default handlers
    logger.handlers.clear()

    # JSON log formatter
    json_handler = logging.StreamHandler(sys.stdout)
    formatter = jsonlogger.JsonFormatter(
        '%(asctime)s %(levelname)s %(name)s %(message)s %(exc_info)s',
        json_ensure_ascii=False
    )
    json_handler.setFormatter(formatter)
    logger.addHandler(json_handler)

    return logger

def log_deployment_event(logger, event_type, details):
    """
    Log structured deployment events
    """
    log_data = {
        'event_type': event_type,
        'details': details
    }
    logger.info(json.dumps(log_data))

def main():
    # Setup logging
    logger = setup_json_logging()

    # Example deployment logging
    deployment_details = {
        'service': 'backend-microservice',
        'version': '1.2.3',
        'environment': 'production'
    }
    log_deployment_event(logger, 'deployment_started', deployment_details)

if __name__ == '__main__':
    main()