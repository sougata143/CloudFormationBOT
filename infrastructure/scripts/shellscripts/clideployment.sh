#!/bin/bash

# CloudFormation Deployment Script
# Manages deployment of microservices infrastructure across different environments

# Set strict error handling
set -euo pipefail

# Project root directory
PROJECT_ROOT="/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT"

# Deployment configuration
ENV="${1:-dev}"
REGION="${2:-us-east-1}"

# Logging function with explicit file logging
log() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    
    # Console output
    echo "[${timestamp}] [${level}] ${message}"
    
    # Ensure log directory exists
    mkdir -p "${LOG_DIR:-/tmp/cloudformation_logs}"
    
    # Log to deployment log
    if [[ -n "${DEPLOYMENT_LOG:-}" ]]; then
        echo "[${timestamp}] [${level}] ${message}" >> "${DEPLOYMENT_LOG}"
    fi
    
    # Log to error log if it's an error
    if [[ "${level}" == "ERROR" && -n "${ERROR_LOG:-}" ]]; then
        echo "[${timestamp}] [${level}] ${message}" >> "${ERROR_LOG}"
    fi
}

# Logging directories
LOG_DIR="${PROJECT_ROOT}/infrastructure/logs/deployments"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DEPLOYMENT_LOG="${LOG_DIR}/cloudformation_deployment_${TIMESTAMP}.log"
ERROR_LOG="${LOG_DIR}/cloudformation_deployment_errors_${TIMESTAMP}.log"

# Create logs directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Ensure log files are created with proper permissions
touch "${DEPLOYMENT_LOG}" "${ERROR_LOG}"
chmod 666 "${DEPLOYMENT_LOG}" "${ERROR_LOG}"

# Stack deployment order and scripts
STACK_DEPLOYMENT_ORDER=(
    "network-stack.sh"
    "database-stack.sh"
    "storage-stack.sh"
    "microservices-stack.sh"
    "monitoring-stack.sh"
)

# Deployment function
deploy_stack() {
    local stack_script="$1"
    local environment="$2"
    local region="$3"
    
    log "Deploying ${stack_script%.*} for ${environment}"
    
    # Multiple potential paths for stack script
    local stack_script_paths=(
        "${PROJECT_ROOT}/infrastructure/scripts/shellscripts/stackscripts/${stack_script}"
        "/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/scripts/shellscripts/stackscripts/${stack_script}"
    )
    
    local script_found=false
    for script_path in "${stack_script_paths[@]}"; do
        if [[ -f "${script_path}" ]]; then
            log "Found stack script: ${script_path}"
            script_found=true
            
            # Detailed logging of stack deployment
            log "Executing stack deployment script: ${script_path}"
            log "------- Stack Deployment Details -------"
            log "Environment: ${environment}"
            log "Region: ${region}"
            
            # Detailed function detection and sourcing
            local stack_name="${stack_script%.*}"
            # Remove any hyphens to match function naming convention
            stack_name=$(echo "${stack_name}" | tr '-' '_')
            
            # Potential deployment function names
            local deployment_function_candidates=(
                "deploy_${stack_name}_stack"
                "deploy_${stack_name%_stack}_stack"
                "deploy_${stack_name}"
            )
            
            # Verbose logging of function detection
            log "Searching for deployment functions with these candidates:" "INFO"
            for candidate in "${deployment_function_candidates[@]}"; do
                log "  - Checking: ${candidate}" "INFO"
            done
            
            # Source the script and print debug information
            log "Sourcing script: ${script_path}"
            if ! source "${script_path}"; then
                log "Failed to source script: ${script_path}" "ERROR"
                return 1
            fi
            
            # Print all functions for debugging
            log "All available functions after sourcing:" "INFO"
            declare -F || log "No functions found" "WARN"
            
            # Try to find a valid deployment function
            local found_function=""
            for candidate in "${deployment_function_candidates[@]}"; do
                if declare -f "${candidate}" > /dev/null; then
                    found_function="${candidate}"
                    break
                fi
            done
            
            # Check if a function was found
            if [[ -z "${found_function}" ]]; then
                log "No deployment function found for ${stack_script}" "ERROR"
                return 1
            fi
            
            # Call the deployment function with error handling
            log "Calling deployment function: ${found_function}"
            if ! "${found_function}" "${environment}" "${region}"; then
                # Only log an error if the function returns a non-zero status
                if [[ $? -ne 0 ]]; then
                    log "Deployment failed for ${stack_script}" "ERROR"
                    
                    # Additional error context
                    log "Stack Name: microservice-${stack_name%_stack}-stack-${environment}" "ERROR"
                    log "Template Path: /Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/cloudformation/${stack_script%.*}.yaml" "ERROR"
                    
                    return 1
                fi
            fi
            
            break
        fi
    done
    
    if [[ "${script_found}" == "false" ]]; then
        log "Stack script not found: ${stack_script}" "ERROR"
        return 1
    fi
    
    log "${stack_script%.*} Deployment Complete"
    return 0
}

# Main deployment function
deploy_all_stacks() {
    local environment="$1"
    local region="$2"
    
    log "Starting CloudFormation Deployment"
    log "Environment: ${environment}"
    log "Region: ${region}"
    log "Deployment Log: ${DEPLOYMENT_LOG}"
    log "Error Log: ${ERROR_LOG}"
    
    # Deploy stacks in order
    for stack_script in "${STACK_DEPLOYMENT_ORDER[@]}"; do
        if ! deploy_stack "${stack_script}" "${environment}" "${region}"; then
            log "Deployment failed for ${stack_script}" "ERROR"
            return 1
        fi
    done
    
    log "All Stacks Deployment Complete" "INFO"
}

# Rollback function for all stacks
rollback_all_stacks() {
    local environment="$1"
    local region="$2"
    
    log "Starting CloudFormation Rollback"
    log "Environment: ${environment}"
    log "Region: ${region}"
    
    # Reverse the stack deployment order for rollback
    for ((i=${#STACK_DEPLOYMENT_ORDER[@]}-1; i>=0; i--)); do
        local stack_script="${STACK_DEPLOYMENT_ORDER[i]}"
        local stack_name="microservice-${stack_script%.*}-${environment}"
        
        log "Attempting to delete stack: ${stack_name}"
        
        # Delete the stack
        if aws cloudformation delete-stack \
            --stack-name "${stack_name}" \
            --region "${region}"; then
            
            # Wait for stack deletion
            aws cloudformation wait stack-delete-complete \
                --stack-name "${stack_name}" \
                --region "${region}"
            
            log "Stack ${stack_name} deleted successfully"
        else
            log "Failed to delete stack ${stack_name}" "WARN"
        fi
    done
    
    log "Rollback Complete" "INFO"
}

# Usage instructions
usage() {
    echo "Usage: $0 [deploy|rollback] [environment] [region]"
    echo "  environment: dev (default), staging, prod"
    echo "  region: us-east-1 (default)"
    exit 1
}

# Main script execution
main() {
    # Validate arguments
    if [[ $# -lt 1 ]]; then
        usage
    fi
    
    local command="$1"
    shift
    
    # Set default environment and region if not provided
    local environment="${1:-dev}"
    local region="${2:-us-east-1}"
    
    # Execute based on command
    case "${command}" in
        deploy)
            deploy_all_stacks "${environment}" "${region}"
            ;;
        rollback)
            rollback_all_stacks "${environment}" "${region}"
            ;;
        -h|--help)
            usage
            ;;
        *)
            log "Invalid command: ${command}" "ERROR"
            usage
            ;;
    esac
}

# Run main function
main "$@"