#!/bin/bash

# Deployment Common Functions
# Version: 1.0.0
# Description: Shared utility functions for CloudFormation deployments

# Logging function
log_message() {
    local log_level="${1:-INFO}"
    local message="${2}"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[${timestamp}] [${log_level}] ${message}"
}

# Error handling function
handle_error() {
    local error_message="${1}"
    log_message "ERROR" "${error_message}"
    exit 1
}

# Check AWS CLI installation
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        handle_error "AWS CLI is not installed. Please install AWS CLI."
    fi
}

# Check AWS credentials
check_aws_credentials() {
    if ! aws sts get-caller-identity &> /dev/null; then
        handle_error "AWS credentials are not configured. Please run 'aws configure'."
    fi
}

# Validate environment input
validate_environment() {
    local environment="${1}"
    local valid_envs=("dev" "staging" "prod")
    
    if [[ ! " ${valid_envs[@]} " =~ " ${environment} " ]]; then
        handle_error "Invalid environment. Must be one of: ${valid_envs[*]}"
    fi
}

# Retrieve stack outputs
retrieve_stack_outputs() {
    local stack_name="${1}"
    local output_file="${2:-/tmp/${stack_name}_outputs.json}"
    
    log_message "INFO" "Retrieving outputs for stack: ${stack_name}"
    
    aws cloudformation describe-stacks \
        --stack-name "${stack_name}" \
        --query 'Stacks[0].Outputs' \
        --output json > "${output_file}" 2>/dev/null
    
    if [[ $? -ne 0 ]]; then
        handle_error "Failed to retrieve stack outputs for ${stack_name}"
    fi
    
    log_message "INFO" "Stack outputs saved to ${output_file}"
    echo "${output_file}"
}

# Extract specific output value
get_stack_output_value() {
    local output_file="${1}"
    local output_key="${2}"
    
    jq -r ".[] | select(.OutputKey == \"${output_key}\") | .OutputValue" "${output_file}"
}

# Send deployment notification
send_deployment_notification() {
    local deployment_name="${1}"
    local status="${2}"
    local additional_info="${3:-}"
    
    log_message "INFO" "Deployment Notification: ${deployment_name} - ${status}"
    
    # Optional: Implement SNS or email notification logic here
    # For now, just log the notification
    if [[ -n "${additional_info}" ]]; then
        log_message "INFO" "Additional Info: ${additional_info}"
    fi
}

# Export functions for use in other scripts
export -f log_message
export -f handle_error
export -f check_aws_cli
export -f check_aws_credentials
export -f validate_environment
export -f retrieve_stack_outputs
export -f get_stack_output_value
export -f send_deployment_notification
