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

# Comprehensive AWS Resource Types Dictionary
declare -A RESOURCE_TYPES=(
    # Compute Resources
    [EC2_INSTANCES]="aws ec2 describe-instances --query 'Reservations[*].Instances[?State.Name!='\''terminated'\''].{ID:InstanceId,Type:InstanceType,State:State.Name,LaunchTime:LaunchTime}' --output table"
    [EC2_VOLUMES]="aws ec2 describe-volumes --query 'Volumes[*].{ID:VolumeId,Size:Size,State:State,AttachmentState:Attachments[0].State}' --output table"
    [EC2_SNAPSHOTS]="aws ec2 describe-snapshots --owner-ids self --query 'Snapshots[*].{ID:SnapshotId,VolumeId:VolumeId,State:State,StartTime:StartTime}' --output table"
    [EC2_RESERVED_INSTANCES]="aws ec2 describe-reserved-instances --query 'ReservedInstances[*].{InstanceType:InstanceType,AvailabilityZone:AvailabilityZone,State:State,Duration:Duration}' --output table"
    [EC2_SPOT_INSTANCES]="aws ec2 describe-spot-instance-requests --query 'SpotInstanceRequests[*].{SpotInstanceRequestId:SpotInstanceRequestId,State:State,Type:Type,Price:SpotPrice}' --output table"
    [EC2_SECURITY_GROUPS]="aws ec2 describe-security-groups --query 'SecurityGroups[*].{GroupId:GroupId,GroupName:GroupName,Description:Description,VpcId:VpcId}' --output table"
    [EC2_SUBNETS]="aws ec2 describe-subnets --query 'Subnets[*].{SubnetId:SubnetId,VpcId:VpcId,CidrBlock:CidrBlock,AvailabilityZone:AvailabilityZone}' --output table"
    [EC2_VPCS]="aws ec2 describe-vpcs --query 'Vpcs[*].{VpcId:VpcId,CidrBlock:CidrBlock,IsDefault:IsDefault,State:State}' --output table"
    [EC2_NETWORK_INTERFACES]="aws ec2 describe-network-interfaces --query 'NetworkInterfaces[*].{NetworkInterfaceId:NetworkInterfaceId,SubnetId:SubnetId,VpcId:VpcId,Description:Description,Status:Status}' --output table"
    [EC2_ELASTIC_IPS]="aws ec2 describe-addresses --query 'Addresses[*].{PublicIp:PublicIp,AllocationId:AllocationId,Domain:Domain,NetworkInterfaceId:NetworkInterfaceId}' --output table"
    [EC2_ROUTE_TABLES]="aws ec2 describe-route-tables --query 'RouteTables[*].{RouteTableId:RouteTableId,VpcId:VpcId,Associations:Associations}' --output table"
    [EC2_INTERNET_GATEWAYS]="aws ec2 describe-internet-gateways --query 'InternetGateways[*].{InternetGatewayId:InternetGatewayId,Attachments:Attachments}' --output table"
    [EC2_NAT_GATEWAYS]="aws ec2 describe-nat-gateways --query 'NatGateways[*].{NatGatewayId:NatGatewayId,State:State,SubnetId:SubnetId,VpcId:VpcId}' --output table"

    # Container Resources
    [ECS_CLUSTERS]="aws ecs list-clusters --query 'clusterArns' --output text | xargs -n1 aws ecs describe-clusters --cluster"
    [ECS_SERVICES]="aws ecs list-services --cluster default --query 'serviceArns' --output text | xargs -n1 aws ecs describe-services --service"
    [ECS_TASK_DEFINITIONS]="aws ecs list-task-definitions --query 'taskDefinitionArns' --output json"
    [EKS_CLUSTERS]="aws eks list-clusters --query 'clusters' --output json"
    [EKS_NODEGROUPS]="aws eks list-nodegroups --cluster-name default --query 'nodegroups' --output json"
    [EKS_FARGATE_PROFILES]="aws eks list-fargate-profiles --cluster-name default --query 'fargateProfileNames' --output json"
    [ECR_REPOSITORIES]="aws ecr describe-repositories --query 'repositories[*].{RepositoryName:repositoryName,RepositoryUri:repositoryUri,CreatedAt:createdAt}' --output table"

    # Serverless Resources
    [LAMBDA_FUNCTIONS]="aws lambda list-functions --query 'Functions[*].{FunctionName:FunctionName,Runtime:Runtime,LastModified:LastModified,MemorySize:MemorySize}' --output table"
    [STEP_FUNCTIONS]="aws stepfunctions list-state-machines --query 'stateMachines[*].{Arn:stateMachineArn,Name:name,CreationDate:creationDate}' --output table"
    [APPSYNC_GRAPHQL_APIS]="aws appsync list-graphql-apis --query 'graphqlApis[*].{Name:name,ApiId:apiId,AuthenticationType:authenticationType}' --output table"

    # Networking Resources
    [LOAD_BALANCERS_V2]="aws elbv2 describe-load-balancers --query 'LoadBalancers[*].{LoadBalancerArn:LoadBalancerArn,DNSName:DNSName,Type:Type,State:State.Code}' --output table"
    [TARGET_GROUPS]="aws elbv2 describe-target-groups --query 'TargetGroups[*].{TargetGroupArn:TargetGroupArn,TargetType:TargetType,Protocol:Protocol,Port:Port}' --output table"
    [API_GATEWAYS]="aws apigateway get-rest-apis --query 'items[*].{Id:id,Name:name,CreatedDate:createdDate,Version:version}' --output table"

    # Storage Resources
    [S3_BUCKETS]="aws s3api list-buckets --query 'Buckets[*].{Name:Name,CreationDate:CreationDate}' --output table"
    [EFS_FILE_SYSTEMS]="aws efs describe-file-systems --query 'FileSystems[*].{FileSystemId:FileSystemId,Name:Name,CreationTime:CreationTime,SizeInBytes:SizeInBytes}' --output table"
    [EBS_VOLUMES]="aws ec2 describe-volumes --query 'Volumes[*].{VolumeId:VolumeId,Size:Size,State:State,AvailabilityZone:AvailabilityZone}' --output table"

    # Database Resources
    [RDS_INSTANCES]="aws rds describe-db-instances --query 'DBInstances[*].{Identifier:DBInstanceIdentifier,Engine:Engine,Status:DBInstanceStatus,Size:DBInstanceClass}' --output table"
    [DYNAMODB_TABLES]="aws dynamodb list-tables --query 'TableNames' --output json | jq -r '.[]' | xargs -I {} aws dynamodb describe-table --table-name {}"
    [AURORA_CLUSTERS]="aws rds describe-db-clusters --query 'DBClusters[*].{ClusterIdentifier:DBClusterIdentifier,Engine:Engine,Status:Status,Endpoint:Endpoint}' --output table"
    [ELASTICACHE_CLUSTERS]="aws elasticache describe-cache-clusters --query 'CacheClusters[*].{CacheClusterId:CacheClusterId,Engine:Engine,CacheNodeType:CacheNodeType,Status:CacheClusterStatus}' --output table"
    [REDSHIFT_CLUSTERS]="aws redshift describe-clusters --query 'Clusters[*].{ClusterIdentifier:ClusterIdentifier,NodeType:NodeType,ClusterStatus:ClusterStatus,DBName:DBName}' --output table"

    # Monitoring and Logging
    [CLOUDWATCH_ALARMS]="aws cloudwatch describe-alarms --query 'MetricAlarms[*].{AlarmName:AlarmName,MetricName:MetricName,Namespace:Namespace,State:StateValue}' --output table"
    [CLOUDWATCH_LOG_GROUPS]="aws logs describe-log-groups --query 'logGroups[*].{LogGroupName:logGroupName,StoredBytes:storedBytes,RetentionInDays:retentionInDays}' --output table"
    [CLOUDWATCH_LOG_STREAMS]="aws logs describe-log-streams --log-group-name /aws/lambda/default --query 'logStreams[*].{LogStreamName:logStreamName,LastEventTimestamp:lastEventTimestamp}' --output table"
    [CLOUDWATCH_METRICS]="aws cloudwatch list-metrics --namespace AWS/EC2 --query 'Metrics[*].{Namespace:Namespace,MetricName:MetricName,Dimensions:Dimensions}' --output table"

    # Security and Compliance
    [WAF_WEB_ACLS]="aws wafv2 list-web-acls --scope REGIONAL --query 'WebACLs[*].{Name:Name,Id:Id,Description:Description}' --output table"
    [SECRETS_MANAGER_SECRETS]="aws secretsmanager list-secrets --query 'SecretList[*].{Name:Name,Description:Description,LastChangedDate:LastChangedDate}' --output table"
    [IAM_USERS]="aws iam list-users --query 'Users[*].{UserName:UserName,UserId:UserId,CreateDate:CreateDate}' --output table"
    [IAM_ROLES]="aws iam list-roles --query 'Roles[*].{RoleName:RoleName,RoleId:RoleId,CreateDate:CreateDate}' --output table"

    # Machine Learning
    [SAGEMAKER_NOTEBOOKS]="aws sagemaker list-notebook-instances --query 'NotebookInstances[*].{Name:NotebookInstanceName,Status:NotebookInstanceStatus,InstanceType:InstanceType}' --output table"
    [SAGEMAKER_MODELS]="aws sagemaker list-models --query 'Models[*].{ModelName:ModelName,ModelArn:ModelArn,CreationTime:CreationTime}' --output table"

    # Transfer and Migration
    [TRANSFER_SERVERS]="aws transfer list-servers --query 'Servers[*].{ServerId:ServerId,State:State,IdentityProviderType:IdentityProviderType}' --output table"
    [DATASYNC_TASKS]="aws datasync list-tasks --query 'Tasks[*].{TaskArn:TaskArn,Name:Name,Status:Status}' --output table"
)

# Deletion Commands Dictionary
declare -A DELETION_COMMANDS=(
    # Compute Resources
    [EC2_INSTANCES]="aws ec2 terminate-instances --instance-ids"
    [EC2_VOLUMES]="aws ec2 delete-volume --volume-id"
    [EC2_SNAPSHOTS]="aws ec2 delete-snapshot --snapshot-id"
    [EC2_SECURITY_GROUPS]="aws ec2 delete-security-group --group-id"
    [EC2_SUBNETS]="aws ec2 delete-subnet --subnet-id"
    [EC2_VPCS]="aws ec2 delete-vpc --vpc-id"
    [EC2_NETWORK_INTERFACES]="aws ec2 delete-network-interface --network-interface-id"
    [EC2_ROUTE_TABLES]="aws ec2 delete-route-table --route-table-id"
    [EC2_INTERNET_GATEWAYS]="aws ec2 delete-internet-gateway --internet-gateway-id"
    [EC2_NAT_GATEWAYS]="aws ec2 delete-nat-gateway --nat-gateway-id"

    # Container Resources
    [ECS_CLUSTERS]="aws ecs delete-cluster --cluster"
    [ECS_SERVICES]="aws ecs delete-service --cluster default --service"
    [ECS_TASK_DEFINITIONS]="aws ecs deregister-task-definition --task-definition"
    [EKS_CLUSTERS]="aws eks delete-cluster --name"
    [ECR_REPOSITORIES]="aws ecr delete-repository --repository-name"

    # Serverless Resources
    [LAMBDA_FUNCTIONS]="aws lambda delete-function --function-name"
    [STEP_FUNCTIONS]="aws stepfunctions delete-state-machine --state-machine-arn"
    [APPSYNC_GRAPHQL_APIS]="aws appsync delete-graphql-api --api-id"

    # Networking Resources
    [LOAD_BALANCERS_V2]="aws elbv2 delete-load-balancer --load-balancer-arn"
    [TARGET_GROUPS]="aws elbv2 delete-target-group --target-group-arn"
    [API_GATEWAYS]="aws apigateway delete-rest-api --rest-api-id"

    # Storage Resources
    [S3_BUCKETS]="aws s3 rb s3://"
    [EFS_FILE_SYSTEMS]="aws efs delete-file-system --file-system-id"
    [EBS_VOLUMES]="aws ec2 delete-volume --volume-id"

    # Database Resources
    [RDS_INSTANCES]="aws rds delete-db-instance --db-instance-identifier --skip-final-snapshot"
    [DYNAMODB_TABLES]="aws dynamodb delete-table --table-name"
    [AURORA_CLUSTERS]="aws rds delete-db-cluster --db-cluster-identifier --skip-final-snapshot"
    [ELASTICACHE_CLUSTERS]="aws elasticache delete-cache-cluster --cache-cluster-id"
    [REDSHIFT_CLUSTERS]="aws redshift delete-cluster --cluster-identifier --skip-final-snapshot"

    # Monitoring and Logging
    [CLOUDWATCH_ALARMS]="aws cloudwatch delete-alarms --alarm-names"
    [CLOUDWATCH_LOG_GROUPS]="aws logs delete-log-group --log-group-name"

    # Security and Compliance
    [WAF_WEB_ACLS]="aws wafv2 delete-web-acl --id"
    [SECRETS_MANAGER_SECRETS]="aws secretsmanager delete-secret --secret-id"
    [IAM_USERS]="aws iam delete-user --user-name"
    [IAM_ROLES]="aws iam delete-role --role-name"

    # Machine Learning
    [SAGEMAKER_NOTEBOOKS]="aws sagemaker delete-notebook-instance --notebook-instance-name"
    [SAGEMAKER_MODELS]="aws sagemaker delete-model --model-name"

    # Transfer and Migration
    [TRANSFER_SERVERS]="aws transfer delete-server --server-id"
    [DATASYNC_TASKS]="aws datasync delete-task --task-arn"
)

# Resource Management Function (Existing implementation remains the same)
manage_resources() {
    local action="${1:-list}"
    local resource_type="${2:-}"
    local additional_arg="${3:-}"
    
    log_message "INFO" "Resource Management Action: ${action} for ${resource_type}"
    
    case "${action}" in
        "list")
            list_resources "${resource_type}"
            ;;
        "filter")
            filter_resources "${resource_type}" "${additional_arg}"
            ;;
        "delete")
            delete_resources "${resource_type}" "${additional_arg}"
            ;;
        "cost")
            track_resource_costs "${resource_type}" "${additional_arg}"
            ;;
        "cost-analysis")
            advanced_cost_analysis "${resource_type}" "${additional_arg}"
            ;;
        "forecast")
            forecast_costs "${additional_arg}"
            ;;
        "export")
            export_resource_inventory
            ;;
        *)
            log_message "ERROR" "Invalid action: ${action}"
            return 1
            ;;
    esac
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
        --query "Reservations[*].Instances[*].{InstanceId: InstanceId, State: State.Name, InstanceType: InstanceType, PublicIpAddress: PublicIpAddress, PrivateIpAddress: PrivateIpAddress, LaunchTime: LaunchTime}" \
        --output json | jq -r '.[][] | "| \(.InstanceId) | \(.State) | \(.InstanceType) | \(.PublicIpAddress // "N/A") | \(.PrivateIpAddress // "N/A") | \(.LaunchTime) |"' >> "$RESOURCES_TABLE" || 
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
        --query "Subnets[*].{SubnetId: SubnetId, VpcId: VpcId, CidrBlock: CidrBlock, AvailabilityZone: AvailabilityZone, MapPublicIpOnLaunch: MapPublicIpOnLaunch}" \
        --output json | jq -r '.[] | "| \(.SubnetId) | \(.VpcId) | \(.CidrBlock) | \(.AvailabilityZone) | \(.MapPublicIpOnLaunch) |"' >> "$RESOURCES_TABLE" || 
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
        --query "MetricAlarms[?contains(AlarmName, '$ENVIRONMENT')].{Name: AlarmName, Metric: MetricName, Threshold: Threshold, State: StateValue}" \
        --output json | jq -r '.[] | "| \(.Name) | \(.Metric) | \(.Threshold) | \(.State) |"' >> "$RESOURCES_TABLE" || 
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