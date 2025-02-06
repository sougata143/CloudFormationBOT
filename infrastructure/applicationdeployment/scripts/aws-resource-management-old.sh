#!/bin/bash

# AWS Resource Management Script
# Author: Cascade AI Assistant
# Purpose: Comprehensive AWS resource management tool

# Configurable Variables
ENVIRONMENT="dev"  # Change this to match your environment
REGION="us-east-1"  # Change to your preferred region
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$HOME/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/applicationdeployment/logs/aws_resource_management_${TIMESTAMP}.log"
RESOURCES_TABLE="$HOME/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/applicationdeployment/logs/aws_resources_${TIMESTAMP}.md"

# Logging Function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Error Handling Function
handle_error() {
    log "ERROR: $*"
    exit 1
}

# Create Markdown Table Header
create_table_header() {
    echo "# AWS Resources Inventory for Environment: $ENVIRONMENT" > "$RESOURCES_TABLE"
    echo "" >> "$RESOURCES_TABLE"
}

# Additional Resource Types to Add
additional_resource_types() {
    # Elastic Container Service (ECS)
    echo "## ECS Clusters" >> "$RESOURCES_TABLE"
    echo "| Cluster Name | Status | Active Services | Registered Instances |" >> "$RESOURCES_TABLE"
    echo "|-------------|--------|----------------|---------------------|" >> "$RESOURCES_TABLE"
    aws ecs list-clusters --region "$REGION" \
        --query "clusterArns[?contains(@, '$ENVIRONMENT')]" \
        --output json | jq -r '.[]' | while read -r cluster_arn; do
            cluster_name=$(echo "$cluster_arn" | awk -F/ '{print $NF}')
            services_count=$(aws ecs list-services --cluster "$cluster_arn" --region "$REGION" --query "length(serviceArns)" --output text)
            container_instances=$(aws ecs list-container-instances --cluster "$cluster_arn" --region "$REGION" --query "length(containerInstanceArns)" --output text)
            echo "| $cluster_name | Active | $services_count | $container_instances |" >> "$RESOURCES_TABLE"
        done
    echo "" >> "$RESOURCES_TABLE"

    # Elastic Kubernetes Service (EKS)
    echo "## EKS Clusters" >> "$RESOURCES_TABLE"
    echo "| Cluster Name | Version | Status | Endpoint | Nodes |" >> "$RESOURCES_TABLE"
    echo "|-------------|---------|--------|----------|-------|" >> "$RESOURCES_TABLE"
    aws eks list-clusters --region "$REGION" \
        --query "clusters[?contains(@, '$ENVIRONMENT')]" \
        --output json | jq -r '.[]' | while read -r cluster; do
            cluster_info=$(aws eks describe-cluster --name "$cluster" --region "$REGION" --query "{Version: version, Status: status, Endpoint: endpoint}" --output json)
            nodes=$(aws eks list-nodegroups --cluster-name "$cluster" --region "$REGION" --query "length(nodegroups)" --output text)
            echo "| $cluster | $(echo "$cluster_info" | jq -r '.Version') | $(echo "$cluster_info" | jq -r '.Status') | $(echo "$cluster_info" | jq -r '.Endpoint') | $nodes |" >> "$RESOURCES_TABLE"
        done
    echo "" >> "$RESOURCES_TABLE"

    # Elastic Container Registry (ECR)
    echo "## Elastic Container Registry Repositories" >> "$RESOURCES_TABLE"
    echo "| Repository Name | URI | Image Count | Last Updated |" >> "$RESOURCES_TABLE"
    echo "|---------------|-----|-------------|--------------|" >> "$RESOURCES_TABLE"
    aws ecr describe-repositories --region "$REGION" \
        --query "repositories[?contains(repositoryName, '$ENVIRONMENT')].{Name: repositoryName, URI: repositoryUri}" \
        --output json | jq -r '.[] | "| \(.Name) | \(.URI) | - | - |"' >> "$RESOURCES_TABLE"
    echo "" >> "$RESOURCES_TABLE"

    # API Gateway
    echo "## API Gateway" >> "$RESOURCES_TABLE"
    echo "| API Name | Stage | Method | Resource Path | Status |" >> "$RESOURCES_TABLE"
    echo "|----------|-------|--------|--------------|--------|" >> "$RESOURCES_TABLE"
    aws apigateway get-rest-apis --region "$REGION" \
        --query "items[?contains(name, '$ENVIRONMENT')].{Name: name, Id: id}" \
        --output json | jq -r '.[] | .Id' | while read -r api_id; do
            api_name=$(aws apigateway get-rest-api --rest-api-id "$api_id" --region "$REGION" --query "name" --output text)
            stages=$(aws apigateway get-stages --rest-api-id "$api_id" --region "$REGION" --query "item[*].stageName" --output json)
            echo "| $api_name | $stages | - | - | - |" >> "$RESOURCES_TABLE"
        done
    echo "" >> "$RESOURCES_TABLE"

    # Step Functions
    echo "## Step Functions" >> "$RESOURCES_TABLE"
    echo "| State Machine Name | Type | Status | Creation Date |" >> "$RESOURCES_TABLE"
    echo "|------------------|------|--------|---------------|" >> "$RESOURCES_TABLE"
    aws stepfunctions list-state-machines --region "$REGION" \
        --query "stateMachines[?contains(name, '$ENVIRONMENT')].{Name: name, Arn: stateMachineArn}" \
        --output json | jq -r '.[] | .Arn' | while read -r state_machine_arn; do
            details=$(aws stepfunctions describe-state-machine --state-machine-arn "$state_machine_arn" --region "$REGION" --query "{Name: name, Type: type}" --output json)
            echo "| $(echo "$details" | jq -r '.Name') | $(echo "$details" | jq -r '.Type') | - | - |" >> "$RESOURCES_TABLE"
        done
    echo "" >> "$RESOURCES_TABLE"

    # Elastic Beanstalk Applications
    echo "## Elastic Beanstalk Applications" >> "$RESOURCES_TABLE"
    echo "| Application Name | Environments | Versions | Last Updated |" >> "$RESOURCES_TABLE"
    echo "|-----------------|--------------|----------|--------------|" >> "$RESOURCES_TABLE"
    aws elasticbeanstalk describe-applications --region "$REGION" \
        --query "Applications[?contains(ApplicationName, '$ENVIRONMENT')].ApplicationName" \
        --output text | while read -r app_name; do
            environments=$(aws elasticbeanstalk describe-environments --application-name "$app_name" --region "$REGION" --query "length(Environments)" --output text)
            versions=$(aws elasticbeanstalk describe-application-versions --application-name "$app_name" --region "$REGION" --query "length(ApplicationVersions)" --output text)
            echo "| $app_name | $environments | $versions | - |" >> "$RESOURCES_TABLE"
        done
    echo "" >> "$RESOURCES_TABLE"

    # Elastic File System (EFS)
    echo "## Elastic File Systems" >> "$RESOURCES_TABLE"
    echo "| File System ID | Size (GB) | Performance Mode | Throughput Mode | Encrypted |" >> "$RESOURCES_TABLE"
    echo "|---------------|-----------|-----------------|-----------------|-----------|" >> "$RESOURCES_TABLE"
    aws efs describe-file-systems --region "$REGION" \
        --query "FileSystems[?contains(Name, '$ENVIRONMENT')].{Id: FileSystemId, Size: SizeInBytes, PerformanceMode: PerformanceMode, ThroughputMode: ThroughputMode}" \
        --output json | jq -r '.[] | "| \(.Id) | \(.Size / 1024 / 1024 / 1024) | \(.PerformanceMode) | \(.ThroughputMode) | - |"' >> "$RESOURCES_TABLE"
    echo "" >> "$RESOURCES_TABLE"

    # Elastic Block Store (EBS) Volumes
    echo "## EBS Volumes" >> "$RESOURCES_TABLE"
    echo "| Volume ID | Size (GB) | Type | Availability Zone | Attached Instance |" >> "$RESOURCES_TABLE"
    echo "|----------|-----------|------|------------------|-------------------|" >> "$RESOURCES_TABLE"
    aws ec2 describe-volumes --region "$REGION" \
        --filters "Name=tag:Environment,Values=$ENVIRONMENT" \
        --query "Volumes[*].{VolumeId: VolumeId, Size: Size, Type: VolumeType, AZ: AvailabilityZone, Attachments: Attachments[0].InstanceId}" \
        --output json | jq -r '.[] | "| \(.VolumeId) | \(.Size) | \(.Type) | \(.AZ) | \(.Attachments // "Not Attached") |"' >> "$RESOURCES_TABLE"
    echo "" >> "$RESOURCES_TABLE"
}

# Additional Advanced Resource Types
advanced_resource_types() {
    # AWS WAF (Web Application Firewall)
    echo "## AWS WAF Web ACLs" >> "$RESOURCES_TABLE"
    echo "| WAF Name | Type | Rules | Protection Status |" >> "$RESOURCES_TABLE"
    echo "|----------|------|-------|------------------|" >> "$RESOURCES_TABLE"
    aws wafv2 list-web-acls --scope REGIONAL --region "$REGION" \
        --query "WebACLs[?contains(Name, '$ENVIRONMENT')].{Name: Name, Id: Id}" \
        --output json | jq -r '.[] | .Id' | while read -r waf_id; do
            waf_name=$(aws wafv2 get-web-acl --id "$waf_id" --scope REGIONAL --region "$REGION" --query "WebACL.Name" --output text)
            rules_count=$(aws wafv2 get-web-acl --id "$waf_id" --scope REGIONAL --region "$REGION" --query "length(WebACL.Rules)" --output text)
            echo "| $waf_name | Regional | $rules_count | Active |" >> "$RESOURCES_TABLE"
        done
    echo "" >> "$RESOURCES_TABLE"

    # AWS Secrets Manager
    echo "## AWS Secrets Manager" >> "$RESOURCES_TABLE"
    echo "| Secret Name | Type | Last Rotated | Next Rotation |" >> "$RESOURCES_TABLE"
    echo "|------------|------|--------------|---------------|" >> "$RESOURCES_TABLE"
    aws secretsmanager list-secrets --region "$REGION" \
        --query "SecretList[?contains(Name, '$ENVIRONMENT')].{Name: Name, Type: SecretType}" \
        --output json | jq -r '.[] | "| \(.Name) | \(.Type) | - | - |"' >> "$RESOURCES_TABLE"
    echo "" >> "$RESOURCES_TABLE"

    # AWS AppSync GraphQL APIs
    echo "## AWS AppSync GraphQL APIs" >> "$RESOURCES_TABLE"
    echo "| API Name | API ID | Authentication | Visibility |" >> "$RESOURCES_TABLE"
    echo "|----------|--------|----------------|------------|" >> "$RESOURCES_TABLE"
    aws appsync list-graphql-apis --region "$REGION" \
        --query "graphqlApis[?contains(name, '$ENVIRONMENT')].{Name: name, Id: apiId, Auth: authenticationType}" \
        --output json | jq -r '.[] | "| \(.Name) | \(.Id) | \(.Auth) | - |"' >> "$RESOURCES_TABLE"
    echo "" >> "$RESOURCES_TABLE"

    # AWS Transfer Family (SFTP/FTPS Servers)
    echo "## AWS Transfer Family Servers" >> "$RESOURCES_TABLE"
    echo "| Server ID | Endpoint | Protocol | User Count |" >> "$RESOURCES_TABLE"
    echo "|----------|----------|----------|------------|" >> "$RESOURCES_TABLE"
    aws transfer list-servers --region "$REGION" \
        --query "Servers[?contains(ServerId, '$ENVIRONMENT')].{Id: ServerId, Endpoint: Endpoint, Protocol: Protocols[0]}" \
        --output json | jq -r '.[] | "| \(.Id) | \(.Endpoint) | \(.Protocol) | - |"' >> "$RESOURCES_TABLE"
    echo "" >> "$RESOURCES_TABLE"

    # AWS DataSync Tasks
    echo "## AWS DataSync Tasks" >> "$RESOURCES_TABLE"
    echo "| Task Name | Source | Destination | Status | Last Run |" >> "$RESOURCES_TABLE"
    echo "|----------|--------|-------------|--------|----------|" >> "$RESOURCES_TABLE"
    aws datasync list-tasks --region "$REGION" \
        --query "Tasks[?contains(Name, '$ENVIRONMENT')].{Name: Name, SourceLocationArn: SourceLocationArn, DestinationLocationArn: DestinationLocationArn}" \
        --output json | jq -r '.[] | "| \(.Name) | \(.SourceLocationArn) | \(.DestinationLocationArn) | - | - |"' >> "$RESOURCES_TABLE"
    echo "" >> "$RESOURCES_TABLE"

    # AWS Glue Jobs and Crawlers
    echo "## AWS Glue Jobs" >> "$RESOURCES_TABLE"
    echo "| Job Name | Type | Last Run Status | Schedule |" >> "$RESOURCES_TABLE"
    echo "|----------|------|----------------|----------|" >> "$RESOURCES_TABLE"
    aws glue get-jobs --region "$REGION" \
        --query "Jobs[?contains(Name, '$ENVIRONMENT')].{Name: Name}" \
        --output json | jq -r '.[] | .Name' | while read -r job_name; do
            job_details=$(aws glue get-job --job-name "$job_name" --region "$REGION" --query "{Type: Command.Name}" --output json)
            echo "| $job_name | $(echo "$job_details" | jq -r '.Type') | - | - |" >> "$RESOURCES_TABLE"
        done
    echo "" >> "$RESOURCES_TABLE"
}

# Fetch and List Resources Function
list_resources() {
    # Create table header
    create_table_header

    log "Comprehensive AWS Resources Listing..."

    additional_resource_types
    advanced_resource_types

    # CloudFormation Stacks
    log "Fetching CloudFormation Stacks..."
    echo "## CloudFormation Stacks" >> "$RESOURCES_TABLE"
    echo "| Stack Name | Status | Creation Time | Description |" >> "$RESOURCES_TABLE"
    echo "|-----------|--------|--------------|-------------|" >> "$RESOURCES_TABLE"
    aws cloudformation describe-stacks --region "$REGION" \
        --query "Stacks[?Tags[?Key=='Environment'=='$ENVIRONMENT']].{StackName: StackName, Status: StackStatus, CreationTime: CreationTime, Description: Description}" \
        --output json | jq -r '.[] | "| \(.StackName) | \(.Status) | \(.CreationTime) | \(.Description // "-") |"' >> "$RESOURCES_TABLE" || 
        handle_error "Failed to list CloudFormation stacks"
    echo "" >> "$RESOURCES_TABLE"

    # Compute Resources
    log "Fetching Compute Resources..."
    
    # EC2 Instances
    echo "## EC2 Instances" >> "$RESOURCES_TABLE"
    echo "| Instance ID | State | Type | Public IP | Private IP | Launch Time |" >> "$RESOURCES_TABLE"
    echo "|------------|-------|------|-----------|------------|-------------|" >> "$RESOURCES_TABLE"
    aws ec2 describe-instances --region "$REGION" \
        --filters "Name=tag:Environment,Values=$ENVIRONMENT" \
        --query "Reservations[*].Instances[*].{InstanceId: InstanceId, State: State.Name, Type: InstanceType, PublicIP: PublicIpAddress, PrivateIP: PrivateIpAddress, LaunchTime: LaunchTime}" \
        --output json | jq -r '.[][] | "| \(.InstanceId) | \(.State) | \(.Type) | \(.PublicIP // "N/A") | \(.PrivateIP // "N/A") | \(.LaunchTime) |"' >> "$RESOURCES_TABLE" || 
        handle_error "Failed to list EC2 instances"
    echo "" >> "$RESOURCES_TABLE"

    # Auto Scaling Groups
    echo "## Auto Scaling Groups" >> "$RESOURCES_TABLE"
    echo "| ASG Name | Desired | Min | Max | Launch Config | Status |" >> "$RESOURCES_TABLE"
    echo "|----------|---------|-----|-----|--------------|--------|" >> "$RESOURCES_TABLE"
    aws autoscaling describe-auto-scaling-groups --region "$REGION" \
        --query "AutoScalingGroups[?contains(Tags[?Key=='Environment'].Value, '$ENVIRONMENT')].{Name: AutoScalingGroupName, Desired: DesiredCapacity, Min: MinSize, Max: MaxSize, LaunchConfig: LaunchConfigurationName, Status: Status}" \
        --output json | jq -r '.[] | "| \(.Name) | \(.Desired) | \(.Min) | \(.Max) | \(.LaunchConfig // "-") | \(.Status // "-") |"' >> "$RESOURCES_TABLE" || 
        handle_error "Failed to list Auto Scaling Groups"
    echo "" >> "$RESOURCES_TABLE"

    # Lambda Functions
    echo "## Lambda Functions" >> "$RESOURCES_TABLE"
    echo "| Function Name | Runtime | Handler | Role | Last Modified |" >> "$RESOURCES_TABLE"
    echo "|--------------|---------|---------|------|--------------|" >> "$RESOURCES_TABLE"
    aws lambda list-functions --region "$REGION" \
        --query "Functions[?contains(FunctionName, '$ENVIRONMENT')].{Name: FunctionName, Runtime: Runtime, Handler: Handler, Role: Role, LastModified: LastModified}" \
        --output json | jq -r '.[] | "| \(.Name) | \(.Runtime) | \(.Handler) | \(.Role) | \(.LastModified) |"' >> "$RESOURCES_TABLE" || 
        handle_error "Failed to list Lambda functions"
    echo "" >> "$RESOURCES_TABLE"

    # Networking Resources
    log "Fetching Networking Resources..."
    
    # VPCs
    echo "## VPCs" >> "$RESOURCES_TABLE"
    echo "| VPC ID | CIDR | State | Is Default | Tags |" >> "$RESOURCES_TABLE"
    echo "|--------|------|-------|------------|------|" >> "$RESOURCES_TABLE"
    aws ec2 describe-vpcs --region "$REGION" \
        --filters "Name=tag:Environment,Values=$ENVIRONMENT" \
        --query "Vpcs[*].{VpcId: VpcId, CidrBlock: CidrBlock, State: State, IsDefault: IsDefault, Tags: Tags}" \
        --output json | jq -r '.[] | "| \(.VpcId) | \(.CidrBlock) | \(.State) | \(.IsDefault) | \(.Tags | map(.Key + ":" + .Value) | join(", ")) |"' >> "$RESOURCES_TABLE" || 
        handle_error "Failed to list VPCs"
    echo "" >> "$RESOURCES_TABLE"

    # Subnets
    echo "## Subnets" >> "$RESOURCES_TABLE"
    echo "| Subnet ID | VPC ID | CIDR | Availability Zone | Type |" >> "$RESOURCES_TABLE"
    echo "|----------|--------|------|------------------|------|" >> "$RESOURCES_TABLE"
    aws ec2 describe-subnets --region "$REGION" \
        --filters "Name=tag:Environment,Values=$ENVIRONMENT" \
        --query "Subnets[*].{SubnetId: SubnetId, VpcId: VpcId, CidrBlock: CidrBlock, AZ: AvailabilityZone, Type: MapPublicIpOnLaunch}" \
        --output json | jq -r '.[] | "| \(.SubnetId) | \(.VpcId) | \(.CidrBlock) | \(.AZ) | \(.Type) |"' >> "$RESOURCES_TABLE" || 
        handle_error "Failed to list Subnets"
    echo "" >> "$RESOURCES_TABLE"

    # Load Balancers
    echo "## Load Balancers" >> "$RESOURCES_TABLE"
    echo "| LB Name | Type | Scheme | VPC ID | State |" >> "$RESOURCES_TABLE"
    echo "|---------|------|--------|--------|-------|" >> "$RESOURCES_TABLE"
    aws elbv2 describe-load-balancers --region "$REGION" \
        --query "LoadBalancers[?contains(LoadBalancerName, '$ENVIRONMENT')].{Name: LoadBalancerName, Type: Type, Scheme: Scheme, VpcId: VpcId, State: State.Code}" \
        --output json | jq -r '.[] | "| \(.Name) | \(.Type) | \(.Scheme) | \(.VpcId) | \(.State) |"' >> "$RESOURCES_TABLE" || 
        handle_error "Failed to list Load Balancers"
    echo "" >> "$RESOURCES_TABLE"

    # Storage Resources
    log "Fetching Storage Resources..."
    
    # S3 Buckets
    echo "## S3 Buckets" >> "$RESOURCES_TABLE"
    echo "| Bucket Name | Region | Creation Date | Versioning | Encryption |" >> "$RESOURCES_TABLE"
    echo "|------------|--------|--------------|------------|------------|" >> "$RESOURCES_TABLE"
    aws s3api list-buckets \
        --query "Buckets[?contains(Name, '$ENVIRONMENT')].{Name: Name}" \
        --output json | jq -r '.[] | "| \(.Name) | - | - | - | - |"' >> "$RESOURCES_TABLE" || 
        handle_error "Failed to list S3 buckets"
    echo "" >> "$RESOURCES_TABLE"

    # RDS Databases
    echo "## RDS Databases" >> "$RESOURCES_TABLE"
    echo "| DB Identifier | Engine | Version | Status | Endpoint |" >> "$RESOURCES_TABLE"
    echo "|--------------|--------|---------|--------|----------|" >> "$RESOURCES_TABLE"
    aws rds describe-db-instances --region "$REGION" \
        --query "DBInstances[?contains(DBInstanceIdentifier, '$ENVIRONMENT')].{Identifier: DBInstanceIdentifier, Engine: Engine, Version: EngineVersion, Status: DBInstanceStatus, Endpoint: Endpoint.Address}" \
        --output json | jq -r '.[] | "| \(.Identifier) | \(.Engine) | \(.Version) | \(.Status) | \(.Endpoint // "N/A") |"' >> "$RESOURCES_TABLE" || 
        handle_error "Failed to list RDS instances"
    echo "" >> "$RESOURCES_TABLE"

    # DynamoDB Tables
    echo "## DynamoDB Tables" >> "$RESOURCES_TABLE"
    echo "| Table Name | Status | Primary Key | Secondary Indexes |" >> "$RESOURCES_TABLE"
    echo "|-----------|--------|-------------|-------------------|" >> "$RESOURCES_TABLE"
    aws dynamodb list-tables --region "$REGION" \
        --query "TableNames[?contains(@, '$ENVIRONMENT')]" \
        --output json | jq -r '.[] | "| \(.) | - | - | - |"' >> "$RESOURCES_TABLE" || 
        handle_error "Failed to list DynamoDB tables"
    echo "" >> "$RESOURCES_TABLE"

    # Security and Monitoring
    log "Fetching Security and Monitoring Resources..."
    
    # Security Groups
    echo "## Security Groups" >> "$RESOURCES_TABLE"
    echo "| Group ID | Group Name | Description | VPC ID |" >> "$RESOURCES_TABLE"
    echo "|----------|------------|-------------|--------|" >> "$RESOURCES_TABLE"
    aws ec2 describe-security-groups --region "$REGION" \
        --filters "Name=tag:Environment,Values=$ENVIRONMENT" \
        --query "SecurityGroups[*].{GroupId: GroupId, GroupName: GroupName, Description: Description, VpcId: VpcId}" \
        --output json | jq -r '.[] | "| \(.GroupId) | \(.GroupName) | \(.Description) | \(.VpcId) |"' >> "$RESOURCES_TABLE" || 
        handle_error "Failed to list Security Groups"
    echo "" >> "$RESOURCES_TABLE"

    # CloudWatch Alarms
    echo "## CloudWatch Alarms" >> "$RESOURCES_TABLE"
    echo "| Alarm Name | Metric | Threshold | Status |" >> "$RESOURCES_TABLE"
    echo "|-----------|--------|-----------|--------|" >> "$RESOURCES_TABLE"
    aws cloudwatch describe-alarms --region "$REGION" \
        --query "MetricAlarms[?contains(AlarmName, '$ENVIRONMENT')].{Name: AlarmName, Metric: MetricName, Threshold: Threshold, Status: StateValue}" \
        --output json | jq -r '.[] | "| \(.Name) | \(.Metric) | \(.Threshold) | \(.Status) |"' >> "$RESOURCES_TABLE" || 
        handle_error "Failed to list CloudWatch Alarms"
    echo "" >> "$RESOURCES_TABLE"

    # Print locations of generated files
    log "Comprehensive resources inventory generated:"
    log "- Detailed log: $LOG_FILE"
    log "- Resources table: $RESOURCES_TABLE"

    # Display the table contents
    cat "$RESOURCES_TABLE"
}

# Remove Resources Function
remove_resources() {
    local environment="${1:-dev}"
    local region="${2:-us-east-1}"
    
    # Logging setup
    local log_dir="${HOME}/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/applicationdeployment/logs"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local log_file="${log_dir}/resource_cleanup_${timestamp}.log"
    
    mkdir -p "$log_dir"
    touch "$log_file"
    
    # Enhanced logging function
    log_message() {
        local level="${1}"
        local message="${2}"
        local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        echo "[${timestamp}] [${level}] ${message}" | tee -a "$log_file"
    }

    # Resource Types to Clean Up (Expanded List)
    local resource_types=(
        "ec2:security-group"
        "ec2:subnet"
        "ec2:vpc"
        "ec2:internet-gateway"
        "ec2:nat-gateway"
        "ec2:route-table"
        "elasticloadbalancingv2:targetgroup"
        "elasticloadbalancingv2:loadbalancer"
        "autoscaling:autoScalingGroup"
        "lambda:function"
        "s3:bucket"
        "sns:topic"
        "cloudwatch:alarm"
        "iam:role"
    )

    log_message "INFO" "Starting resource cleanup for environment: ${environment}"
    log_message "INFO" "Cleanup log will be saved to: ${log_file}"

    # Comprehensive Resource Deletion
    for resource_type in "${resource_types[@]}"; do
        IFS=':' read -r service resource <<< "$resource_type"
        
        log_message "INFO" "Processing ${service} ${resource} resources..."
        
        case "$service" in
            "ec2")
                case "$resource" in
                    "security-group")
                        # Delete security groups created by CloudFormation
                        aws ec2 describe-security-groups \
                            --filters "Name=tag:Environment,Values=${environment}" \
                            --query "SecurityGroups[*].GroupId" \
                            --output text | while read -r sg_id; do
                                if [[ -n "$sg_id" ]]; then
                                    log_message "WARN" "Deleting Security Group: ${sg_id}"
                                    aws ec2 delete-security-group --group-id "$sg_id" || 
                                        log_message "ERROR" "Failed to delete Security Group ${sg_id}"
                                fi
                            done
                        ;;
                    "subnet")
                        # Delete subnets
                        aws ec2 describe-subnets \
                            --filters "Name=tag:Environment,Values=${environment}" \
                            --query "Subnets[*].SubnetId" \
                            --output text | while read -r subnet_id; do
                                if [[ -n "$subnet_id" ]]; then
                                    log_message "WARN" "Deleting Subnet: ${subnet_id}"
                                    aws ec2 delete-subnet --subnet-id "$subnet_id" || 
                                        log_message "ERROR" "Failed to delete Subnet ${subnet_id}"
                                fi
                            done
                        ;;
                    # Add more EC2 resource type handlers
                esac
                ;;
            "elasticloadbalancingv2")
                case "$resource" in
                    "targetgroup")
                        # Delete target groups
                        aws elbv2 describe-target-groups \
                            --names "*${environment}*" \
                            --query "TargetGroups[*].TargetGroupArn" \
                            --output text | while read -r tg_arn; do
                                if [[ -n "$tg_arn" ]]; then
                                    log_message "WARN" "Deleting Target Group: ${tg_arn}"
                                    aws elbv2 delete-target-group --target-group-arn "$tg_arn" || 
                                        log_message "ERROR" "Failed to delete Target Group ${tg_arn}"
                                fi
                            done
                        ;;
                    # Add more Load Balancer resource type handlers
                esac
                ;;
            # Add more service handlers
        esac
    done

    log_message "INFO" "Resource cleanup completed for environment: ${environment}"
    
    # Optional: Provide summary of deleted resources
    log_message "SUMMARY" "Please review the log file at ${log_file} for detailed cleanup information"
}

# Main Script Logic
main() {
    # Check AWS CLI is installed
    command -v aws >/dev/null 2>&1 || handle_error "AWS CLI is not installed"
    command -v jq >/dev/null 2>&1 || handle_error "jq is not installed"
    
    case "$1" in
        list)
            list_resources
            ;;
        remove)
            remove_resources
            ;;
        *)
            echo "Usage: $0 {list|remove}"
            exit 1
            ;;
    esac
}

# Execute main function with arguments
main "$@"