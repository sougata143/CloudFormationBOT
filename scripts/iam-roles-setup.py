import boto3
from botocore.exceptions import ClientError

class IAMRoleManager:
    def __init__(self, region='us-west-2'):
        self.iam_client = boto3.client('iam', region_name=region)
        self.sts_client = boto3.client('sts', region_name=region)

    def create_deployment_role(self, role_name, services):
        """
        Create an IAM role with specific service assume role permissions
        
        :param role_name: Name of the IAM role
        :param services: List of AWS services that can assume the role
        :return: Role ARN
        """
        try:
            # Create assume role policy document
            assume_role_policy = {
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Effect": "Allow",
                        "Principal": {
                            "Service": services
                        },
                        "Action": "sts:AssumeRole"
                    }
                ]
            }

            # Create IAM role
            response = self.iam_client.create_role(
                RoleName=role_name,
                AssumeRolePolicyDocument=json.dumps(assume_role_policy)
            )

            # Attach deployment policies
            self._attach_deployment_policies(role_name)

            return response['Role']['Arn']

        except ClientError as e:
            print(f"Error creating IAM role: {e}")
            return None

    def _attach_deployment_policies(self, role_name):
        """
        Attach comprehensive deployment policies to the role
        """
        policies = [
            {
                'name': 'DeploymentFullAccess',
                'document': {
                    "Version": "2012-10-17",
                    "Statement": [
                        {
                            "Effect": "Allow",
                            "Action": [
                                "ecs:*",
                                "ecr:*",
                                "s3:*",
                                "cloudformation:*",
                                "logs:*"
                            ],
                            "Resource": "*"
                        }
                    ]
                }
            },
            {
                'name': 'SecretsManagerAccess',
                'document': {
                    "Version": "2012-10-17",
                    "Statement": [
                        {
                            "Effect": "Allow",
                            "Action": [
                                "secretsmanager:GetSecretValue",
                                "secretsmanager:DescribeSecret"
                            ],
                            "Resource": "*"
                        }
                    ]
                }
            }
        ]

        for policy in policies:
            try:
                policy_arn = self._create_policy(role_name + policy['name'], policy['document'])
                self.iam_client.attach_role_policy(
                    RoleName=role_name,
                    PolicyArn=policy_arn
                )
            except ClientError as e:
                print(f"Error attaching policy {policy['name']}: {e}")

    def _create_policy(self, policy_name, policy_document):
        """
        Create a custom IAM policy
        """
        response = self.iam_client.create_policy(
            PolicyName=policy_name,
            PolicyDocument=json.dumps(policy_document)
        )
        return response['Policy']['Arn']

def main():
    role_manager = IAMRoleManager()
    
    # Create roles for different components
    roles = [
        {
            'name': 'DeploymentServiceRole',
            'services': ['ecs-tasks.amazonaws.com', 'codedeploy.amazonaws.com']
        },
        {
            'name': 'JenkinsDeploymentRole',
            'services': ['ec2.amazonaws.com']
        }
    ]

    for role in roles:
        role_arn = role_manager.create_deployment_role(role['name'], role['services'])
        print(f"Created role {role['name']}: {role_arn}")

if __name__ == '__main__':
    main()