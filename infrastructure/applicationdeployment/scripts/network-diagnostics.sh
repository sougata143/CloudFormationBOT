#!/bin/bash

# Comprehensive Network Diagnostics Script for AWS CloudFormation Deployment

set -e

# Configuration
REGION="${REGION:-us-east-1}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Logging Directory
LOG_DIR="${HOME}/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/applicationdeployment/logs"
mkdir -p "$LOG_DIR"

# Log file with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/network_diagnostics_${TIMESTAMP}.log"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions with file output
log() {
    local message="$1"
    echo -e "${YELLOW}[NETWORK DIAGNOSTIC]${NC} $message" | tee -a "$LOG_FILE"
}

error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} $message" | tee -a "$LOG_FILE"
}

success() {
    local message="$1"
    echo -e "${GREEN}[SUCCESS]${NC} $message" | tee -a "$LOG_FILE"
}

info() {
    local message="$1"
    echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$LOG_FILE"
}

# Comprehensive AWS Resource Inventory
aws_resource_inventory() {
    log "Generating AWS Resource Inventory..."
    
    # VPC Inventory
    info "VPC Inventory:" 
    aws ec2 describe-vpcs \
        --region "$REGION" \
        --query "Vpcs[*].{VpcId:VpcId, CidrBlock:CidrBlock, IsDefault:IsDefault, Tags:Tags}" \
        --output table | tee -a "$LOG_FILE"

    # Internet Gateway Inventory
    info "\nInternet Gateway Inventory:"
    aws ec2 describe-internet-gateways \
        --region "$REGION" \
        --query "InternetGateways[*].{IGWId:InternetGatewayId, Attachments:Attachments[*].VpcId}" \
        --output table | tee -a "$LOG_FILE"

    # Subnet Inventory
    info "\nSubnet Inventory:"
    aws ec2 describe-subnets \
        --region "$REGION" \
        --query "Subnets[*].{SubnetId:SubnetId, VpcId:VpcId, CidrBlock:CidrBlock, AvailabilityZone:AvailabilityZone, MapPublicIpOnLaunch:MapPublicIpOnLaunch}" \
        --output table | tee -a "$LOG_FILE"

    # Security Group Inventory
    info "\nSecurity Group Inventory:"
    aws ec2 describe-security-groups \
        --region "$REGION" \
        --query "SecurityGroups[*].{GroupId:GroupId, GroupName:GroupName, VpcId:VpcId}" \
        --output table | tee -a "$LOG_FILE"
}

# Network Connectivity Diagnostics
network_connectivity_test() {
    log "Performing Network Connectivity Diagnostics..."
    
    # Check AWS API Connectivity
    info "Checking AWS API Connectivity..."
    aws sts get-caller-identity > /dev/null 2>&1 && 
        success "AWS API Connectivity: Successful" || 
        error "AWS API Connectivity: Failed"

    # Check Default VPC
    info "Checking Default VPC Configuration..."
    DEFAULT_VPC=$(aws ec2 describe-vpcs \
        --region "$REGION" \
        --filters "Name=isDefault,Values=true" \
        --query "Vpcs[0].VpcId" \
        --output text)
    
    if [ "$DEFAULT_VPC" != "None" ]; then
        success "Default VPC Found: $DEFAULT_VPC"
        
        # Check Default Subnets
        DEFAULT_SUBNETS=$(aws ec2 describe-subnets \
            --region "$REGION" \
            --filters "Name=vpc-id,Values=$DEFAULT_VPC" \
            --query "length(Subnets)" \
            --output text)
        
        info "Default Subnets in VPC: $DEFAULT_SUBNETS"
    else
        error "No Default VPC Found"
    fi
}

# CloudFormation Stack Diagnostics
cloudformation_stack_diagnostics() {
    log "Analyzing CloudFormation Stack Configuration..."
    
    # List Recent Stacks
    info "Recent CloudFormation Stacks:"
    aws cloudformation list-stacks \
        --region "$REGION" \
        --stack-status-filter CREATE_COMPLETE CREATE_FAILED \
        --query "StackSummaries[?contains(StackName, '$ENVIRONMENT')].{StackName:StackName, CreationTime:CreationTime, StackStatus:StackStatus}" \
        --output table | tee -a "$LOG_FILE"

    # Detailed Stack Events for Last Deployment
    LAST_STACK=$(aws cloudformation list-stacks \
        --region "$REGION" \
        --stack-status-filter CREATE_COMPLETE CREATE_FAILED \
        --query "StackSummaries[?contains(StackName, '$ENVIRONMENT')]|[0].StackName" \
        --output text)
    
    if [ "$LAST_STACK" != "None" ]; then
        info "\nLast Stack Deployment Events:"
        aws cloudformation describe-stack-events \
            --region "$REGION" \
            --stack-name "$LAST_STACK" \
            --query "StackEvents[?ResourceStatus=='CREATE_FAILED']|[0:5].{LogicalResourceId:LogicalResourceId, ResourceStatus:ResourceStatus, ResourceStatusReason:ResourceStatusReason}" \
            --output table | tee -a "$LOG_FILE"
    fi
}

# Main Diagnostic Function
main() {
    log "Starting Comprehensive Network Configuration Diagnostics..."
    log "AWS Account: $AWS_ACCOUNT_ID | Region: $REGION | Environment: $ENVIRONMENT"
    log "Logging to: $LOG_FILE"
    
    aws_resource_inventory
    network_connectivity_test
    cloudformation_stack_diagnostics
    
    success "Network Diagnostics Completed Successfully"
    
    # Print log file location
    echo -e "\n${GREEN}Diagnostic log saved to:${NC} $LOG_FILE"
}

# Execute Main Function
main