#!/bin/bash

# Database Stack Deployment Script

# Source network parameter validation script
source /Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/scripts/shellscripts/validate-network-params.sh

# Logging function
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
}

generate_database_password() {
    # Generate a complex password that meets RDS requirements
    # Ensure it contains:
    # - Uppercase letters
    # - Lowercase letters
    # - Numbers
    # - Special characters (excluding '/', '@', '"', ' ')
    local password=$(openssl rand -base64 16 | tr -dc 'A-Za-z0-9!#$%^&*()_+-=[]{}|;:,.<>?' | head -c 32)
    echo "${password}"
}

validate_database_password() {
    local password="$1"
    
    # Check password length
    if [[ ${#password} -lt 12 || ${#password} -gt 41 ]]; then
        log "Database password must be between 12 and 41 characters" "ERROR"
        return 1
    fi
    
    # Check for disallowed characters using a more explicit method
    if [[ "$password" == *"/"* || "$password" == *"@"* || "$password" == *"\""* || "$password" == *" "* ]]; then
        log "Database password contains disallowed characters ('/', '@', '\"', or space)" "ERROR"
        return 1
    fi
    
    return 0
}

deploy_database_stack() {
    local environment="${1:-dev}"
    local region="${2:-us-east-1}"
    
    # Validate network parameters
    if ! validate_network_parameters "${environment}"; then
        log "Network parameter validation failed" "ERROR"
        return 1
    fi
    
    # Verify required network parameters are set
    if [[ -z "${DATABASE_VPC_ID:-}" || -z "${DATABASE_PRIVATE_SUBNET_1:-}" || -z "${DATABASE_PRIVATE_SUBNET_2:-}" ]]; then
        log "Missing required network parameters. Ensure network stack is deployed." "ERROR"
        return 1
    fi
    
    # Generate and validate database password
    local db_password
    db_password=$(generate_database_password)
    
    if ! validate_database_password "${db_password}"; then
        log "Failed to generate valid database password" "ERROR"
        return 1
    fi
    
    # Deploy database stack with validated parameters
    local db_stack_name="microservice-database-stack-${environment}"
    local deployment_output
    deployment_output=$(aws cloudformation deploy \
        --template-file "/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/cloudformation/database-stack.yaml" \
        --stack-name "${db_stack_name}" \
        --parameter-overrides \
            Environment="${environment}" \
            VpcId="${DATABASE_VPC_ID}" \
            PrivateSubnet1="${DATABASE_PRIVATE_SUBNET_1}" \
            PrivateSubnet2="${DATABASE_PRIVATE_SUBNET_2}" \
            DatabasePassword="${db_password}" \
        --capabilities CAPABILITY_IAM \
        --region "${region}" 2>&1)
    local deploy_status=$?
    
    if [[ ${deploy_status} -ne 0 ]]; then
        log "Database Stack Deployment Failed" "ERROR"
        log "Deployment Output:" "ERROR"
        log "${deployment_output}" "ERROR"
        
        # Check for SSL validation specific error
        if echo "${deployment_output}" | grep -q "SSL validation failed"; then
            log "SSL Validation Error Detected. Possible network or certificate issue." "ERROR"
            log "Suggestions:" "ERROR"
            log "1. Check network connectivity" "ERROR"
            log "2. Verify AWS CLI SSL certificates" "ERROR"
            log "3. Temporarily disable SSL verification (not recommended for production)" "ERROR"
        fi
        
        return 1
    fi
    
    log "Database stack deployed successfully" "INFO"
    return 0
}

# Main execution
main() {
    local environment="${1:-dev}"
    local region="${2:-us-east-1}"
    
    log "Deploying Database Stack for ${environment}"
    
    deploy_database_stack "${environment}" "${region}"
    
    log "Database Stack Deployment Complete"
}

# Run main function if script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi