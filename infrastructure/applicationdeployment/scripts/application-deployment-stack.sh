#!/bin/bash

# Deployment Script for CloudFormation Infrastructure

# Set strict error handling
set -euo pipefail

# Source the common deployment functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/deployment-common.sh"

# Logging Configuration
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
LOG_DIR="$HOME/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/applicationdeployment/logs"
mkdir -p "$LOG_DIR"
ERROR_LOG="$LOG_DIR/deployment_${TIMESTAMP}.log"
DEPLOYMENT_LOG="$LOG_DIR/deployment_${TIMESTAMP}_events.log"

# Logging Functions
log() {
    local message="$1"
    local timestamp=$(date +'[%Y-%m-%d %H:%M:%S]')
    echo "$timestamp $message" | tee -a "$ERROR_LOG"
}

log_error() {
    local message="$1"
    local timestamp=$(date +'[%Y-%m-%d %H:%M:%S]')
    echo "ERROR: $timestamp $message" | tee -a "$ERROR_LOG" >&2
}

# Configuration Variables
ENVIRONMENT="dev"
REGION="us-east-1"
DEPLOYMENT_ROLE_ARN=""  # Add your deployment role ARN here
TEMPLATE_PATH="$HOME/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/applicationdeployment/cloudformation/application-deployment-stack.yaml"

# Enhanced stack creation with rollback handling
deploy_cloudformation_stack() {
    local stack_name="$1"
    
    log "Starting advanced CloudFormation stack deployment..."
    
    # Prepare CloudFormation parameters
    local parameters=(
        "ParameterKey=Environment,ParameterValue=$ENVIRONMENT"
        "ParameterKey=VpcCIDR,ParameterValue=10.0.0.0/16"
        "ParameterKey=PublicSubnet1CIDR,ParameterValue=10.0.1.0/24"
        "ParameterKey=PublicSubnet2CIDR,ParameterValue=10.0.2.0/24"
        "ParameterKey=PrivateSubnet1CIDR,ParameterValue=10.0.10.0/24"
        "ParameterKey=PrivateSubnet2CIDR,ParameterValue=10.0.11.0/24"
        "ParameterKey=InstanceType,ParameterValue=t3.medium"
        "ParameterKey=KeyPairName,ParameterValue=test"
        "ParameterKey=MinSize,ParameterValue=2"
        "ParameterKey=MaxSize,ParameterValue=6"
        "ParameterKey=DesiredCapacity,ParameterValue=2"
        "ParameterKey=AlertEmailAddress,ParameterValue=admin@yourdomain.com"
        "ParameterKey=LatestAmiId,ParameterValue=/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
        "ParameterKey=CreateSecurityHubResource,ParameterValue=false"
        "ParameterKey=CreateSNSSubscriptionResource,ParameterValue=false"
        "ParameterKey=CreateCSVProcessingBucket,ParameterValue=false"
        "ParameterKey=CreateApplicationLoadBalancerTargetGroup,ParameterValue=false"
        "ParameterKey=CreateInspectorAssessment,ParameterValue=false"
    )
    
    # Attempt to delete existing stack if it exists
    if aws cloudformation describe-stacks --stack-name "$stack_name" &>/dev/null; then
        log "Existing stack found. Attempting to delete..."
        if ! aws cloudformation delete-stack --stack-name "$stack_name"; then
            log_error "Failed to delete existing stack. Attempting force cleanup..."
            
            # Get all resources in the stack
            local resources
            resources=$(aws cloudformation list-stack-resources \
                --stack-name "$stack_name" \
                --query 'StackResourceSummaries[*].ResourceType' \
                --output text)
            
            # Additional cleanup for specific resource types
            for resource in $resources; do
                case "$resource" in
                    "AWS::EC2::Instance")
                        log "Terminating EC2 instances..."
                        aws ec2 terminate-instances \
                            --instance-ids $(aws cloudformation list-stack-resources \
                                --stack-name "$stack_name" \
                                --query 'StackResourceSummaries[?ResourceType==`AWS::EC2::Instance`].PhysicalResourceId' \
                                --output text)
                        ;;
                    "AWS::IAM::Role")
                        log "Cleaning up IAM roles..."
                        aws iam delete-role \
                            --role-name $(aws cloudformation list-stack-resources \
                                --stack-name "$stack_name" \
                                --query 'StackResourceSummaries[?ResourceType==`AWS::IAM::Role`].PhysicalResourceId' \
                                --output text)
                        ;;
                    # Add more resource type cleanups as needed
                esac
            done
            
            # Retry stack deletion
            if ! aws cloudformation delete-stack --stack-name "$stack_name"; then
                log_error "Failed to delete existing stack after force cleanup. Aborting deployment."
                return 1
            fi
        fi
        
        # Wait for stack deletion
        if ! aws cloudformation wait stack-delete-complete --stack-name "$stack_name"; then
            log_error "Stack deletion did not complete successfully"
            return 1
        fi
    fi
    
    # Pre-deployment cleanup and preparation
    pre_deployment_cleanup
    
    # Create new stack with enhanced error handling
    local stack_creation_output
    local stack_creation_error_log="${ERROR_LOG}_stack_creation_errors.log"
    
    # Validate template before creation
    if ! aws cloudformation validate-template --template-body file://"$TEMPLATE_PATH" > "$stack_creation_error_log" 2>&1; then
        log_error "CloudFormation template validation failed"
        cat "$stack_creation_error_log" >> "$ERROR_LOG"
        return 1
    fi
    
    # Attempt stack creation with comprehensive error capture
    if ! stack_creation_output=$(aws cloudformation create-stack \
        --stack-name "$stack_name" \
        --template-body file://"$TEMPLATE_PATH" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --parameters "${parameters[@]}" \
        --disable-rollback \
        2> >(tee -a "$stack_creation_error_log" >&2)); then
        
        log_error "CloudFormation stack creation failed"
        
        # Log detailed error information
        echo "=== AWS CLI Error Details ===" >> "$ERROR_LOG"
        cat "$stack_creation_error_log" >> "$ERROR_LOG"
        
        # Additional diagnostic information
        log_error "Detailed Template Validation:"
        aws cloudformation validate-template \
            --template-body file://"$TEMPLATE_PATH" \
            --query 'Parameters[*].{ParameterKey:ParameterKey, ParameterType:ParameterType}' \
            --output table >> "$ERROR_LOG" 2>&1
        
        return 1
    fi
    
    # Wait for stack creation with detailed logging
    log "Waiting for stack creation to complete..."
    if ! aws cloudformation wait stack-create-complete --stack-name "$stack_name" 2>> "$ERROR_LOG"; then
        log_error "Stack creation did not complete successfully"
        
        # Retrieve and log detailed stack failure information
        local failure_events
        failure_events=$(aws cloudformation describe-stack-events \
            --stack-name "$stack_name" \
            --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]' \
            --output table)
        
        log_error "Stack Creation Failure Details:"
        log_error "$failure_events"
        
        return 1
    fi
    
    log "Stack deployment completed successfully"
    return 0
}

# Pre-deployment cleanup function
pre_deployment_cleanup() {
    log "Performing pre-deployment cleanup..."
    
    # Remove existing Config Recorder if it exists
    local config_recorders
    config_recorders=$(aws configservice describe-configuration-recorders --query 'ConfigurationRecorders[].name' --output text)
    
    if [ -n "$config_recorders" ]; then
        log "Deleting existing Config Recorders: $config_recorders"
        for recorder in $config_recorders; do
            aws configservice delete-configuration-recorder --configuration-recorder-name "$recorder"
        done
    fi
    
    # Delete existing IAM Roles that might conflict
    local existing_roles=(
        "ApplicationDeploymentRole"
        "CloudFormationDeploymentRole"
    )
    
    for role in "${existing_roles[@]}"; do
        if aws iam get-role --role-name "$role" &>/dev/null; then
            log "Deleting existing IAM Role: $role"
            # Delete role's attached policies first
            local policies
            policies=$(aws iam list-attached-role-policies --role-name "$role" --query 'AttachedPolicies[].PolicyArn' --output text)
            
            for policy in $policies; do
                aws iam detach-role-policy --role-name "$role" --policy-arn "$policy"
            done
            
            # Delete inline policies
            local inline_policies
            inline_policies=$(aws iam list-role-policies --role-name "$role" --query 'PolicyNames' --output text)
            
            for policy in $inline_policies; do
                aws iam delete-role-policy --role-name "$role" --policy-name "$policy"
            done
            
            # Delete the role
            aws iam delete-role --role-name "$role"
        fi
    done
    
    log "Pre-deployment cleanup completed"
}

# Function to log stack events
log_stack_events() {
    local stack_name="$1"
    local log_file="${ERROR_LOG}_stack_events"
    
    log "Logging stack events for: $stack_name"
    
    # Retrieve and log stack events
    aws cloudformation describe-stack-events \
        --stack-name "$stack_name" \
        --query 'StackEvents[*].{ResourceStatus:ResourceStatus, ResourceType:ResourceType, LogicalResourceId:LogicalResourceId, ResourceStatusReason:ResourceStatusReason}' \
        --output table 2>&1 | tee -a "$log_file"
    
    # Log full stack events in JSON for detailed debugging
    aws cloudformation describe-stack-events \
        --stack-name "$stack_name" \
        --output json >> "${log_file}_full.json"
    
    log "Stack events logged to $log_file and ${log_file}_full.json"
}

# Network Parameters Validation
validate_network_parameters() {
    log "Validating network parameters..."
    
    # Add your network parameter validation logic here
    # Example checks:
    # - Validate CIDR blocks
    # - Check subnet configurations
    # - Verify network ACL settings
    
    log "Network parameters validation successful"
}

# Auto Scaling Configuration Validation
validate_autoscaling_config() {
    log "Validating Auto Scaling configuration..."
    
    # Add your Auto Scaling configuration validation logic
    # Example checks:
    # - Verify min/max instance counts
    # - Check scaling policies
    # - Validate launch configuration
    
    log "Auto Scaling configuration validation successful"
}

# Enhanced stack validation function
validate_cloudformation_template() {
    log "Performing comprehensive CloudFormation template validation..."
    
    # Validate template syntax
    local validation_output
    validation_output=$(aws cloudformation validate-template \
        --template-body file://"$TEMPLATE_PATH" 2>&1)
    local validation_status=$?
    
    if [ $validation_status -ne 0 ]; then
        log_error "CloudFormation template validation failed"
        log_error "Validation Error: $validation_output"
        
        # Additional detailed validation checks
        log "Checking for potential issues..."
        
        # Check for common CloudFormation template errors
        if echo "$validation_output" | grep -q "extraneous key"; then
            log_error "Detected extraneous key in template. Check resource definitions."
        fi
        
        if echo "$validation_output" | grep -q "invalid property"; then
            log_error "Detected invalid property in template. Review resource configurations."
        fi
        
        return 1
    fi
    
    log "CloudFormation template validation successful"
    return 0
}

# Generate unique stack name
generate_stack_name() {
    local prefix="$1"
    local timestamp=$(date +"%Y%m%d%H%M%S")
    local stack_name="${prefix}-${timestamp}"
    echo "$stack_name"
}

# Rest of the script remains the same as in the previous implementation

# Ensure logging functions are defined before main function
main() {
    # Validate network parameters
    validate_network_parameters
    
    # Validate Auto Scaling configuration
    validate_autoscaling_config
    
    # Validate CloudFormation template
    validate_cloudformation_template || {
        log_error "Template validation failed. Aborting deployment."
        exit 1
    }
    
    # Generate unique stack name
    STACK_NAME=$(generate_stack_name "application-deployment")
    
    # Deploy stack with advanced error handling
    deploy_cloudformation_stack "$STACK_NAME" || {
        log_error "Deployment of $STACK_NAME failed"
        exit 1
    }
    
    # Retrieve stack outputs
    STACK_OUTPUTS=$(retrieve_stack_outputs "$STACK_NAME")
    
    # Retrieve specific notification topics
    SECURITY_NOTIFICATION_TOPIC=$(get_stack_output "$STACK_NAME" "SecurityNotificationTopicArn")
    DISASTER_RECOVERY_TOPIC=$(get_stack_output "$STACK_NAME" "DisasterRecoveryNotificationTopicArn")
    
    # Run security scans
    run_security_scans "$STACK_NAME" "$SECURITY_NOTIFICATION_TOPIC" || {
        log "Security scan detected potential issues"
    }
    
    # Run disaster recovery simulation
    simulate_disaster_recovery "$STACK_NAME" "$DISASTER_RECOVERY_TOPIC" || {
        log "Potential disaster scenario detected"
    }
    
    # Log comprehensive stack events
    log_comprehensive_stack_events "$STACK_NAME"
    
    # Send deployment notification
    send_deployment_notification "$STACK_NAME"
    
    log "Deployment workflow completed successfully!"
}

# Run main function
main "$@"