#!/bin/bash

# Config Recorder Stack Deployment Script
# Version: 1.0.0
# Author: Sougata Roy
# Description: Automates the deployment of AWS Config Recorder CloudFormation stack

# Strict mode
set -euo pipefail

# Logging setup
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGS_DIR="${SCRIPT_DIR}/../logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOGS_DIR}/config_recorder_deployment_${TIMESTAMP}.log"

# Create logs directory if it doesn't exist
mkdir -p "${LOGS_DIR}"

# Source common functions and environment variables
source "${SCRIPT_DIR}/deployment-common.sh"

# Configuration
ENVIRONMENT="${1:-dev}"
STACK_NAME="${ENVIRONMENT}-config-recorder-stack"
TEMPLATE_PATH="${SCRIPT_DIR}/../cloudformation/config-recorder.yaml"

# Validate input
validate_environment "${ENVIRONMENT}"

# Logging function
log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

# Deployment function
deploy_config_recorder_stack() {
    log_message "Starting Config Recorder stack deployment for ${ENVIRONMENT} environment"

    # Validate CloudFormation template
    log_message "Validating CloudFormation template..."
    aws cloudformation validate-template \
        --template-body file://"${TEMPLATE_PATH}" || handle_error "Template validation failed"

    # Deploy CloudFormation stack
    log_message "Deploying CloudFormation stack: ${STACK_NAME}"
    aws cloudformation create-stack \
        --stack-name "${STACK_NAME}" \
        --template-body file://"${TEMPLATE_PATH}" \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --parameters \
            ParameterKey=Environment,ParameterValue="${ENVIRONMENT}" \
            ParameterKey=CreateConfigRecorder,ParameterValue="true" \
        --tags \
            Key=Environment,Value="${ENVIRONMENT}" \
            Key=ManagedBy,Value="CloudFormation" \
            Key=Project,Value="AWS Config Recorder" || handle_error "Stack creation failed"

    # Wait for stack creation
    log_message "Waiting for stack creation to complete..."
    aws cloudformation wait stack-create-complete \
        --stack-name "${STACK_NAME}" || handle_error "Stack creation did not complete successfully"

    log_message "Config Recorder stack deployment completed successfully"
}

# Error handling function
handle_error() {
    log_message "ERROR: $1"
    send_deployment_notification "Config Recorder Stack Deployment" "FAILED" "$1"
    exit 1
}

# Main execution
main() {
    log_message "Initiating Config Recorder stack deployment process"
    
    # Pre-deployment checks
    check_aws_cli
    check_aws_credentials

    # Deploy stack
    deploy_config_recorder_stack

    # Post-deployment tasks
    send_deployment_notification "Config Recorder Stack Deployment" "SUCCESS"
}

# Trap signals for clean exit
trap 'handle_error "Deployment interrupted"' SIGINT SIGTERM

# Execute main function
main

log_message "Config Recorder stack deployment script completed"