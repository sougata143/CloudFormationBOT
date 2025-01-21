import boto3
import json
from datetime import datetime, timedelta

class AdvancedAlertingSystem:
    def __init__(self, regions=['us-west-2', 'us-east-1']):
        """
        Initialize advanced alerting system
        
        :param regions: List of AWS regions to monitor
        """
        self.regions = regions
        self.cloudwatch = {region: boto3.client('cloudwatch', region_name=region) for region in regions}
        self.sns = {region: boto3.client('sns', region_name=region) for region in regions}

    def create_composite_alarms(self):
        """
        Create composite alarms combining multiple metrics
        """
        for region in self.regions:
            try:
                # CPU and Memory Utilization Composite Alarm
                self.cloudwatch[region].put_composite_alarm(
                    AlarmName=f'{region}-resource-utilization-alarm',
                    AlarmRule=(
                        "ALARM(ecs-cpu-high) OR ALARM(ecs-memory-high) OR "
                        "ALARM(rds-cpu-high) OR ALARM(elb-target-errors)"
                    ),
                    AlarmDescription='Composite alarm for resource utilization and performance',
                    AlarmActions=[
                        f'arn:aws:sns:{region}:123456789012:high-severity-alerts'
                    ]
                )
            except Exception as e:
                print(f"Error creating composite alarm in {region}: {e}")

    def setup_anomaly_detection_alarms(self):
        """
        Set up machine learning-powered anomaly detection alarms
        """
        for region in self.regions:
            try:
                # Request count anomaly detection
                self.cloudwatch[region].put_anomaly_detector(
                    MetricMathAnomalyDetector={
                        'MetricDataQueries': [
                            {
                                'Id': 'request_count',
                                'MetricStat': {
                                    'Metric': {
                                        'Namespace': 'AWS/ApplicationELB',
                                        'MetricName': 'RequestCount',
                                        'Dimensions': [
                                            {
                                                'Name': 'LoadBalancer',
                                                'Value': 'microservice-alb'
                                            }
                                        ]
                                    },
                                    'Period': 300,
                                    'Stat': 'Sum'
                                }
                            }
                        ]
                    }
                )

                # Create anomaly alarm
                self.cloudwatch[region].put_metric_alarm(
                    AlarmName=f'{region}-request-anomaly-alarm',
                    ComparisonOperator='GreaterThanUpperThreshold',
                    EvaluationPeriods=2,
                    MetricName='RequestCount',
                    Namespace='AWS/ApplicationELB',
                    Period=300,
                    Statistic='Sum',
                    Threshold=1.5,  # 1.5 standard deviations
                    TreatMissingData='notBreaching',
                    AlarmActions=[
                        f'arn:aws:sns:{region}:123456789012:anomaly-alerts'
                    ]
                )
            except Exception as e:
                print(f"Error setting up anomaly detection in {region}: {e}")

    def create_notification_channels(self):
        """
        Create multiple notification channels
        """
        for region in self.regions:
            try:
                # High severity SNS topic
                high_severity_topic = self.sns[region].create_topic(
                    Name=f'{region}-high-severity-alerts'
                )

                # Anomaly detection SNS topic
                anomaly_topic = self.sns[region].create_topic(
                    Name=f'{region}-anomaly-alerts'
                )

                # Subscribe email endpoints
                self.sns[region].subscribe(
                    TopicArn=high_severity_topic['TopicArn'],
                    Protocol='email',
                    Endpoint='admin@company.com'
                )

                self.sns[region].subscribe(
                    TopicArn=anomaly_topic['TopicArn'],
                    Protocol='email',
                    Endpoint='devops@company.com'
                )

            except Exception as e:
                print(f"Error creating notification channels in {region}: {e}")

def main():
    alerting_system = AdvancedAlertingSystem()
    
    # Setup advanced alerting mechanisms
    alerting_system.create_composite_alarms()
    alerting_system.setup_anomaly_detection_alarms()
    alerting_system.create_notification_channels()

if __name__ == '__main__':
    main()