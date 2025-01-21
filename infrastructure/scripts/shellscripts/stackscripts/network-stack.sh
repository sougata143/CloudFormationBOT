#!/bin/bash

# Network Stack Deployment Script

# Logging function
log() {
    local level="${2:-INFO}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [${level}] $1"
}

# Deploy network stack
deploy_network_stack() {
    local environment="${1:-dev}"
    local region="${2:-us-east-1}"
    
    # Normalize environment to lowercase and use 'dev' as default
    environment=$(echo "${environment}" | tr '[:upper:]' '[:lower:]')
    environment="${environment:-dev}"
    
    # Deploy network stack with explicit outputs
    local deploy_output
    deploy_output=$(aws cloudformation deploy \
        --template-file "/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/cloudformation/network-stack.yaml" \
        --stack-name "microservice-network-stack-${environment}" \
        --parameter-overrides \
            Environment="${environment}" \
        --capabilities CAPABILITY_IAM \
        --region "${region}" 2>&1)
    
    # Capture the deployment status
    local deploy_status=$?
    
    # Check if deployment was successful or if stack is already up to date
    if [[ ${deploy_status} -ne 0 ]]; then
        # Check if the error is just "No changes to deploy"
        if echo "${deploy_output}" | grep -q "No changes to deploy"; then
            log "Stack microservice-network-stack-${environment} is already up to date" "INFO"
            return 0
        else
            log "Deployment failed: ${deploy_output}" "ERROR"
            return 1
        fi
    fi
    
    log "Network stack deployed successfully" "INFO"
    return 0
}

# Function to output network stack parameters
output_network_parameters() {
    local environment="${1:-dev}"
    local region="${2:-us-east-1}"
    
    # Normalize environment to lowercase and use 'dev' as default
    environment=$(echo "${environment}" | tr '[:upper:]' '[:lower:]')
    environment="${environment:-dev}"
    
    local stack_name="microservice-network-stack-${environment}"
    
    # Retrieve stack outputs
    local outputs
    outputs=$(aws cloudformation describe-stacks \
        --stack-name "${stack_name}" \
        --region "${region}" \
        --query 'Stacks[0].Outputs' \
        --output json)
    
    # Check if outputs exist
    if [[ -z "${outputs}" || "${outputs}" == "[]" ]]; then
        log "No outputs found for network stack ${stack_name}" "ERROR"
        return 1
    fi
    
    # Parse and export outputs
    echo "${outputs}" | jq -r '.[] | "export \(.OutputKey)=\(.OutputValue)"'
}

# Main execution
main() {
    local environment="${1:-dev}"
    local region="${2:-us-east-1}"
    
    log "Deploying Network Stack for ${environment}"
    
    # Deploy network stack
    deploy_network_stack "${environment}" "${region}"
    
    # Output network parameters
    output_network_parameters "${environment}" "${region}"
    
    log "Network Stack Deployment Complete"
}

# Run main function if script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi