#!/bin/bash

# Network Stack Output Retrieval and Validation Script

# Set strict error handling
set -euo pipefail

# Logging function
log() {
    local level="${2:-INFO}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [${level}] $1"
}

# Function to get network stack outputs
get_network_stack_outputs() {
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
        --output json 2>/dev/null || true)
    
    # Check if outputs exist
    if [[ -z "${outputs}" || "${outputs}" == "[]" ]]; then
        log "No outputs found for network stack ${stack_name}" "ERROR"
        return 1
    fi
    
    # Parse and export outputs as environment variables
    echo "${outputs}" | jq -r '.[] | "export \(.OutputKey)=\(.OutputValue)"'
}

# Function to validate network stack parameters
validate_network_parameters() {
    local environment="${1:-dev}"
    local region="${2:-us-east-1}"
    
    # Normalize environment to lowercase and use 'dev' as default
    environment=$(echo "${environment}" | tr '[:upper:]' '[:lower:]')
    environment="${environment:-dev}"
    
    log "Validating Network Stack Parameters for ${environment}"
    
    # Retrieve network stack outputs
    local network_params
    network_params=$(get_network_stack_outputs "${environment}" "${region}")
    
    # Check if parameter retrieval was successful
    if [[ $? -ne 0 ]]; then
        log "Failed to retrieve network stack parameters. Ensure network stack is deployed." "ERROR"
        return 1
    fi
    
    # Execute the exported variables
    eval "${network_params}"
    
    # Validate critical network parameters
    local required_params=(
        "VpcId"
        "PrivateSubnet1"
        "PrivateSubnet2"
    )
    
    for param in "${required_params[@]}"; do
        if [[ -z "${!param:-}" ]]; then
            log "Missing required network parameter: ${param}" "ERROR"
            return 1
        else
            log "Validated ${param}: ${!param}"
        fi
    done
    
    # Export parameters for database stack deployment
    export DATABASE_VPC_ID="${VpcId}"
    export DATABASE_PRIVATE_SUBNET_1="${PrivateSubnet1}"
    export DATABASE_PRIVATE_SUBNET_2="${PrivateSubnet2}"
    
    log "Network parameters validated successfully"
}

# Main execution
main() {
    local environment="${1:-dev}"
    local region="${2:-us-east-1}"
    
    # Validate network parameters
    validate_network_parameters "${environment}" "${region}"
}

# Run main function if script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi