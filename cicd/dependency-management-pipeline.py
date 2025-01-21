import os
import subprocess
import json
import requests
from datetime import datetime
import logging
from typing import Dict, List

class DependencyManagementPipeline:
    def __init__(self, 
                 github_token: str, 
                 repo_owner: str, 
                 repo_name: str, 
                 base_branch: str = 'main'):
        """
        Initialize Dependency Management Pipeline
        
        :param github_token: GitHub Personal Access Token
        :param repo_owner: GitHub repository owner
        :param repo_name: GitHub repository name
        :param base_branch: Base branch for pull requests
        """
        self.github_token = github_token
        self.repo_owner = repo_owner
        self.repo_name = repo_name
        self.base_branch = base_branch
        
        # Configure logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)

    def run_dependency_scan(self, requirements_file: str) -> Dict:
        """
        Run comprehensive dependency scan
        
        :param requirements_file: Path to requirements file
        :return: Scan report
        """
        try:
            # Run safety vulnerability scan
            result = subprocess.run(
                ['safety', 'check', '-r', requirements_file, '--output', 'json'],
                capture_output=True,
                text=True
            )
            
            vulnerabilities = json.loads(result.stdout)
            
            return {
                'timestamp': datetime.now().isoformat(),
                'total_dependencies': len(self._get_dependencies(requirements_file)),
                'vulnerabilities': vulnerabilities,
                'severity_summary': self._summarize_vulnerabilities(vulnerabilities)
            }
        
        except Exception as e:
            self.logger.error(f"Dependency scan error: {e}")
            return {}

    def _get_dependencies(self, requirements_file: str) -> List[str]:
        """
        Extract dependencies from requirements file
        
        :param requirements_file: Path to requirements file
        :return: List of dependencies
        """
        with open(requirements_file, 'r') as f:
            return [line.strip() for line in f if line.strip() and not line.startswith('#')]

    def _summarize_vulnerabilities(self, vulnerabilities: List[Dict]) -> Dict:
        """
        Summarize vulnerability severity
        
        :param vulnerabilities: List of vulnerabilities
        :return: Severity summary
        """
        severity_summary = {
            'critical': 0,
            'high': 0,
            'medium': 0,
            'low': 0
        }
        
        for vuln in vulnerabilities:
            severity = vuln.get('severity', 'low').lower()
            if severity in severity_summary:
                severity_summary[severity] += 1
        
        return severity_summary

    def create_dependency_update_branch(self, requirements_file: str) -> str:
        """
        Create a new branch for dependency updates
        
        :param requirements_file: Path to requirements file
        :return: New branch name
        """
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        branch_name = f"dependency-update-{timestamp}"
        
        try:
            # Create and checkout new branch
            subprocess.run(['git', 'checkout', '-b', branch_name], check=True)
            
            # Update dependencies
            self._update_dependencies(requirements_file)
            
            # Commit changes
            subprocess.run(['git', 'add', requirements_file], check=True)
            subprocess.run(['git', 'commit', '-m', f'Update dependencies in {requirements_file}'], check=True)
            
            return branch_name
        
        except Exception as e:
            self.logger.error(f"Branch creation error: {e}")
            return ''

    def _update_dependencies(self, requirements_file: str):
        """
        Update dependencies to latest versions
        
        :param requirements_file: Path to requirements file
        """
        try:
            with open(requirements_file, 'r') as f:
                requirements = [line.strip() for line in f if line.strip() and not line.startswith('#')]

            updated_requirements = []
            for req in requirements:
                package = req.split('==')[0]
                result = subprocess.run(
                    ['pip', 'index', 'versions', package],
                    capture_output=True,
                    text=True
                )
                latest_version = result.stdout.strip().split('\n')[0].split()[0]
                updated_requirements.append(f"{package}=={latest_version}")

            with open(requirements_file, 'w') as f:
                f.write('\n'.join(updated_requirements))
        
        except Exception as e:
            self.logger.error(f"Dependency update error: {e}")

    def create_github_pull_request(self, branch_name: str, requirements_file: str) -> Dict:
        """
        Create GitHub pull request for dependency updates
        
        :param branch_name: Name of the update branch
        :param requirements_file: Path to requirements file
        :return: Pull request details
        """
        try:
            # GitHub API endpoint
            url = f"https://api.github.com/repos/{self.repo_owner}/{self.repo_name}/pulls"
            
            # Pull request payload
            payload = {
                'title': f'Dependency Updates for {os.path.basename(requirements_file)}',
                'body': 'Automated dependency updates:\n'
                        '- Scanned and updated package versions\n'
                        '- Please review and merge carefully',
                'head': branch_name,
                'base': self.base_branch
            }
            
            # Send pull request
            headers = {
                'Authorization': f'token {self.github_token}',
                'Accept': 'application/vnd.github.v3+json'
            }
            
            response = requests.post(url, json=payload, headers=headers)
            response.raise_for_status()
            
            return response.json()
        
        except Exception as e:
            self.logger.error(f"Pull request creation error: {e}")
            return {}

    def send_slack_notification(self, scan_report: Dict, webhook_url: str):
        """
        Send Slack notification for vulnerability scan
        
        :param scan_report: Dependency scan report
        :param webhook_url: Slack webhook URL
        """
        try:
            severity_summary = scan_report.get('severity_summary', {})
            
            message = {
                'text': '*Dependency Vulnerability Scan Report*',
                'attachments': [
                    {
                        'color': 'danger' if severity_summary.get('critical', 0) > 0 else 'warning',
                        'fields': [
                            {
                                'title': 'Total Dependencies',
                                'value': scan_report.get('total_dependencies', 0),
                                'short': True
                            },
                            {
                                'title': 'Critical Vulnerabilities',
                                'value': severity_summary.get('critical', 0),
                                'short': True
                            },
                            {
                                'title': 'High Vulnerabilities',
                                'value': severity_summary.get('high', 0),
                                'short': True
                            }
                        ]
                    }
                ]
            }
            
            requests.post(webhook_url, json=message)
        
        except Exception as e:
            self.logger.error(f"Slack notification error: {e}")

def main():
    # Configuration
    github_token = os.environ.get('GITHUB_TOKEN')
    repo_owner = 'your-github-username'
    repo_name = 'CloudFormationBOT'
    slack_webhook_url = os.environ.get('SLACK_WEBHOOK_URL')

    # Initialize pipeline
    pipeline = DependencyManagementPipeline(
        github_token=github_token, 
        repo_owner=repo_owner, 
        repo_name=repo_name
    )

    # Scan requirements files
    production_scan = pipeline.run_dependency_scan(
        '/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/requirements/production.txt'
    )
    development_scan = pipeline.run_dependency_scan(
        '/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/requirements/development.txt'
    )

    # Create update branches and pull requests
    production_branch = pipeline.create_dependency_update_branch(
        '/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/requirements/production.txt'
    )
    development_branch = pipeline.create_dependency_update_branch(
        '/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/requirements/development.txt'
    )

    # Create pull requests
    if production_branch:
        pipeline.create_github_pull_request(
            production_branch, 
            '/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/requirements/production.txt'
        )
    
    if development_branch:
        pipeline.create_github_pull_request(
            development_branch, 
            '/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/requirements/development.txt'
        )

    # Send Slack notifications
    if slack_webhook_url:
        pipeline.send_slack_notification(production_scan, slack_webhook_url)
        pipeline.send_slack_notification(development_scan, slack_webhook_url)

if __name__ == '__main__':
    main()