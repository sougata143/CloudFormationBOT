import unittest
import boto3
from moto import mock_rds, mock_secretsmanager, mock_iam
import sys
sys.path.append('../scripts')  # Add scripts directory to path

from secrets_management import SecretManager
from iam_roles_setup import IAMRoleManager
from deployment_script import MicroserviceDeployment

class TestMicroserviceInfrastructure(unittest.TestCase):
    def setUp(self):
        # Mock AWS services
        self.rds_mock = mock_rds()
        self.rds_mock.start()
        
        self.secrets_mock = mock_secretsmanager()
        self.secrets_mock.start()
        
        self.iam_mock = mock_iam()
        self.iam_mock.start()

    def tearDown(self):
        # Stop mocking AWS services
        self.rds_mock.stop()
        self.secrets_mock.stop()
        self.iam_mock.stop()

    def test_secret_management(self):
        """
        Test secret management functionality
        """
        secret_manager = SecretManager()
        
        # Create encryption key
        key_id = secret_manager.create_encryption_key()
        self.assertIsNotNone(key_id)

        # Store and retrieve secret
        test_secret = {
            'username': 'test_user',
            'password': 'test_password'
        }
        secret_manager.store_secret('test-secret', test_secret, key_id)

    def test_iam_role_creation(self):
        """
        Test IAM role creation
        """
        role_manager = IAMRoleManager()
        
        role_arn = role_manager.create_deployment_role(
            'TestDeploymentRole', 
            ['ecs-tasks.amazonaws.com']
        )
        
        self.assertIsNotNone(role_arn)
        self.assertTrue(role_arn.startswith('arn:aws:iam::'))

    def test_microservice_deployment(self):
        """
        Test microservice deployment workflow
        """
        deployment = MicroserviceDeployment('test-environment')
        
        # Simulate deployment
        result = deployment.deploy_microservices()
        
        self.assertTrue(result)

    def test_multi_region_deployment(self):
        """
        Test deployment across multiple regions
        """
        regions = ['us-west-2', 'us-east-1', 'eu-west-1']
        
        for region in regions:
            deployment = MicroserviceDeployment(f'test-environment-{region}', region)
            result = deployment.deploy_microservices()
            self.assertTrue(result)

    def test_error_scenarios(self):
        """
        Test error handling and recovery
        """
        # Simulate network disconnection
        with self.assertRaises(ConnectionError):
            deployment = MicroserviceDeployment('error-test')
            deployment.update_ecs_service(
                'non-existent-cluster', 
                'non-existent-service', 
                'non-existent-repository'
            )

def main():
    unittest.main()

if __name__ == '__main__':
    main()