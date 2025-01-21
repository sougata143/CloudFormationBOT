import boto3
import pytest
from botocore.exceptions import ClientError
import os
import hashlib
import time

class S3ReplicationTester:
    def __init__(self, source_bucket, destination_bucket, region='us-west-2'):
        """
        Initialize S3 Replication Tester
        
        :param source_bucket: Source S3 bucket name
        :param destination_bucket: Destination S3 bucket name
        :param region: AWS region
        """
        self.s3_client = boto3.client('s3', region_name=region)
        self.source_bucket = source_bucket
        self.destination_bucket = destination_bucket
        self.logger = self._setup_logger()
    
    def _setup_logger(self):
        """
        Setup logging for replication tests
        """
        import logging
        logger = logging.getLogger('S3ReplicationTester')
        logger.setLevel(logging.INFO)
        
        # Create logs directory
        os.makedirs('logs', exist_ok=True)
        
        # File handler
        file_handler = logging.FileHandler(f'logs/replication_test_{time.strftime("%Y%m%d_%H%M%S")}.log')
        file_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s: %(message)s'))
        logger.addHandler(file_handler)
        
        return logger
    
    def generate_test_file(self, size_mb=10):
        """
        Generate a test file with random content
        
        :param size_mb: Size of test file in MB
        :return: Path to generated file
        """
        test_data = os.urandom(size_mb * 1024 * 1024)
        filename = f'replication_test_{hashlib.md5(test_data).hexdigest()}.bin'
        filepath = os.path.join('temp', filename)
        
        os.makedirs('temp', exist_ok=True)
        
        with open(filepath, 'wb') as f:
            f.write(test_data)
        
        return filepath
    
    def upload_test_file(self, filepath):
        """
        Upload test file to source bucket
        
        :param filepath: Path to file to upload
        :return: Object key
        """
        object_key = os.path.basename(filepath)
        
        try:
            self.s3_client.upload_file(filepath, self.source_bucket, object_key)
            self.logger.info(f"Uploaded {filepath} to {self.source_bucket}")
            return object_key
        except ClientError as e:
            self.logger.error(f"Upload failed: {e}")
            raise
    
    def verify_replication(self, object_key, max_wait_time=300):
        """
        Verify file replication to destination bucket
        
        :param object_key: Object key to verify
        :param max_wait_time: Maximum wait time in seconds
        :return: Boolean indicating successful replication
        """
        start_time = time.time()
        
        while time.time() - start_time < max_wait_time:
            try:
                # Check if object exists in destination bucket
                self.s3_client.head_object(Bucket=self.destination_bucket, Key=object_key)
                self.logger.info(f"Replication successful for {object_key}")
                return True
            except ClientError:
                time.sleep(5)  # Wait before retrying
        
        self.logger.error(f"Replication failed for {object_key}")
        return False

def test_s3_cross_region_replication():
    """
    Pytest for S3 cross-region replication
    """
    # Configuration (ideally from environment or config file)
    source_bucket = os.environ.get('SOURCE_BUCKET', 'microservice-dev-storage')
    destination_bucket = os.environ.get('DESTINATION_BUCKET', 'microservice-dev-storage-replica')
    
    # Initialize tester
    replication_tester = S3ReplicationTester(source_bucket, destination_bucket)
    
    # Generate test file
    test_file = replication_tester.generate_test_file()
    
    try:
        # Upload test file
        object_key = replication_tester.upload_test_file(test_file)
        
        # Verify replication
        replication_success = replication_tester.verify_replication(object_key)
        
        # Assert replication
        assert replication_success, "S3 cross-region replication failed"
    
    finally:
        # Cleanup
        os.remove(test_file)

if __name__ == '__main__':
    pytest.main([__file__])