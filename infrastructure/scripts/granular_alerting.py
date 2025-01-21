import boto3
import os
import yaml
from datetime import datetime, timedelta

class GranularAlertManager:
    def __init__(self, config_path: str = None):
        """
        Initialize Granular Alert Manager
        
        :param config_path: Path to monitoring configuration
        """
        # Load configuration
        if config_path is None:
            config_path = os.path.join(
                os.path.dirname(__file__), 
                '../config/monitoring_config.yaml'
            )
        
        with open(config_path, 'r') as config_file:
            self.config = yaml.safe_load(config_file)
        
        # AWS Clients
        self.cloudwatch = boto3.client('cloudwatch')
        self.notifier = MultiChannelNotifier()
    
    def check_s3_bucket_size(self, bucket_name: str):
        """
        Check S3 bucket size and generate alerts
        
        :param bucket_name: Name of S3 bucket to monitor
        """
        s3_size_config = self.config['alert_rules']['s3_bucket_size']
        
        response = self.cloudwatch.get_metric_statistics(
            Namespace='AWS/S3',
            MetricName='BucketSizeBytes',
            Dimensions=[{'Name': 'BucketName', 'Value': bucket_name}],
            StartTime=datetime.now() - timedelta(hours=24),
            EndTime=datetime.now(),
            Period=86400,
            Statistics=['Maximum']
        )
        
        bucket_size_gb = response['Datapoints'][0]['Maximum'] / (1024 ** 3)
        
        if bucket_size_gb > s3_size_config['critical_threshold_gb']:
            self.notifier.send_slack_notification(
                'replication_alerts', 
                f'CRITICAL: S3 Bucket {bucket_name} size exceeded {s3_size_config["critical_threshold_gb"]} GB'
            )
            self.notifier.send_pagerduty_alert(
                f'S3 Bucket {bucket_name} Size Critical', 
                severity='critical'
            )
        elif bucket_size_gb > s3_size_config['warning_threshold_gb']:
            self.notifier.send_slack_notification(
                'replication_alerts', 
                f'WARNING: S3 Bucket {bucket_name} size approaching limit: {bucket_size_gb:.2f} GB'
            )
    
    def analyze_replication_latency(self, source_bucket: str, destination_bucket: str):
        """
        Analyze S3 replication latency
        
        :param source_bucket: Source S3 bucket
        :param destination_bucket: Destination S3 bucket
        """
        latency_config = self.config['alert_rules']['replication_latency']
        
        response = self.cloudwatch.get_metric_statistics(
            Namespace='AWS/S3',
            MetricName='ReplicationLatency',
            Dimensions=[
                {'Name': 'SourceBucket', 'Value': source_bucket},
                {'Name': 'DestinationBucket', 'Value': destination_bucket}
            ],
            StartTime=datetime.now() - timedelta(hours=1),
            EndTime=datetime.now(),
            Period=3600,
            Statistics=['Maximum']
        )
        
        max_latency = response['Datapoints'][0]['Maximum'] if response['Datapoints'] else 0
        
        if max_latency > latency_config['critical_threshold_seconds']:
            self.notifier.send_slack_notification(
                'replication_alerts', 
                f'CRITICAL: Replication latency exceeded {latency_config["critical_threshold_seconds"]} seconds'
            )
            self.notifier.send_pagerduty_alert(
                'S3 Replication Latency Critical', 
                severity='critical'
            )
        elif max_latency > latency_config['warning_threshold_seconds']:
            self.notifier.send_slack_notification(
                'replication_alerts', 
                f'WARNING: Replication latency high: {max_latency} seconds'
            )

def main():
    # Initialize granular alert manager
    alert_manager = GranularAlertManager()
    
    # Check S3 bucket sizes
    alert_manager.check_s3_bucket_size('microservice-storage')
    
    # Analyze replication latency
    alert_manager.analyze_replication_latency(
        'microservice-source-bucket', 
        'microservice-destination-bucket'
    )

if __name__ == '__main__':
    main()