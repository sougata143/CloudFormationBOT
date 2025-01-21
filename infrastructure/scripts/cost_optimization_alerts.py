import boto3
import os
import logging
from datetime import datetime, timedelta

class CostOptimizationMonitor:
    def __init__(self, region='us-west-2'):
        """
        Initialize Cost Optimization Monitor
        
        :param region: AWS region
        """
        self.ce_client = boto3.client('ce', region_name=region)
        self.sns_client = boto3.client('sns', region_name=region)
        self.logger = self._setup_logger()
    
    def _setup_logger(self):
        """
        Setup logging for cost optimization
        """
        logger = logging.getLogger('CostOptimizationMonitor')
        logger.setLevel(logging.INFO)
        
        # Create logs directory
        os.makedirs('logs', exist_ok=True)
        
        # File handler
        file_handler = logging.FileHandler(f'logs/cost_optimization_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log')
        file_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s: %(message)s'))
        logger.addHandler(file_handler)
        
        return logger
    
    def get_daily_cost(self):
        """
        Retrieve daily cost
        
        :return: Total daily cost
        """
        end = datetime.now()
        start = end - timedelta(days=1)
        
        response = self.ce_client.get_cost_and_usage(
            TimePeriod={
                'Start': start.strftime('%Y-%m-%d'),
                'End': end.strftime('%Y-%m-%d')
            },
            Granularity='DAILY',
            Metrics=['UnblendedCost']
        )
        
        total_cost = sum(
            float(result['Total']['UnblendedCost']['Amount'])
            for result in response['ResultsByTime']
        )
        
        return total_cost
    
    def send_cost_alert(self, cost, threshold=100):
        """
        Send cost alert if threshold is exceeded
        
        :param cost: Total daily cost
        :param threshold: Cost threshold in USD
        """
        if cost > threshold:
            message = f"Daily cost alert: ${cost:.2f} exceeds threshold of ${threshold}"
            
            # Send SNS notification
            self.sns_client.publish(
                TopicArn=os.environ.get('COST_ALERT_SNS_TOPIC'),
                Message=message,
                Subject='AWS Cost Optimization Alert'
            )
            
            self.logger.warning(message)
    
    def analyze_cost_by_service(self):
        """
        Analyze cost by AWS service
        """
        end = datetime.now()
        start = end - timedelta(days=30)
        
        response = self.ce_client.get_cost_and_usage(
            TimePeriod={
                'Start': start.strftime('%Y-%m-%d'),
                'End': end.strftime('%Y-%m-%d')
            },
            Granularity='MONTHLY',
            Metrics=['UnblendedCost'],
            GroupBy=[
                {'Type': 'DIMENSION', 'Key': 'SERVICE'}
            ]
        )
        
        service_costs = {
            group['Keys'][0]: float(group['Metrics']['UnblendedCost']['Amount'])
            for group in response['ResultsByTime'][0]['Groups']
        }
        
        return service_costs

def main():
    # Initialize monitor
    monitor = CostOptimizationMonitor()
    
    # Get daily cost
    daily_cost = monitor.get_daily_cost()
    
    # Send alert if cost exceeds threshold
    monitor.send_cost_alert(daily_cost, threshold=100)
    
    # Analyze service costs
    service_costs = monitor.analyze_cost_by_service()
    print("Monthly Service Costs:", service_costs)

if __name__ == '__main__':
    main()