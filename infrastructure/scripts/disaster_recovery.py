import boto3
import logging
import os
import json
from datetime import datetime, timedelta

class DisasterRecoveryManager:
    def __init__(self, source_bucket, destination_bucket, region='us-west-2'):
        """
        Initialize Disaster Recovery Manager
        
        :param source_bucket: Primary S3 bucket
        :param destination_bucket: Disaster recovery S3 bucket
        :param region: AWS region
        """
        self.s3_client = boto3.client('s3', region_name=region)
        self.source_bucket = source_bucket
        self.destination_bucket = destination_bucket
        self.logger = self._setup_logger()
    
    def _setup_logger(self):
        """
        Setup logging for disaster recovery
        """
        logger = logging.getLogger('DisasterRecoveryManager')
        logger.setLevel(logging.INFO)
        
        # Create logs directory
        os.makedirs('logs', exist_ok=True)
        
        # File handler
        file_handler = logging.FileHandler(f'logs/disaster_recovery_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log')
        file_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s: %(message)s'))
        logger.addHandler(file_handler)
        
        return logger
    
    def backup_bucket_metadata(self):
        """
        Backup bucket metadata and configuration
        """
        backup_data = {
            'timestamp': datetime.now().isoformat(),
            'source_bucket': self.source_bucket,
            'destination_bucket': self.destination_bucket,
            'bucket_policy': self._get_bucket_policy(),
            'bucket_lifecycle_rules': self._get_lifecycle_rules(),
            'bucket_versioning': self._get_versioning_status()
        }
        
        backup_file = f'disaster_recovery_backup_{datetime.now().strftime("%Y%m%d_%H%M%S")}.json'
        
        with open(os.path.join('backups', backup_file), 'w') as f:
            json.dump(backup_data, f, indent=2)
        
        self.logger.info(f"Backup metadata saved to {backup_file}")
    
    def _get_bucket_policy(self):
        """
        Retrieve bucket policy
        """
        try:
            policy = self.s3_client.get_bucket_policy(Bucket=self.source_bucket)
            return policy['Policy']
        except Exception as e:
            self.logger.warning(f"Could not retrieve bucket policy: {e}")
            return None
    
    def _get_lifecycle_rules(self):
        """
        Retrieve bucket lifecycle rules
        """
        try:
            lifecycle = self.s3_client.get_bucket_lifecycle_configuration(Bucket=self.source_bucket)
            return lifecycle['Rules']
        except Exception as e:
            self.logger.warning(f"Could not retrieve lifecycle rules: {e}")
            return None
    
    def _get_versioning_status(self):
        """
        Retrieve bucket versioning status
        """
        try:
            versioning = self.s3_client.get_bucket_versioning(Bucket=self.source_bucket)
            return versioning.get('Status')
        except Exception as e:
            self.logger.warning(f"Could not retrieve versioning status: {e}")
            return None
    
    def restore_from_backup(self, backup_file):
        """
        Restore bucket configuration from backup
        
        :param backup_file: Path to backup JSON file
        """
        with open(backup_file, 'r') as f:
            backup_data = json.load(f)
        
        # Restore bucket policy
        if backup_data.get('bucket_policy'):
            self.s3_client.put_bucket_policy(
                Bucket=self.destination_bucket,
                Policy=backup_data['bucket_policy']
            )
        
        # Restore lifecycle rules
        if backup_data.get('bucket_lifecycle_rules'):
            self.s3_client.put_bucket_lifecycle_configuration(
                Bucket=self.destination_bucket,
                LifecycleConfiguration={'Rules': backup_data['bucket_lifecycle_rules']}
            )
        
        # Restore versioning
        if backup_data.get('bucket_versioning'):
            self.s3_client.put_bucket_versioning(
                Bucket=self.destination_bucket,
                VersioningConfiguration={'Status': backup_data['bucket_versioning']}
            )
        
        self.logger.info(f"Restored configuration from {backup_file}")

def main():
    # Configuration
    source_bucket = os.environ.get('SOURCE_BUCKET', 'microservice-dev-storage')
    destination_bucket = os.environ.get('DESTINATION_BUCKET', 'microservice-dev-storage-replica')
    
    # Create backups directory
    os.makedirs('backups', exist_ok=True)
    
    # Initialize disaster recovery manager
    drm = DisasterRecoveryManager(source_bucket, destination_bucket)
    
    # Perform backup
    drm.backup_bucket_metadata()

if __name__ == '__main__':
    main()