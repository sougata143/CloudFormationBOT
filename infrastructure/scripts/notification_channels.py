import os
import json
import requests
import yaml
import boto3
from typing import Dict, Any

class MultiChannelNotifier:
    def __init__(self, config_path: str = None):
        """
        Initialize Multi-Channel Notifier
        
        :param config_path: Path to monitoring configuration
        """
        # Load configuration
        if config_path is None:
            config_path = os.path.join(
                os.path.dirname(__file__), 
                '../config/monitoring_config.yaml'
            )
        
        with open(config_path, 'r') as config_file:
            self.config = yaml.safe_load(config_file)
        
        # Initialize clients
        self.sns_client = boto3.client('sns')
        self.ses_client = boto3.client('ses')
    
    def send_slack_notification(self, channel: str, message: str):
        """
        Send notification to Slack
        
        :param channel: Slack webhook channel
        :param message: Notification message
        """
        slack_webhooks = self.config.get('notifications', {}).get('slack', {}).get('webhooks', {})
        webhook_url = slack_webhooks.get(channel)
        
        if webhook_url and self.config['notifications']['slack']['enabled']:
            payload = {
                'text': message,
                'blocks': [
                    {
                        'type': 'section',
                        'text': {
                            'type': 'mrkdwn',
                            'text': message
                        }
                    }
                ]
            }
            
            try:
                response = requests.post(webhook_url, json=payload)
                response.raise_for_status()
            except requests.exceptions.RequestException as e:
                print(f"Slack notification failed: {e}")
    
    def send_pagerduty_alert(self, message: str, severity: str = 'critical'):
        """
        Send alert to PagerDuty
        
        :param message: Alert message
        :param severity: Alert severity
        """
        pagerduty_config = self.config.get('notifications', {}).get('pagerduty', {})
        
        if pagerduty_config.get('enabled'):
            payload = {
                'routing_key': pagerduty_config['service_key'],
                'event_action': 'trigger',
                'payload': {
                    'summary': message,
                    'severity': severity,
                    'source': 'CloudFormationBOT'
                }
            }
            
            try:
                response = requests.post(
                    'https://events.pagerduty.com/v2/enqueue', 
                    json=payload
                )
                response.raise_for_status()
            except requests.exceptions.RequestException as e:
                print(f"PagerDuty alert failed: {e}")
    
    def send_email_notification(self, subject: str, body: str):
        """
        Send email notification via AWS SES
        
        :param subject: Email subject
        :param body: Email body
        """
        email_endpoints = self.config.get('notifications', {}).get('email_endpoints', [])
        
        for email in email_endpoints:
            try:
                self.ses_client.send_email(
                    Source='noreply@company.com',
                    Destination={'ToAddresses': [email]},
                    Message={
                        'Subject': {'Data': subject},
                        'Body': {
                            'Text': {'Data': body},
                            'Html': {'Data': f'<html><body>{body}</body></html>'}
                        }
                    }
                )
            except Exception as e:
                print(f"Email notification to {email} failed: {e}")

def main():
    # Initialize multi-channel notifier
    notifier = MultiChannelNotifier()
    
    # Example notifications
    notifier.send_slack_notification(
        'cost_alerts', 
        'Daily cost exceeded $100: Current spend is $150'
    )
    
    notifier.send_pagerduty_alert(
        'S3 Replication Test Failed', 
        severity='critical'
    )
    
    notifier.send_email_notification(
        'Disaster Recovery Backup Alert',
        'Daily disaster recovery backup completed successfully.'
    )

if __name__ == '__main__':
    main()