#!/bin/bash

# Microservices Stack Deployment Script
# Provides helper functions and deployment logic for microservices infrastructure

log_stack_events() {
    local stack_name="$1"
    local region="$2"
    
    log "Fetching CloudFormation Stack Events for ${stack_name}" "INFO"
    
    # Fetch and log stack events
    local stack_events
    stack_events=$(aws cloudformation describe-stack-events \
        --stack-name "${stack_name}" \
        --region "${region}" \
        --query 'StackEvents[*].{ResourceStatus:ResourceStatus, ResourceType:ResourceType, LogicalResourceId:LogicalResourceId, Timestamp:Timestamp, ResourceStatusReason:ResourceStatusReason}' \
        --output table 2>&1)
    
    if [[ $? -eq 0 ]]; then
        log "Stack Events for ${stack_name}:" "INFO"
        log "${stack_events}" "INFO"
    else
        log "Failed to retrieve stack events for ${stack_name}" "ERROR"
        log "${stack_events}" "ERROR"
    fi
}

deploy_microservices_stack() {
    local environment="$1"
    local region="${2:-us-east-1}"
    local stack_name="microservice-microservices-stack-${environment}"
    
    log "Deploying Microservices Stack for ${environment}" "INFO"
    log "Detailed Microservices Stack Parameters:" "INFO"
    log "- Environment: ${environment}" "INFO"
    log "- Region: ${region}" "INFO"
    log "- Microservice Image URI: 954976299892.dkr.ecr.us-west-2.amazonaws.com/microservice-repo:latest" "INFO"
    
    log "Initiating CloudFormation deployment for Microservices Stack" "INFO"
    
    local deployment_output
    deployment_output=$(aws cloudformation deploy \
        --template-file "/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/cloudformation/microservices-stack.yaml" \
        --stack-name "${stack_name}" \
        --parameter-overrides \
            Environment="${environment}" \
            MicroserviceImageUri=954976299892.dkr.ecr.us-west-2.amazonaws.com/microservice-repo:latest \
        --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
        --region "${region}" 2>&1)
    
    local deploy_status=$?
    
    if [[ ${deploy_status} -ne 0 ]]; then
        log "Microservices Stack Deployment Failed" "ERROR"
        log "Deployment Output:" "ERROR"
        log "${deployment_output}" "ERROR"
        
        # Log stack events in case of failure
        log_stack_events "${stack_name}" "${region}"
        
        return 1
    fi
    
    # Log stack events after successful deployment
    log_stack_events "${stack_name}" "${region}"
    
    log "Microservices Stack Deployment Details:" "INFO"
    log "${deployment_output}" "INFO"
    log "Microservices Stack Deployment Complete" "INFO"
    
    return 0
}

export -f deploy_microservices_stack
export -f deploy_microservices_stack