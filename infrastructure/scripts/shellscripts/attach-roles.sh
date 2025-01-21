#!/bin/bash

# IAM Role Attachment Script
# Attaches predefined IAM roles to a specified user

# Set strict error handling
set -euo pipefail

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Function to attach role to user
attach_role_to_user() {
    local username="$1"
    local role_name="$2"
    
    # Check if user exists
    if ! aws iam get-user --user-name "${username}" &> /dev/null; then
        log "Error: User ${username} does not exist" "ERROR"
        return 1
    }
    
    # Check if role exists
    if ! aws iam get-role --role-name "${role_name}" &> /dev/null; then
        log "Error: Role ${role_name} does not exist" "ERROR"
        return 1
    }
    
    # Attach role to user
    log "Attaching role ${role_name} to user ${username}"
    aws iam attach-user-policy \
        --user-name "${username}" \
        --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):role/${role_name}"
}

# Main function
main() {
    # Check if username is provided
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 <username> [roles...]"
        echo "Available roles:"
        echo "- MicroservicesDeploymentRole"
        echo "- ECSTaskExecutionRole"
        echo "- LambdaExecutionRole"
        echo "- CloudFormationDeploymentRole"
        exit 1
    }
    
    local username="$1"
    shift
    
    # Default roles if none specified
    local roles=(
        "MicroservicesDeploymentRole"
        "ECSTaskExecutionRole"
        "LambdaExecutionRole"
        "CloudFormationDeploymentRole"
    )
    
    # Override with user-specified roles if provided
    if [[ $# -gt 0 ]]; then
        roles=("$@")
    fi
    
    # Attach each role
    for role in "${roles[@]}"; do
        attach_role_to_user "${username}" "${role}"
    done
    
    log "Role attachment complete for user ${username}"
}

# Run main function with all arguments
main "$@"