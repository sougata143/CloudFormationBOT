import json
import yaml
import boto3
from typing import Dict, List

class SecurityPlaybookManager:
    def __init__(self, playbooks_dir='./security_playbooks'):
        """
        Initialize Security Playbook Manager
        
        :param playbooks_dir: Directory containing security playbooks
        """
        self.playbooks_dir = playbooks_dir
        self.ssm_client = boto3.client('ssm')
        self.sns_client = boto3.client('sns')

    def load_playbooks(self) -> Dict[str, Dict]:
        """
        Load security playbooks from YAML files
        
        :return: Dictionary of playbooks
        """
        playbooks = {}
        
        # Implement playbook loading logic
        playbook_files = [
            'data_breach_response.yaml',
            'unauthorized_access.yaml',
            'malware_detection.yaml'
        ]
        
        for filename in playbook_files:
            try:
                with open(f'{self.playbooks_dir}/{filename}', 'r') as f:
                    playbook = yaml.safe_load(f)
                    playbooks[playbook['name']] = playbook
            except Exception as e:
                print(f"Error loading playbook {filename}: {e}")
        
        return playbooks

    def create_ssm_automation_documents(self, playbooks: Dict[str, Dict]):
        """
        Create SSM Automation documents for each playbook
        
        :param playbooks: Dictionary of security playbooks
        """
        for name, playbook in playbooks.items():
            try:
                self.ssm_client.create_document(
                    Name=f'SecurityPlaybook-{name}',
                    DocumentType='Automation',
                    Content=json.dumps({
                        'schemaVersion': '0.3',
                        'description': playbook.get('description', ''),
                        'parameters': playbook.get('parameters', {}),
                        'mainSteps': [
                            {
                                'name': step['name'],
                                'action': step['action'],
                                'inputs': step.get('inputs', {})
                            } for step in playbook.get('steps', [])
                        ]
                    })
                )
            except Exception as e:
                print(f"Error creating SSM document for {name}: {e}")

    def trigger_incident_response(self, playbook_name: str, incident_details: Dict):
        """
        Trigger incident response playbook
        
        :param playbook_name: Name of the playbook to trigger
        :param incident_details: Details of the security incident
        """
        try:
            # Execute SSM Automation
            response = self.ssm_client.start_automation_execution(
                DocumentName=f'SecurityPlaybook-{playbook_name}',
                Parameters=incident_details
            )

            # Send notification
            self.sns_client.publish(
                TopicArn='arn:aws:sns:us-west-2:123456789012:security-incidents',
                Message=json.dumps({
                    'playbook': playbook_name,
                    'incident_details': incident_details,
                    'execution_id': response['AutomationExecutionId']
                }),
                Subject=f'Security Playbook Triggered: {playbook_name}'
            )

            return response['AutomationExecutionId']
        
        except Exception as e:
            print(f"Error triggering playbook {playbook_name}: {e}")
            return None

def main():
    playbook_manager = SecurityPlaybookManager()
    
    # Load playbooks
    playbooks = playbook_manager.load_playbooks()
    
    # Create SSM Automation documents
    playbook_manager.create_ssm_automation_documents(playbooks)
    
    # Example incident response trigger
    incident_details = {
        'source_ip': '192.168.1.100',
        'affected_resource': 'microservice-backend',
        'severity': 'high'
    }
    
    playbook_manager.trigger_incident_response(
        'unauthorized_access', 
        incident_details
    )

if __name__ == '__main__':
    main()