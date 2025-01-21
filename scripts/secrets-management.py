import boto3
import json
import base64
from cryptography.fernet import Fernet

class SecretManager:
    def __init__(self, region='us-west-2'):
        self.secrets_manager = boto3.client('secretsmanager', region_name=region)
        self.kms_client = boto3.client('kms', region_name=region)

    def create_encryption_key(self):
        """
        Create a KMS key for encryption
        """
        response = self.kms_client.create_key(
            Description='Microservice Encryption Key',
            KeyUsage='ENCRYPT_DECRYPT',
            Origin='AWS_KMS'
        )
        return response['KeyMetadata']['KeyId']

    def encrypt_secret(self, key_id, secret):
        """
        Encrypt a secret using KMS
        """
        response = self.kms_client.encrypt(
            KeyId=key_id,
            Plaintext=json.dumps(secret).encode()
        )
        return base64.b64encode(response['CiphertextBlob']).decode()

    def store_secret(self, secret_name, secret_value, key_id):
        """
        Store an encrypted secret in Secrets Manager
        """
        encrypted_secret = self.encrypt_secret(key_id, secret_value)
        
        try:
            self.secrets_manager.create_secret(
                Name=secret_name,
                Description='Microservice Deployment Secrets',
                SecretString=encrypted_secret,
                KmsKeyId=key_id
            )
            print(f"Secret {secret_name} stored successfully")
        except self.secrets_manager.exceptions.ResourceExistsException:
            print(f"Secret {secret_name} already exists. Updating...")
            self.secrets_manager.update_secret(
                SecretId=secret_name,
                SecretString=encrypted_secret,
                KmsKeyId=key_id
            )

def main():
    secret_manager = SecretManager()
    
    # Create encryption key
    key_id = secret_manager.create_encryption_key()
    
    # Secrets to store
    secrets = {
        'database-credentials': {
            'username': 'microservice_user',
            'password': 'secure_password_here',
            'endpoint': 'database.endpoint.com'
        },
        'jenkins-credentials': {
            'admin_username': 'jenkins_admin',
            'admin_password': 'secure_jenkins_password'
        }
    }

    # Store each secret
    for name, value in secrets.items():
        secret_manager.store_secret(name, value, key_id)

if __name__ == '__main__':
    main()