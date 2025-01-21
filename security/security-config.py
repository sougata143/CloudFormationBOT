import boto3
import json
from botocore.exceptions import ClientError

class SecurityConfigurationManager:
    def __init__(self, regions=['us-west-2', 'us-east-1']):
        """
        Initialize security configuration management
        
        :param regions: List of AWS regions to configure
        """
        self.regions = regions
        self.clients = {
            'iam': {region: boto3.client('iam', region_name=region) for region in regions},
            'ec2': {region: boto3.client('ec2', region_name=region) for region in regions},
            'wafv2': {region: boto3.client('wafv2', region_name=region) for region in regions},
            'kms': {region: boto3.client('kms', region_name=region) for region in regions},
            'secretsmanager': {region: boto3.client('secretsmanager', region_name=region) for region in regions}
        }

    def create_least_privilege_roles(self):
        """
        Create IAM roles with least privilege principle
        """
        role_configurations = [
            {
                'name': 'MicroserviceDeploymentRole',
                'services': ['ecs-tasks.amazonaws.com'],
                'policies': [
                    {
                        'name': 'ECSDeploymentPolicy',
                        'document': {
                            "Version": "2012-10-17",
                            "Statement": [
                                {
                                    "Effect": "Allow",
                                    "Action": [
                                        "ecs:DescribeServices",
                                        "ecs:UpdateService",
                                        "ecs:DescribeTaskDefinition"
                                    ],
                                    "Resource": "*"
                                }
                            ]
                        }
                    }
                ]
            }
        ]

        created_roles = []
        for region in self.regions:
            for role_config in role_configurations:
                try:
                    # Create role
                    role_response = self.clients['iam'][region].create_role(
                        RoleName=role_config['name'],
                        AssumeRolePolicyDocument=json.dumps({
                            "Version": "2012-10-17",
                            "Statement": [
                                {
                                    "Effect": "Allow",
                                    "Principal": {
                                        "Service": role_config['services']
                                    },
                                    "Action": "sts:AssumeRole"
                                }
                            ]
                        })
                    )

                    # Attach policies
                    for policy in role_config['policies']:
                        policy_response = self.clients['iam'][region].create_policy(
                            PolicyName=policy['name'],
                            PolicyDocument=json.dumps(policy['document'])
                        )
                        
                        self.clients['iam'][region].attach_role_policy(
                            RoleName=role_config['name'],
                            PolicyArn=policy_response['Policy']['Arn']
                        )

                    created_roles.append({
                        'region': region,
                        'role_name': role_config['name'],
                        'role_arn': role_response['Role']['Arn']
                    })
                
                except ClientError as e:
                    print(f"Error creating role in {region}: {e}")

        return created_roles

    def configure_secrets_manager(self):
        """
        Configure AWS Secrets Manager for secure credential management
        """
        secret_configurations = [
            {
                'name': 'microservice-database-credentials',
                'description': 'Database credentials for microservice',
                'secret_value': {
                    'username': 'db_user',
                    'password': 'secure_password',
                    'endpoint': 'database.endpoint.com'
                }
            }
        ]

        created_secrets = []
        for region in self.regions:
            for secret_config in secret_configurations:
                try:
                    response = self.clients['secretsmanager'][region].create_secret(
                        Name=secret_config['name'],
                        Description=secret_config['description'],
                        SecretString=json.dumps(secret_config['secret_value'])
                    )
                    
                    created_secrets.append({
                        'region': region,
                        'secret_name': secret_config['name'],
                        'secret_arn': response['ARN']
                    })
                
                except ClientError as e:
                    print(f"Error creating secret in {region}: {e}")

        return created_secrets

    def configure_kms_encryption(self):
        """
        Configure KMS for encryption
        """
        kms_configurations = [
            {
                'alias': 'microservice-encryption-key',
                'description': 'Encryption key for microservice data',
                'key_usage': 'ENCRYPT_DECRYPT'
            }
        ]

        created_keys = []
        for region in self.regions:
            for kms_config in kms_configurations:
                try:
                    response = self.clients['kms'][region].create_key(
                        Description=kms_config['description'],
                        KeyUsage=kms_config['key_usage']
                    )

                    # Create alias
                    self.clients['kms'][region].create_alias(
                        AliasName=f'alias/{kms_config["alias"]}',
                        TargetKeyId=response['KeyMetadata']['KeyId']
                    )

                    created_keys.append({
                        'region': region,
                        'key_id': response['KeyMetadata']['KeyId'],
                        'arn': response['KeyMetadata']['Arn']
                    })
                
                except ClientError as e:
                    print(f"Error creating KMS key in {region}: {e}")

        return created_keys

    def configure_waf_rules(self):
        """
        Configure WAF rules for web application protection
        """
        waf_rule_configurations = [
            {
                'name': 'block-common-attacks',
                'priority': 1,
                'action': 'block',
                'statement': {
                    'managedRuleGroupStatement': {
                        'vendorName': 'AWS',
                        'name': 'AWSManagedRulesCommonRuleSet'
                    }
                }
            }
        ]

        created_waf_rules = []
        for region in self.regions:
            for waf_config in waf_rule_configurations:
                try:
                    response = self.clients['wafv2'][region].create_web_acl(
                        Name=waf_config['name'],
                        Scope='REGIONAL',
                        DefaultAction={'Allow': {}},
                        Rules=[
                            {
                                'Name': waf_config['name'],
                                'Priority': waf_config['priority'],
                                'Action': {'Block': {}},
                                'Statement': waf_config['statement'],
                                'VisibilityConfig': {
                                    'SampledRequestsEnabled': True,
                                    'CloudWatchMetricsEnabled': True,
                                    'MetricName': waf_config['name']
                                }
                            }
                        ],
                        VisibilityConfig={
                            'SampledRequestsEnabled': True,
                            'CloudWatchMetricsEnabled': True,
                            'MetricName': waf_config['name']
                        }
                    )

                    created_waf_rules.append({
                        'region': region,
                        'name': waf_config['name'],
                        'arn': response['Summary']['ARN']
                    })
                
                except ClientError as e:
                    print(f"Error creating WAF rule in {region}: {e}")

        return created_waf_rules

def main():
    security_config_manager = SecurityConfigurationManager()
    
    # Configure security components
    roles = security_config_manager.create_least_privilege_roles()
    secrets = security_config_manager.configure_secrets_manager()
    encryption_keys = security_config_manager.configure_kms_encryption()
    waf_rules = security_config_manager.configure_waf_rules()
    
    # Generate comprehensive security configuration report
    security_report = {
        'roles': roles,
        'secrets': secrets,
        'encryption_keys': encryption_keys,
        'waf_rules': waf_rules
    }
    
    # Save security configuration report
    with open('security_configuration_report.json', 'w') as f:
        json.dump(security_report, f, indent=2)

if __name__ == '__main__':
    main()