#!/bin/bash

# Route53 Stack Deployment Script

# Logging function
log() {
    local level="${2:-INFO}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [${level}] $1"
}

# Deploy route53 stack
deploy_route53_stack() {
    local environment="${1:-dev}"
    local region="${2:-us-east-1}"
    
    # Normalize environment to lowercase and use 'dev' as default
    environment=$(echo "${environment}" | tr '[:upper:]' '[:lower:]')
    environment="${environment:-dev}"
    
    # Deploy route53 stack with explicit outputs
    local deploy_output
    deploy_output=$(aws cloudformation deploy \
        --template-file "/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/cloudformation/route53-stack.yaml" \
        --stack-name "microservice-route53-stack-${environment}" \
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
            log "Stack microservice-route53-stack-${environment} is already up to date" "INFO"
            return 0
        else
            log "Deployment failed: ${deploy_output}" "ERROR"
            return 1
        fi
    fi
    
    log "Route53 stack deployed successfully" "INFO"
    return 0
}

# Function to output route53 stack parameters
output_route53_parameters() {
    local environment="${1:-dev}"
    local region="${2:-us-east-1}"
    
    # Retrieve stack outputs
    local stack_name="microservice-route53-stack-${environment}"
    
    log "Retrieving Route53 stack parameters for ${stack_name}" "INFO"
    
    aws cloudformation describe-stacks \
        --stack-name "${stack_name}" \
        --region "${region}" \
        --query 'Stacks[0].Outputs' \
        --output table
}

# Main execution
main() {
    local environment="${1:-dev}"
    local region="${2:-us-east-1}"
    
    log "Starting Route53 Stack Deployment" "INFO"
    log "Environment: ${environment}" "INFO"
    log "Region: ${region}" "INFO"
    
    # Deploy the stack
    if ! deploy_route53_stack "${environment}" "${region}"; then
        log "Route53 Stack Deployment Failed" "ERROR"
        return 1
    fi
    
    # Output stack parameters
    output_route53_parameters "${environment}" "${region}"
    
    log "Route53 Stack Deployment Completed" "INFO"
    return 0
}

# Run main function if script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi