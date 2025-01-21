import boto3
import time
from botocore.exceptions import ClientError

class AdvancedMonitoring:
    def __init__(self, region='us-west-2'):
        self.cloudwatch = boto3.client('cloudwatch', region_name=region)
        self.sns = boto3.client('sns', region_name=region)

    def create_custom_metric(self, namespace, metric_name, value, dimensions):
        """
        Create and publish custom CloudWatch metrics
        """
        try:
            self.cloudwatch.put_metric_data(
                Namespace=namespace,
                MetricData=[
                    {
                        'MetricName': metric_name,
                        'Dimensions': dimensions,
                        'Value': value,
                        'Unit': 'Count'
                    }
                ]
            )
        except ClientError as e:
            print(f"Error publishing metric: {e}")

    def create_deployment_alarm(self, alarm_name, metric_name, threshold, comparison_operator):
        """
        Create CloudWatch alarm for deployment metrics
        """
        try:
            self.cloudwatch.put_metric_alarm(
                AlarmName=alarm_name,
                ComparisonOperator=comparison_operator,
                EvaluationPeriods=2,
                MetricName=metric_name,
                Namespace='MicroserviceDeployment',
                Period=300,
                Statistic='Average',
                Threshold=threshold,
                AlarmActions=[
                    f'arn:aws:sns:us-west-2:123456789012:DeploymentAlerts'
                ],
                OKActions=[
                    f'arn:aws:sns:us-west-2:123456789012:DeploymentAlerts'
                ]
            )
        except ClientError as e:
            print(f"Error creating alarm: {e}")

    def track_deployment_performance(self, deployment_id):
        """
        Track and log deployment performance metrics
        """
        start_time = time.time()
        metrics = {
            'deployment_duration': 0,
            'services_deployed': 0,
            'errors_encountered': 0
        }

        try:
            # Simulate deployment tracking
            metrics['services_deployed'] = 3
            metrics['deployment_duration'] = time.time() - start_time

            # Publish metrics to CloudWatch
            for metric_name, value in metrics.items():
                self.create_custom_metric(
                    'MicroserviceDeployment',
                    metric_name,
                    value,
                    [{'Name': 'DeploymentID', 'Value': deployment_id}]
                )

            return metrics

        except Exception as e:
            metrics['errors_encountered'] += 1
            print(f"Deployment tracking error: {e}")
            return metrics

def main():
    monitoring = AdvancedMonitoring()
    
    # Create deployment performance alarm
    monitoring.create_deployment_alarm(
        'DeploymentDurationAlarm',
        'deployment_duration',
        threshold=600,  # 10 minutes
        comparison_operator='GreaterThanThreshold'
    )

    # Track a sample deployment
    deployment_metrics = monitoring.track_deployment_performance('DEPLOY-2025-01-20')
    print("Deployment Metrics:", deployment_metrics)

if __name__ == '__main__':
    main()