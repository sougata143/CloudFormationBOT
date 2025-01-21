import boto3
import json
from datetime import datetime, timedelta

class AdvancedMonitoringDashboard:
    def __init__(self, regions=['us-west-2', 'us-east-1']):
        self.regions = regions
        self.cloudwatch = {region: boto3.client('cloudwatch', region_name=region) for region in regions}
        self.dashboard_client = boto3.client('cloudwatch', region_name=regions[0])

    def create_comprehensive_dashboard(self, dashboard_name):
        """
        Create a comprehensive multi-region monitoring dashboard
        """
        dashboard_body = {
            "widgets": [
                # ECS Cluster Metrics
                {
                    "type": "metric",
                    "properties": {
                        "metrics": [
                            ["AWS/ECS", "CPUUtilization", "ClusterName", "MicroserviceCluster"],
                            [".", "MemoryUtilization", ".", "."]
                        ],
                        "view": "timeSeries",
                        "stacked": False,
                        "region": self.regions[0],
                        "title": "ECS Cluster Performance"
                    }
                },
                # RDS Database Metrics
                {
                    "type": "metric",
                    "properties": {
                        "metrics": [
                            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "MicroserviceDatabase"],
                            [".", "DatabaseConnections", ".", "."]
                        ],
                        "view": "timeSeries",
                        "stacked": False,
                        "region": self.regions[0],
                        "title": "Database Performance"
                    }
                },
                # Application Load Balancer Metrics
                {
                    "type": "metric",
                    "properties": {
                        "metrics": [
                            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "MicroserviceALB"],
                            [".", "TargetResponseTime", ".", "."]
                        ],
                        "view": "timeSeries",
                        "stacked": False,
                        "region": self.regions[0],
                        "title": "Load Balancer Metrics"
                    }
                }
            ]
        }

        try:
            self.dashboard_client.put_dashboard(
                DashboardName=dashboard_name,
                DashboardBody=json.dumps(dashboard_body)
            )
            print(f"Dashboard {dashboard_name} created successfully")
        except Exception as e:
            print(f"Error creating dashboard: {e}")

    def generate_performance_report(self, hours=24):
        """
        Generate comprehensive performance report
        """
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(hours=hours)

        report = {
            'timestamp': end_time.isoformat(),
            'regions': {}
        }

        for region in self.regions:
            region_metrics = self._collect_region_metrics(region, start_time, end_time)
            report['regions'][region] = region_metrics

        return report

    def _collect_region_metrics(self, region, start_time, end_time):
        """
        Collect metrics for a specific region
        """
        cloudwatch = self.cloudwatch[region]
        metrics = {
            'ecs': self._get_metric_statistics(cloudwatch, 'AWS/ECS', 'CPUUtilization', start_time, end_time),
            'rds': self._get_metric_statistics(cloudwatch, 'AWS/RDS', 'DatabaseConnections', start_time, end_time),
            'elb': self._get_metric_statistics(cloudwatch, 'AWS/ApplicationELB', 'RequestCount', start_time, end_time)
        }
        return metrics

    def _get_metric_statistics(self, client, namespace, metric_name, start_time, end_time):
        """
        Retrieve metric statistics
        """
        try:
            response = client.get_metric_statistics(
                Namespace=namespace,
                MetricName=metric_name,
                Dimensions=[],
                StartTime=start_time,
                EndTime=end_time,
                Period=3600,
                Statistics=['Average', 'Maximum', 'Minimum']
            )
            return response['Datapoints']
        except Exception as e:
            print(f"Error retrieving {metric_name} metrics: {e}")
            return []

def main():
    monitoring_dashboard = AdvancedMonitoringDashboard()
    
    # Create dashboard
    monitoring_dashboard.create_comprehensive_dashboard('MicroservicePerformanceDashboard')
    
    # Generate performance report
    performance_report = monitoring_dashboard.generate_performance_report()
    
    # Save report
    with open('performance_report.json', 'w') as f:
        json.dump(performance_report, f, indent=2)

if __name__ == '__main__':
    main()