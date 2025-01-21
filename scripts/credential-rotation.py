import boto3
import json
import secrets
import datetime
from botocore.exceptions import ClientError

class CredentialRotationManager:
    def __init__(self, region='us-west-2'):
        self.secrets_manager = boto3.client('secretsmanager', region_name=region)
        self.rds_client = boto3.client('rds', region_name=region)
        self.iam_client = boto3.client('iam', region_name=region)

    def generate_secure_password(self, length=32):
        """
        Generate a cryptographically secure password
        """
        # Use secrets module for cryptographically strong random generation
        alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+-='
        return ''.join(secrets.choice(alphabet) for _ in range(length))

    def rotate_database_credentials(self, database_identifier):
        """
        Rotate RDS database credentials
        """
        try:
            # Generate new credentials
            new_password = self.generate_secure_password()

            # Modify database master user password
            self.rds_client.modify_db_instance(
                DBInstanceIdentifier=database_identifier,
                MasterUserPassword=new_password
            )

            # Store new credentials in Secrets Manager
            self.secrets_manager.update_secret(
                SecretId=f'{database_identifier}-credentials',
                SecretString=json.dumps({
                    'username': 'master_user',
                    'password': new_password,
                    'rotation_date': datetime.datetime.now().isoformat()
                })
            )

            print(f"Successfully rotated credentials for {database_identifier}")
            return True

        except ClientError as e:
            print(f"Credential rotation error: {e}")
            return False

    def rotate_iam_access_keys(self, username):
        """
        Rotate IAM user access keys
        """
        try:
            # List existing access keys
            existing_keys = self.iam_client.list_access_keys(UserName=username)

            # Deactivate and delete old keys
            for key in existing_keys['AccessKeyMetadata']:
                if key['Status'] == 'Active':
                    self.iam_client.update_access_key(
                        UserName=username,
                        AccessKeyId=key['AccessKeyId'],
                        Status='Inactive'
                    )
                    self.iam_client.delete_access_key(
                        UserName=username,
                        AccessKeyId=key['AccessKeyId']
                    )

            # Create new access key
            new_key = self.iam_client.create_access_key(UserName=username)

            # Store new key in Secrets Manager
            self.secrets_manager.update_secret(
                SecretId=f'{username}-access-keys',
                SecretString=json.dumps({
                    'access_key_id': new_key['AccessKey']['AccessKeyId'],
                    'secret_access_key': new_key['AccessKey']['SecretAccessKey'],
                    'rotation_date': datetime.datetime.now().isoformat()
                })
            )

            print(f"Successfully rotated IAM access keys for {username}")
            return True

        except ClientError as e:
            print(f"IAM key rotation error: {e}")
            return False

    def comprehensive_rotation(self):
        """
        Perform comprehensive credential rotation
        """
        rotation_targets = {
            'databases': ['microservice-database'],
            'iam_users': ['deployment-service-account']
        }

        rotation_results = {
            'databases': {},
            'iam_users': {}
        }

        # Rotate database credentials
        for db in rotation_targets['databases']:
            rotation_results['databases'][db] = self.rotate_database_credentials(db)

        # Rotate IAM access keys
        for user in rotation_targets['iam_users']:
            rotation_results['iam_users'][user] = self.rotate_iam_access_keys(user)

        return rotation_results

def main():
    rotation_manager = CredentialRotationManager()
    
    # Perform comprehensive rotation
    rotation_results = rotation_manager.comprehensive_rotation()
    
    # Log rotation results
    print("Credential Rotation Results:")
    print(json.dumps(rotation_results, indent=2))

if __name__ == '__main__':
    main()