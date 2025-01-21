import os
import base64
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
import json
import boto3

class SecretsManager:
    def __init__(self, master_key=None):
        """
        Initialize Secrets Manager with encryption capabilities
        
        :param master_key: Optional master encryption key
        """
        self.ssm_client = boto3.client('ssm')
        self.secrets_manager = boto3.client('secretsmanager')
        
        # Generate or retrieve master key
        self.master_key = master_key or self._generate_master_key()

    def _generate_master_key(self):
        """
        Generate a secure master encryption key
        """
        # Use AWS KMS for key generation and management
        kms_client = boto3.client('kms')
        response = kms_client.generate_data_key(
            KeyId='alias/microservice-encryption-key',
            KeySpec='AES_256'
        )
        
        # Return plaintext key for encryption
        return response['Plaintext']

    def encrypt_secrets(self, secrets_dict):
        """
        Encrypt a dictionary of secrets
        
        :param secrets_dict: Dictionary of secrets to encrypt
        :return: Encrypted secrets
        """
        # Create Fernet symmetric encryption
        fernet = Fernet(self._derive_key(self.master_key))
        
        encrypted_secrets = {}
        for key, value in secrets_dict.items():
            encrypted_secrets[key] = fernet.encrypt(str(value).encode()).decode()
        
        return encrypted_secrets

    def decrypt_secrets(self, encrypted_secrets):
        """
        Decrypt previously encrypted secrets
        
        :param encrypted_secrets: Dictionary of encrypted secrets
        :return: Decrypted secrets
        """
        fernet = Fernet(self._derive_key(self.master_key))
        
        decrypted_secrets = {}
        for key, value in encrypted_secrets.items():
            decrypted_secrets[key] = fernet.decrypt(value.encode()).decode()
        
        return decrypted_secrets

    def _derive_key(self, master_key, salt=None):
        """
        Derive a secure encryption key using PBKDF2
        
        :param master_key: Original master key
        :param salt: Optional salt for key derivation
        :return: Derived Fernet key
        """
        salt = salt or os.urandom(16)
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=100000
        )
        key = base64.urlsafe_b64encode(kdf.derive(master_key))
        return key

    def store_secrets_in_aws(self, secrets_dict, secret_name='microservice-secrets'):
        """
        Store encrypted secrets in AWS Secrets Manager
        
        :param secrets_dict: Dictionary of secrets to store
        :param secret_name: Name of the secret in AWS Secrets Manager
        """
        encrypted_secrets = self.encrypt_secrets(secrets_dict)
        
        try:
            self.secrets_manager.create_secret(
                Name=secret_name,
                SecretString=json.dumps(encrypted_secrets)
            )
        except self.secrets_manager.exceptions.ResourceExistsException:
            # Update existing secret
            self.secrets_manager.update_secret(
                SecretId=secret_name,
                SecretString=json.dumps(encrypted_secrets)
            )

    def retrieve_secrets_from_aws(self, secret_name='microservice-secrets'):
        """
        Retrieve and decrypt secrets from AWS Secrets Manager
        
        :param secret_name: Name of the secret in AWS Secrets Manager
        :return: Decrypted secrets
        """
        try:
            secret = self.secrets_manager.get_secret_value(SecretId=secret_name)
            encrypted_secrets = json.loads(secret['SecretString'])
            return self.decrypt_secrets(encrypted_secrets)
        except Exception as e:
            print(f"Error retrieving secrets: {e}")
            return None

def main():
    # Load secrets from .env file
    secrets_dict = {}
    with open('/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/cicd/.env', 'r') as f:
        for line in f:
            if '=' in line and not line.startswith('#'):
                key, value = line.strip().split('=', 1)
                secrets_dict[key] = value

    # Initialize Secrets Manager
    secrets_manager = SecretsManager()
    
    # Store secrets in AWS Secrets Manager
    secrets_manager.store_secrets_in_aws(secrets_dict)
    
    # Retrieve and print decrypted secrets (for verification)
    decrypted_secrets = secrets_manager.retrieve_secrets_from_aws()
    print("Decrypted Secrets:", json.dumps(decrypted_secrets, indent=2))

if __name__ == '__main__':
    main()