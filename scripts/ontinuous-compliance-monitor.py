import boto3
import json
from datetime import datetime, timedelta

class ContinuousComplianceMonitor:
    def __init__(self, regions=['us-west-2', 'us-east-1']):
        """
        Initialize continuous compliance monitoring
        
        :param regions: List of AWS regions to monitor
        """
        self.regions = regions
        self.config_client = {region: boto3.client('config', region_name=region) for region in regions}
        self.securityhub_client = {region: boto3.client('securityhub', region_name=region) for region in regions}

    def enable_config_rules(self):
        """
        Enable and configure AWS Config rules
        """
        managed_config_rules = [
            'INCOMING_SSH_DISABLED',
            'INSTANCES_IN_VPC',
            'EIP_ATTACHED',
            'ENCRYPTED_VOLUMES',
            'RDS_INSTANCE_PUBLIC_ACCESS_CHECK'
        ]

        for region in self.regions:
            try:
                for rule_name in managed_config_rules:
                    self.config_client[region].put_config_rule(
                        ConfigRule={
                            'ConfigRuleName': f'{rule_name}-rule',
                            'Source': {
                                'Owner': 'AWS',
                                'SourceIdentifier': rule_name
                            },
                            'Scope': {
                                'ComplianceResourceTypes': [
                                    'AWS::EC2::Instance',
                                    'AWS::RDS::DBInstance',
                                    'AWS::EC2::Volume'
                                ]
                            },
                            'InputParameters': json.dumps({})
                        }
                    )
            except Exception as e:
                print(f"Error enabling Config rules in {region}: {e}")

    def enable_security_hub(self):
        """
        Enable and configure AWS Security Hub
        """
        for region in self.regions:
            try:
                # Enable Security Hub
                self.securityhub_client[region].enable_security_hub(
                    EnableDefaultStandards=True
                )

                # Enable standard security standards
                self.securityhub_client[region].batch_enable_standards(
                    StandardsSubscriptionRequests=[
                        {
                            'StandardsArn': 'arn:aws:securityhub:{}::standards/aws-foundational-security-best-practices/v/1.0.0'.format(region)
                        },
                        {
                            'StandardsArn': 'arn:aws:securityhub:{}::standards/cis-aws-foundations-benchmark/v/1.2.0'.format(region)
                        }
                    ]
                )
            except Exception as e:
                print(f"Error enabling Security Hub in {region}: {e}")

    def generate_compliance_insights(self):
        """
        Generate compliance insights and recommendations
        """
        insights = {}
        
        for region in self.regions:
            try:
                # Get Config rule compliance
                config_compliance = self.config_client[region].describe_compliance_by_config_rule()
                
                # Get Security Hub findings
                security_findings = self.securityhub_client[region].get_findings()
                
                insights[region] = {
                    'config_compliance': {
                        rule['ConfigRuleName']: rule['Compliance']['ComplianceType']
                        for rule in config_compliance.get('EvaluationResults', [])
                    },
                    'security_findings': {
                        'total_findings': len(security_findings['Findings']),
                        'high_severity_findings': len([
                            finding for finding in security_findings['Findings']
                            if finding['Severity']['Label'] in ['HIGH', 'CRITICAL']
                        ])
                    }
                }
            
            except Exception as e:
                insights[region] = {'error': str(e)}
        
        return insights

def main():
    compliance_monitor = ContinuousComplianceMonitor()
    
    # Enable compliance monitoring tools
    compliance_monitor.enable_config_rules()
    compliance_monitor.enable_security_hub()
    
    # Generate compliance insights
    compliance_insights = compliance_monitor.generate_compliance_insights()
    
    # Save insights
    with open('continuous_compliance_insights.json', 'w') as f:
        json.dump(compliance_insights, f, indent=2)
    
    # Print summary
    print("Continuous Compliance Insights Generated")
    print(json.dumps(compliance_insights, indent=2))

if __name__ == '__main__':
    main()