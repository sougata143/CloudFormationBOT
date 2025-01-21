import boto3
import json
import logging
from datetime import datetime, timedelta

class AutomatedRemediation:
    def __init__(self, regions=['us-west-2', 'us-east-1']):
        """
        Initialize automated remediation system
        
        :param regions: List of AWS regions to monitor and remediate
        """
        self.regions = regions
        self.clients = {
            'ec2': {region: boto3.client('ec2', region_name=region) for region in regions},
            'rds': {region: boto3.client('rds', region_name=region) for region in regions},
            'config': {region: boto3.client('config', region_name=region) for region in regions},
            'sns': {region: boto3.client('sns', region_name=region) for region in regions}
        }
        
        # Configure logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)

    def remediate_public_access(self):
        """
        Automatically remediate resources with public access
        """
        remediation_actions = []

        for region in self.regions:
            try:
                # Check and modify EC2 security groups
                security_groups = self.clients['ec2'][region].describe_security_groups(
                    Filters=[{'Name': 'ip-permission.cidr', 'Values': ['0.0.0.0/0']}]
                )

                for sg in security_groups['SecurityGroups']:
                    # Remove public access rules
                    self.clients['ec2'][region].revoke_security_group_ingress(
                        GroupId=sg['GroupId'],
                        IpPermissions=[
                            permission for permission in sg['IpPermissions']
                            if any(ip_range.get('CidrIp') == '0.0.0.0/0' for ip_range in permission.get('IpRanges', []))
                        ]
                    )
                    
                    remediation_actions.append({
                        'type': 'security_group_modification',
                        'resource_id': sg['GroupId'],
                        'region': region
                    })

                # Check RDS instances with public accessibility
                rds_instances = self.clients['rds'][region].describe_db_instances()
                
                for db in rds_instances['DBInstances']:
                    if db.get('PubliclyAccessible', False):
                        self.clients['rds'][region].modify_db_instance(
                            DBInstanceIdentifier=db['DBInstanceIdentifier'],
                            PubliclyAccessible=False
                        )
                        
                        remediation_actions.append({
                            'type': 'rds_public_access_disabled',
                            'resource_id': db['DBInstanceIdentifier'],
                            'region': region
                        })

            except Exception as e:
                self.logger.error(f"Remediation error in {region}: {e}")

        return remediation_actions

    def enforce_encryption(self):
        """
        Enforce encryption for unencrypted resources
        """
        encryption_actions = []

        for region in self.regions:
            try:
                # Check and encrypt RDS instances
                rds_instances = self.clients['rds'][region].describe_db_instances()
                
                for db in rds_instances['DBInstances']:
                    if not db.get('StorageEncrypted', False):
                        self.clients['rds'][region].modify_db_instance(
                            DBInstanceIdentifier=db['DBInstanceIdentifier'],
                            StorageEncrypted=True,
                            # Specify KMS key if needed
                            # KmsKeyId='your-kms-key-arn'
                        )
                        
                        encryption_actions.append({
                            'type': 'rds_encryption_enabled',
                            'resource_id': db['DBInstanceIdentifier'],
                            'region': region
                        })

                # Check and encrypt EBS volumes
                volumes = self.clients['ec2'][region].describe_volumes(
                    Filters=[{'Name': 'encrypted', 'Values': ['false']}]
                )
                
                for volume in volumes['Volumes']:
                    # Create an encrypted snapshot and restore
                    snapshot = self.clients['ec2'][region].create_snapshot(
                        VolumeId=volume['VolumeId'],
                        Description='Encryption Migration Snapshot'
                    )
                    
                    self.clients['ec2'][region].create_volume(
                        SnapshotId=snapshot['SnapshotId'],
                        AvailabilityZone=volume['AvailabilityZone'],
                        Encrypted=True
                    )
                    
                    encryption_actions.append({
                        'type': 'ebs_volume_encryption',
                        'resource_id': volume['VolumeId'],
                        'region': region
                    })

            except Exception as e:
                self.logger.error(f"Encryption enforcement error in {region}: {e}")

        return encryption_actions

    def notify_remediation_actions(self, remediation_actions):
        """
        Send notifications about remediation actions
        """
        for region in self.regions:
            try:
                region_actions = [
                    action for action in remediation_actions
                    if action['region'] == region
                ]
                
                if region_actions:
                    self.clients['sns'][region].publish(
                        TopicArn=f'arn:aws:sns:{region}:123456789012:remediation-notifications',
                        Message=json.dumps(region_actions, indent=2),
                        Subject='Automated Security Remediation Actions'
                    )
            
            except Exception as e:
                self.logger.error(f"Notification error in {region}: {e}")

    def run_comprehensive_remediation(self):
        """
        Run comprehensive automated remediation
        """
        # Track all remediation actions
        all_remediation_actions = []
        
        # Public access remediation
        public_access_actions = self.remediate_public_access()
        all_remediation_actions.extend(public_access_actions)
        
        # Encryption enforcement
        encryption_actions = self.enforce_encryption()
        all_remediation_actions.extend(encryption_actions)
        
        # Notify about remediation actions
        self.notify_remediation_actions(all_remediation_actions)
        
        return all_remediation_actions

def main():
    remediation_system = AutomatedRemediation()
    
    # Run comprehensive remediation
    remediation_actions = remediation_system.run_comprehensive_remediation()
    
    # Log remediation summary
    print("Automated Remediation Summary:")
    print(json.dumps(remediation_actions, indent=2))

if __name__ == '__main__':
    main()