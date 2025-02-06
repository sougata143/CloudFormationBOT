# Comprehensive AWS CloudFormation Deployment Infrastructure

## Overview

This CloudFormation deployment infrastructure provides a robust, scalable, and secure solution for deploying application infrastructure on AWS. The project includes advanced networking, load balancing, auto scaling, security scanning, and disaster recovery mechanisms.

## 🚀 Key Features

### 1. Infrastructure Deployment
- Fully automated AWS CloudFormation stack deployment
- Configurable network architecture
- Multi-environment support (dev, staging, prod)

### 2. Networking
- Custom VPC with public and private subnets
- Configurable CIDR blocks
- Network security groups and ACLs
- Internet Gateway and NAT Gateway configuration

### 3. Compute Resources
- Auto Scaling Group for EC2 instances
- Configurable instance types and capacities
- Launch Templates for consistent instance configuration
- Application Load Balancer for traffic distribution

### 4. Security Enhancements
- AWS Config Rules for continuous monitoring
- GuardDuty threat detection
- AWS Inspector for vulnerability scanning
- Security Hub for centralized security management
- Automated security notifications

### 5. Disaster Recovery
- AWS Backup Vault with daily EC2 backups
- KMS encryption for backup data
- S3 Cross-Region Replication
- Disaster recovery simulation
- Automated instance health monitoring

### 6. Monitoring and Logging
- CloudWatch Dashboards
- Performance and resource utilization metrics
- SNS notifications for critical events
- CloudTrail for audit and compliance logging

## 🔧 Prerequisites

- AWS CLI installed and configured
- AWS Account with necessary permissions
- SSH Key Pair for EC2 instances
- Bash shell (macOS/Linux)

## 🛠 Configuration Parameters

### Network Configuration
- `VpcCIDR`: VPC IP range
- `PublicSubnet1CIDR`: First public subnet IP range
- `PublicSubnet2CIDR`: Second public subnet IP range
- `PrivateSubnet1CIDR`: First private subnet IP range
- `PrivateSubnet2CIDR`: Second private subnet IP range

### Compute Configuration
- `InstanceType`: EC2 instance type (default: t3.medium)
- `KeyPairName`: SSH key pair name
- `MinSize`: Minimum number of instances
- `MaxSize`: Maximum number of instances
- `DesiredCapacity`: Initial number of instances

### Environment Configuration
- `Environment`: Deployment environment (dev/staging/prod)
- `AlertEmailAddress`: Email for notifications

## 📦 Deployment Steps

1. Clone the repository
```bash
git clone <repository-url>
cd infrastructure/applicationdeployment
```

2. Configure AWS CLI
```bash
aws configure
```

3. Make Deployment Script Executable
```bash
chmod +x scripts/application-deployment-stack.sh
```

4. Update Configuration Parameters
```bash
vi scripts/application-deployment-stack.sh
```

5. Run Deployment Script
```bash
./scripts/application-deployment-stack.sh
```

## 📊 Monitoring and Alerts
The infrastructure includes comprehensive monitoring:

EC2 instance performance metrics
Auto Scaling Group health checks
Security vulnerability alerts
Disaster recovery notifications

## 🛡️ Disaster Recovery
### Automated mechanisms:

Daily EC2 instance backups
Cross-Region S3 data replication
Automatic unhealthy instance replacement
Email notifications for critical events

## 📝 Customization
Modify cloudformation/application-deployment-stack.yaml to:

Adjust network configurations
Change instance types
Update security settings
Customize monitoring thresholds

## 🔍 Troubleshooting
Check /var/log/cloudformation-deployments/ for detailed logs
Review CloudWatch Dashboards
Inspect SNS notification emails
Verify AWS Config and Security Hub findings

## 📄 License
[Specify your license here]

## 🤝 Contributing
Fork the repository
Create your feature branch
Commit your changes
Push to the branch
Create a Pull Request

## 📞 Support
For issues or questions, please create a GitHub issue