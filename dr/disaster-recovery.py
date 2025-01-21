import boto3
import json
from datetime import datetime, timedelta

class DisasterRecoveryManager:
    def __init__(self, primary_region='us-west-2', backup_region='us-east-1'):
        """
        Initialize Disaster Recovery Management
        
        :param primary_region: Primary AWS region
        :param backup_region: Backup/Failover AWS region
        """
        self.primary_region = primary_region
        self.backup_region = backup_region
        
        # Initialize AWS clients
        self.ec2_primary = boto3.client('ec2', region_name=primary_region)
        self.ec2_backup = boto3.client('ec2', region_name=backup_region)
        self.rds_primary = boto3.client('rds', region_name=primary_region)
        self.rds_backup = boto3.client('rds', region_name=backup_region)
        self.s3_client = boto3.client('s3')

    def backup_rds_snapshot(self, db_instance_identifier):
        """
        Create RDS snapshot for disaster recovery
        
        :param db_instance_identifier: RDS database instance identifier
        :return: Snapshot details
        """
        try:
            snapshot_id = f"dr-snapshot-{db_instance_identifier}-{datetime.now().strftime('%Y%m%d%H%M%S')}"
            
            snapshot_response = self.rds_primary.create_db_snapshot(
                DBSnapshotIdentifier=snapshot_id,
                DBInstanceIdentifier=db_instance_identifier
            )
            
            # Copy snapshot to backup region
            self.copy_rds_snapshot(snapshot_id)
            
            return {
                'snapshotId': snapshot_id,
                'primaryRegion': self.primary_region,
                'backupRegion': self.backup_region
            }
        
        except Exception as e:
            print(f"RDS snapshot error: {e}")
            return None

    def copy_rds_snapshot(self, snapshot_id):
        """
        Copy RDS snapshot to backup region
        
        :param snapshot_id: Source snapshot identifier
        """
        try:
            self.rds_primary.copy_db_snapshot(
                SourceDBSnapshotIdentifier=f"arn:aws:rds:{self.primary_region}:snapshot:{snapshot_id}",
                TargetDBSnapshotIdentifier=f"{snapshot_id}-backup",
                KmsKeyId=None,  # Optional: specify KMS key for encryption
                SourceRegion=self.primary_region
            )
        except Exception as e:
            print(f"Snapshot copy error: {e}")

    def create_cross_region_backup_bucket(self, bucket_name):
        """
        Create S3 bucket in backup region for cross-region backup
        
        :param bucket_name: Name of the backup bucket
        :return: Bucket configuration
        """
        try:
            # Create bucket in primary region
            self.s3_client.create_bucket(
                Bucket=f"{bucket_name}-{self.primary_region}",
                CreateBucketConfiguration={'LocationConstraint': self.primary_region}
            )
            
            # Create bucket in backup region
            self.s3_client.create_bucket(
                Bucket=f"{bucket_name}-{self.backup_region}",
                CreateBucketConfiguration={'LocationConstraint': self.backup_region}
            )
            
            # Configure replication
            self.configure_s3_cross_region_replication(
                f"{bucket_name}-{self.primary_region}",
                f"{bucket_name}-{self.backup_region}"
            )
            
            return {
                'primaryBucket': f"{bucket_name}-{self.primary_region}",
                'backupBucket': f"{bucket_name}-{self.backup_region}"
            }
        
        except Exception as e:
            print(f"Bucket creation error: {e}")
            return None

    def configure_s3_cross_region_replication(self, source_bucket, destination_bucket):
        """
        Configure S3 cross-region replication
        
        :param source_bucket: Source S3 bucket
        :param destination_bucket: Destination S3 bucket
        """
        try:
            # IAM role for replication
            iam_client = boto3.client('iam')
            replication_role = iam_client.create_role(
                RoleName='S3CrossRegionReplicationRole',
                AssumeRolePolicyDocument=json.dumps({
                    'Version': '2012-10-17',
                    'Statement': [
                        {
                            'Effect': 'Allow',
                            'Principal': {'Service': 's3.amazonaws.com'},
                            'Action': 'sts:AssumeRole'
                        }
                    ]
                })
            )
            
            # Attach replication policy
            iam_client.put_role_policy(
                RoleName='S3CrossRegionReplicationRole',
                PolicyName='S3ReplicationPolicy',
                PolicyDocument=json.dumps({
                    'Version': '2012-10-17',
                    'Statement': [
                        {
                            'Effect': 'Allow',
                            'Action': [
                                's3:GetReplicationConfiguration',
                                's3:ListBucket'
                            ],
                            'Resource': [f'arn:aws:s3:::{source_bucket}']
                        }
                    ]
                })
            )
        
        except Exception as e:
            print(f"Replication configuration error: {e}")

def main():
    dr_manager = DisasterRecoveryManager()
    
    # Create cross-region backup bucket
    bucket_config = dr_manager.create_cross_region_backup_bucket('microservice-backup')
    
    # Create RDS snapshot
    rds_snapshot = dr_manager.backup_rds_snapshot('microservice-database')
    
    # Generate DR report
    dr_report = {
        'timestamp': datetime.now().isoformat(),
        's3_backup': bucket_config,
        'rds_snapshot': rds_snapshot
    }
    
    # Save DR report
    with open('disaster_recovery_report.json', 'w') as f:
        json.dump(dr_report, f, indent=2)

if __name__ == '__main__':
    main()