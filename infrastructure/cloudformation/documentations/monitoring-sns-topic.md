# Monitoring SNS Topics CloudFormation Stack

## Overview
This CloudFormation stack creates SNS (Simple Notification Service) topics for various monitoring and alerting purposes.

## Parameters
- `Environment`: Deployment environment (dev/staging/prod)

## Resources Created
- Cost Optimization Alert Topic
- Replication Test Alert Topic
- Disaster Recovery Alert Topic

## Purpose
Create centralized notification channels for different monitoring and alerting scenarios across the microservices infrastructure.

## Resources Created
- **Cost Optimization Alert Topic**
  - Purpose: Notify team about potential cost inefficiencies
  - Triggers: 
    - Unexpected spending
    - Resource over-provisioning
    - Idle resources

- **Replication Test Alert Topic**
  - Purpose: Monitor data replication health
  - Triggers:
    - Replication failures
    - Latency in data synchronization
    - Inconsistent data states

- **Disaster Recovery Alert Topic**
  - Purpose: Immediate notifications for potential disaster scenarios
  - Triggers:
    - Backup failures
    - Data integrity issues
    - Recovery point objective (RPO) violations

## Utilization Strategies
1. Subscribe relevant team members via email/SMS
2. Integrate with monitoring dashboards
3. Configure automatic remediation actions
4. Set up escalation policies

## Best Practices
- Use least-privilege IAM roles
- Implement message filtering
- Rotate topic access credentials
- Enable encryption at rest

## Monitoring and Compliance
- CloudTrail logging for topic access
- Encryption using AWS KMS
- Comprehensive audit trails

## Outputs
- Cost Optimization Alert Topic ARN
- Replication Test Alert Topic ARN
- Disaster Recovery Alert Topic ARN

## Usage
Deploy using AWS CloudFormation CLI or management console with the specified environment.

## Best Practices
- Use different topics for different alert types
- Configure appropriate subscriptions
- Set up IAM roles with least privilege