import boto3
import json
from datetime import datetime, timedelta

class SecurityComplianceChecker:
    def __init__(self, regions=['us-west-2', 'us-east-1']):
        """
        Initialize security compliance checker
        
        :param regions: List of AWS regions to check
        """
        self.regions = regions
        self.clients = {
            'config': {region: boto3.client('config', region_name=region) for region in regions},
            'iam': {region: boto3.client('iam', region_name=region) for region in regions},
            'securityhub': {region: boto3.client('securityhub', region_name=region) for region in regions}
        }

    def check_iam_password_policy(self):
        """
        Check IAM password policy compliance
        """
        compliance_results = {}
        
        for region in self.regions:
            try:
                password_policy = self.clients['iam'][region].get_account_password_policy()
                policy = password_policy.get('PasswordPolicy', {})
                
                compliance_results[region] = {
                    'minimum_password_length': policy.get('MinimumPasswordLength', 0) >= 14,
                    'require_symbols': policy.get('RequireSymbols', False),
                    'require_numbers': policy.get('RequireNumbers', False),
                    'require_uppercase': policy.get('RequireUppercaseCharacters', False),
                    'require_lowercase': policy.get('RequireLowercaseCharacters', False),
                    'password_reuse_prevention': policy.get('PasswordReusePrevention', 0) >= 24
                }
            
            except Exception as e:
                compliance_results[region] = {'error': str(e)}
        
        return compliance_results

    def check_security_groups(self):
        """
        Check security group configurations
        """
        ec2_client = boto3.client('ec2')
        compliance_results = {}
        
        for region in self.regions:
            try:
                security_groups = ec2_client.describe_security_groups(
                    Filters=[{'Name': 'ip-permission.cidr', 'Values': ['0.0.0.0/0']}]
                )
                
                non_compliant_groups = []
                for sg in security_groups['SecurityGroups']:
                    for permission in sg['IpPermissions']:
                        for ip_range in permission.get('IpRanges', []):
                            if ip_range.get('CidrIp') == '0.0.0.0/0':
                                non_compliant_groups.append({
                                    'group_id': sg['GroupId'],
                                    'group_name': sg.get('GroupName', 'N/A'),
                                    'protocol': permission.get('IpProtocol', 'N/A'),
                                    'port': permission.get('FromPort', 'N/A')
                                })
                
                compliance_results[region] = {
                    'non_compliant_security_groups': non_compliant_groups,
                    'is_compliant': len(non_compliant_groups) == 0
                }
            
            except Exception as e:
                compliance_results[region] = {'error': str(e)}
        
        return compliance_results

    def check_encryption_status(self):
        """
        Check encryption status for key AWS services
        """
        compliance_results = {}
        
        for region in self.regions:
            try:
                # Check RDS encryption
                rds_client = boto3.client('rds', region_name=region)
                db_instances = rds_client.describe_db_instances()
                
                unencrypted_databases = [
                    db['DBInstanceIdentifier'] for db in db_instances['DBInstances']
                    if not db.get('StorageEncrypted', False)
                ]
                
                # Check S3 bucket encryption
                s3_client = boto3.client('s3', region_name=region)
                buckets = s3_client.list_buckets()
                
                unencrypted_buckets = []
                for bucket in buckets['Buckets']:
                    try:
                        encryption = s3_client.get_bucket_encryption(Bucket=bucket['Name'])
                        if not encryption.get('ServerSideEncryptionConfiguration'):
                            unencrypted_buckets.append(bucket['Name'])
                    except s3_client.exceptions.ClientError:
                        unencrypted_buckets.append(bucket['Name'])
                
                compliance_results[region] = {
                    'unencrypted_databases': unencrypted_databases,
                    'unencrypted_s3_buckets': unencrypted_buckets,
                    'is_compliant': len(unencrypted_databases) == 0 and len(unencrypted_buckets) == 0
                }
            
            except Exception as e:
                compliance_results[region] = {'error': str(e)}
        
        return compliance_results

    def generate_compliance_report(self):
        """
        Generate comprehensive compliance report
        """
        report = {
            'timestamp': datetime.now().isoformat(),
            'iam_password_policy': self.check_iam_password_policy(),
            'security_groups': self.check_security_groups(),
            'encryption_status': self.check_encryption_status()
        }
        
        return report

def main():
    compliance_checker = SecurityComplianceChecker()
    
    # Generate compliance report
    compliance_report = compliance_checker.generate_compliance_report()
    
    # Save report
    with open('security_compliance_report.json', 'w') as f:
        json.dump(compliance_report, f, indent=2)
    
    # Print summary
    print("Security Compliance Report Generated")
    print(json.dumps(compliance_report, indent=2))

if __name__ == '__main__':
    main()