import boto3
import json
from datetime import datetime, timedelta

class MonitoringObservabilityManager:
    def __init__(self, regions=['us-west-2', 'us-east-1']):
        """
        Initialize monitoring and observability management
        
        :param regions: List of AWS regions to configure
        """
        self.regions = regions
        self.clients = {
            'cloudwatch': {region: boto3.client('cloudwatch', region_name=region) for region in regions},
            'xray': {region: boto3.client('xray', region_name=region) for region in regions},
            'cloudtrail': {region: boto3.client('cloudtrail', region_name=region) for region in regions}
        }

    def configure_cloudwatch_metrics(self):
        """
        Configure CloudWatch metrics for microservices
        """
        metric_configurations = [
            {
                'namespace': 'MicroserviceMetrics',
                'metrics': [
                    {
                        'name': 'RequestLatency',
                        'unit': 'Milliseconds',
                        'statistic_values': {
                            'Minimum': 0,
                            'Maximum': 10000,
                            'Sum': 0,
                            'SampleCount': 0
                        }
                    },
                    {
                        'name': 'ErrorRate',
                        'unit': 'Percent',
                        'statistic_values': {
                            'Minimum': 0,
                            'Maximum': 100,
                            'Sum': 0,
                            'SampleCount': 0
                        }
                    }
                ]
            }
        ]

        created_metrics = []
        for region in self.regions:
            for metric_config in metric_configurations:
                try:
                    for metric in metric_config['metrics']:
                        self.clients['cloudwatch'][region].put_metric_data(
                            Namespace=metric_config['namespace'],
                            MetricData=[
                                {
                                    'MetricName': metric['name'],
                                    'Unit': metric['unit'],
                                    'StatisticValues': metric['statistic_values']
                                }
                            ]
                        )
                    
                    created_metrics.append({
                        'region': region,
                        'namespace': metric_config['namespace']
                    })
                
                except Exception as e:
                    print(f"Error configuring CloudWatch metrics in {region}: {e}")

        return created_metrics

    def configure_xray_tracing(self):
        """
        Configure X-Ray for distributed tracing
        """
        xray_configurations = [
            {
                'group_name': 'MicroserviceTraces',
                'filter_expression': 'service("microservice")',
                'insights_configuration': {
                    'InsightsEnabled': True,
                    'NotificationsEnabled': True
                }
            }
        ]

        created_trace_groups = []
        for region in self.regions:
            for xray_config in xray_configurations:
                try:
                    response = self.clients['xray'][region].create_group(
                        GroupName=xray_config['group_name'],
                        FilterExpression=xray_config['filter_expression'],
                        InsightsConfiguration=xray_config['insights_configuration']
                    )
                    
                    created_trace_groups.append({
                        'region': region,
                        'group_name': xray_config['group_name'],
                        'group_arn': response['Group']['GroupARN']
                    })
                
                except Exception as e:
                    print(f"Error configuring X-Ray tracing in {region}: {e}")

        return created_trace_groups

    def configure_cloudtrail_logging(self):
        """
        Configure CloudTrail for API logging
        """
        cloudtrail_configurations = [
            {
                'name': 'microservice-api-trail',
                's3_bucket_name': 'microservice-cloudtrail-logs',
                'include_global_service_events': True,
                'is_multi_region_trail': True
            }
        ]

        created_trails = []
        for region in self.regions:
            for trail_config in cloudtrail_configurations:
                try:
                    response = self.clients['cloudtrail'][region].create_trail(
                        Name=trail_config['name'],
                        S3BucketName=trail_config['s3_bucket_name'],
                        IncludeGlobalServiceEvents=trail_config['include_global_service_events'],
                        IsMultiRegionTrail=trail_config['is_multi_region_trail']
                    )
                    
                    # Enable logging
                    self.clients['cloudtrail'][region].start_logging(
                        Name=trail_config['name']
                    )
                    
                    created_trails.append({
                        'region': region,
                        'trail_name': trail_config['name'],
                        'trail_arn': response['TrailARN']
                    })
                
                except Exception as e:
                    print(f"Error configuring CloudTrail in {region}: {e}")

        return created_trails

    def generate_monitoring_report(self):
        """
        Generate comprehensive monitoring configuration report
        """
        monitoring_report = {
            'timestamp': datetime.now().isoformat(),
            'cloudwatch_metrics': self.configure_cloudwatch_metrics(),
            'xray_tracing': self.configure_xray_tracing(),
            'cloudtrail_logging': self.configure_cloudtrail_logging()
        }
        
        return monitoring_report

def main():
    monitoring_manager = MonitoringObservabilityManager()
    
    # Generate monitoring configuration
    monitoring_report = monitoring_manager.generate_monitoring_report()
    
    # Save monitoring report
    with open('monitoring_configuration_report.json', 'w') as f:
        json.dump(monitoring_report, f, indent=2)
    
    # Print summary
    print("Monitoring and Observability Configuration Complete")
    print(json.dumps(monitoring_report, indent=2))

if __name__ == '__main__':
    main()