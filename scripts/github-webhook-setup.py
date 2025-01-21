import os
import requests
from github import Github

def setup_github_webhooks(repo_name, webhook_url, secret):
    """
    Set up GitHub webhooks for CI/CD pipeline
    
    :param repo_name: GitHub repository name (e.g., 'username/repo')
    :param webhook_url: Jenkins webhook URL
    :param secret: Webhook secret for authentication
    """
    # GitHub authentication
    g = Github(os.environ.get('GITHUB_TOKEN'))
    
    # Get the repository
    repo = g.get_repo(repo_name)
    
    # Webhook configuration
    config = {
        'url': webhook_url,
        'content_type': 'json',
        'secret': secret,
        'insecure_ssl': '0'
    }
    
    # Events to trigger webhook
    events = [
        'push',
        'pull_request',
        'create',
        'delete'
    ]
    
    # Create webhook
    webhook = repo.create_hook(
        name='web',
        config=config,
        events=events,
        active=True
    )
    
    print(f"Webhook created for {repo_name}: {webhook.url}")

def main():
    # Repositories to set up webhooks
    repositories = [
        {
            'name': 'yourusername/backend-microservice',
            'webhook_url': 'https://jenkins.yourdomain.com/github-webhook/',
            'secret': os.environ.get('GITHUB_WEBHOOK_SECRET')
        },
        {
            'name': 'yourusername/frontend-angular',
            'webhook_url': 'https://jenkins.yourdomain.com/github-webhook/',
            'secret': os.environ.get('GITHUB_WEBHOOK_SECRET')
        }
    ]
    
    for repo_config in repositories:
        setup_github_webhooks(
            repo_config['name'], 
            repo_config['webhook_url'], 
            repo_config['secret']
        )

if __name__ == '__main__':
    main()