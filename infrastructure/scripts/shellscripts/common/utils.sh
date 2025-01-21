#!/bin/bash

# Determine the project root directory
PROJECT_ROOT="/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT"

# Source logging functions
source "${PROJECT_ROOT}/infrastructure/scripts/shellscripts/common/logging.sh"

# Validate environment
validate_environment() {
    local environment="${1:?Environment is required}"
    
    # Convert to lowercase for consistent checking
    environment=$(echo "${environment}" | tr '[:upper:]' '[:lower:]')
    
    case "${environment}" in
        dev|staging|prod)
            log "Validated environment: ${environment}" "INFO"
            return 0
            ;;
        *)
            log "Invalid environment: ${environment}. Must be dev, staging, or prod" "ERROR"
            return 1
            ;;
    esac
}

# Validate AWS region
validate_region() {
    local region="${1:?Region is required}"
    
    log "Validating AWS region: ${region}" "INFO"
    
    if ! aws ec2 describe-regions --region-names "${region}" &>/dev/null; then
        log "Invalid AWS region: ${region}" "ERROR"
        return 1
    fi
    
    log "Region ${region} is valid" "INFO"
    return 0
}

# Check AWS CLI configuration
check_aws_cli_config() {
    log "Checking AWS CLI configuration" "INFO"
    
    if ! aws sts get-caller-identity &>/dev/null; then
        log "AWS CLI not configured or credentials invalid" "ERROR"
        return 1
    fi
    
    log "AWS CLI configuration verified" "INFO"
    return 0
}

# Retry mechanism for AWS operations
aws_retry() {
    local command="${1:?Command is required}"
    local max_attempts="${2:-3}"
    local delay="${3:-5}"
    
    local attempt=1
    while [[ ${attempt} -le ${max_attempts} ]]; do
        log "Executing command (Attempt ${attempt}): ${command}" "INFO"
        
        if eval "${command}"; then
            log "Command succeeded" "INFO"
            return 0
        fi
        
        log "Command failed (Attempt ${attempt})" "WARN"
        
        if [[ ${attempt} -lt ${max_attempts} ]]; then
            log "Retrying in ${delay} seconds..." "WARN"
            sleep "${delay}"
        fi
        
        ((attempt++))
    done
    
    log "Command failed after ${max_attempts} attempts" "ERROR"
    return 1
}

# Export functions
export -f validate_environment
export -f validate_region
export -f check_aws_cli_config
export -f aws_retry