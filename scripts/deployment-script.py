import os
import boto3
from botocore.exceptions import ClientError

class MicroserviceDeployment:
    def __init__(self, environment):
        self.environment = environment
        self.ecs_client = boto3.client('ecs')
        self.ecr_client = boto3.client('ecr')

    def get_latest_image_tag(self, repository_name):
        """
        Retrieve the latest image tag from ECR
        """
        try:
            response = self.ecr_client.describe_images(
                repositoryName=repository_name,
                filter={'tagStatus': 'TAGGED'},
                sort={'field': 'PUSHED_AT', 'order': 'DESCENDING'}
            )
            return response['imageDetails'][0]['imageTags'][0]
        except ClientError as e:
            print(f"Error retrieving image tag: {e}")
            return None

    def update_ecs_service(self, cluster_name, service_name, repository_name):
        """
        Update ECS service with the latest image
        """
        image_tag = self.get_latest_image_tag(repository_name)
        
        if not image_tag:
            print("No image tag found. Deployment aborted.")
            return False

        try:
            # Get current task definition
            task_definition = self.ecs_client.describe_task_definition(
                taskDefinition=f'{service_name}-task'
            )

            # Update task definition with new image
            new_task_definition = self.ecs_client.register_task_definition(
                family=task_definition['taskDefinition']['family'],
                containerDefinitions=[
                    {
                        **container,
                        'image': f'{repository_name}:{image_tag}'
                    } for container in task_definition['taskDefinition']['containerDefinitions']
                ]
            )

            # Update service
            self.ecs_client.update_service(
                cluster=cluster_name,
                service=service_name,
                taskDefinition=new_task_definition['taskDefinition']['taskDefinitionArn']
            )

            print(f"Successfully deployed {service_name} with image {image_tag}")
            return True

        except ClientError as e:
            print(f"Deployment error: {e}")
            return False

    def deploy_microservices(self):
        """
        Deploy all microservices
        """
        microservices = [
            {
                'cluster': f'{self.environment}-cluster',
                'service': 'backend-service',
                'repository': 'backend-microservice'
            },
            {
                'cluster': f'{self.environment}-cluster',
                'service': 'frontend-service',
                'repository': 'frontend-angular'
            }
        ]

        for service in microservices:
            self.update_ecs_service(
                service['cluster'], 
                service['service'], 
                service['repository']
            )

def main():
    deployment = MicroserviceDeployment('production')
    deployment.deploy_microservices()

if __name__ == '__main__':
    main()