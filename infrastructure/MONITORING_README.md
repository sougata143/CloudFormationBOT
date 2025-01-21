# CloudFormation Monitoring Infrastructure

## Overview

This monitoring infrastructure provides a comprehensive solution for tracking, alerting, and managing AWS resources with a focus on cost optimization, disaster recovery, and performance monitoring.

## Architecture Components

### 1. Configuration Management
- **File**: [config/monitoring_config.yaml](cci:7://file:///Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/config/monitoring_config.yaml:0:0-0:0)
- Centralized configuration for all monitoring components
- Supports multiple environments (dev, staging, prod)

### 2. Notification Channels
- **File**: [scripts/notification_channels.py](cci:7://file:///Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/scripts/notification_channels.py:0:0-0:0)
- Multi-channel notification support:
  - Slack
  - PagerDuty
  - Email (AWS SES)

### 3. Granular Alerting
- **File**: [scripts/granular_alerting.py](cci:7://file:///Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/scripts/granular_alerting.py:0:0-0:0)
- Detailed monitoring for:
  - S3 Bucket Size
  - Replication Latency
  - Cost Anomalies

### 4. CloudFormation Templates
- **SNS Topics**: [cloudformation/monitoring-sns-topics.yaml](cci:7://file:///Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/cloudformation/monitoring-sns-topics.yaml:0:0-0:0)
- **Scheduled Jobs**: [cloudformation/monitoring-scheduled-jobs.yaml](cci:7://file:///Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/cloudformation/monitoring-scheduled-jobs.yaml:0:0-0:0)
- **Lambda Functions**: [cloudformation/monitoring-lambda-functions.yaml](cci:7://file:///Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/cloudformation/monitoring-lambda-functions.yaml:0:0-0:0)

## Configuration Guide

### Monitoring Configuration ([monitoring_config.yaml](cci:7://file:///Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/config/monitoring_config.yaml:0:0-0:0))

#### Global Settings
```yaml
global:
  environment: dev  # Current environment
  enabled: true     # Enable/disable monitoring
  log_level: INFO   # Logging verbosity

#### Notification Channels
```yaml
notifications:
  email_endpoints:
    - admin@company.com
    - devops@company.com
  slack:
    enabled: true
    webhooks:
      cost_alerts: 'https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX'
      replication_alerts: 'https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX'
      disaster_recovery: 'https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX'
  pagerduty:
    enabled: false
    service_key: 'your_pagerduty_service_integration_key'

#### Granular Alerting
```yaml
alert_rules:
  s3_bucket_size:
    warning_threshold_gb: 100
    critical_threshold_gb: 500
  
  replication_latency:
    warning_threshold_seconds: 1800
    critical_threshold_seconds: 3600

```

### Deployment Guide

Prerequirements:
- AWS CLI
- AWS SDK for Python (boto3)
- CloudFormation CLI

pip install boto3 pyyaml requests

### Deployment Steps
1. Configure AWS credentials
2. update config/monitoring_config.yaml
3. Deploy CloudFormation templates
4. Monitor and Alert

aws cloudformation create-stack \
  --stack-name monitoring-sns-topics \
  --template-body file://cloudformation/monitoring-sns-topics.yaml

## Monitoring and Alerting

### 1. Cost Optimization Alerts
    - Daily and monthly cost tracking
    - Configurable cost thresholds
    - Alerts for unexpected spending

### 2. S3 Replication Latency Alerts
    - Hourly replication tests
    - Latency tracking
    - Failure detection and alerting    

### 3. Disaster Recovery Alerts
    - Daily configuration backups
    - Retention policy management
    - Quick restoration capabilities

