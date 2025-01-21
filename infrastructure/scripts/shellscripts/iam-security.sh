#!/bin/bash

# IAM Security and Management Script
# Implements best practices for AWS IAM user and role management

set -euo pipefail

# Logging function
log() {
    local level="${2:-INFO}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [${level}] $1"
}

# Configuration
CONFIG_DIR="/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/config"
USERS_FILE="${CONFIG_DIR}/iam_users.json"
GROUPS_FILE="${CONFIG_DIR}/iam_groups.json"

# Ensure config directory exists
mkdir -p "${CONFIG_DIR}"

# Create initial configuration files if they don't exist
create_default_config() {
    # Default IAM Users Configuration
    if [[ ! -f "${USERS_FILE}" ]]; then
        cat > "${USERS_FILE}" << EOF
{
    "users": [
        {
            "username": "devops-admin",
            "groups": ["DevOps", "Administrators"],
            "permissions": "AdministratorAccess"
        },
        {
            "username": "developer",
            "groups": ["Developers"],
            "permissions": "DeveloperAccess"
        },
        {
            "username": "readonly",
            "groups": ["ReadOnly"],
            "permissions": "ReadOnlyAccess"
        }
    ]
}
EOF
    fi

    # Default IAM Groups Configuration
    if [[ ! -f "${GROUPS_FILE}" ]]; then
        cat > "${GROUPS_FILE}" << EOF
{
    "groups": [
        {
            "name": "Administrators",
            "policies": [
                "arn:aws:iam::aws:policy/AdministratorAccess"
            ]
        },
        {
            "name": "Developers",
            "policies": [
                "arn:aws:iam::aws:policy/AWSCodeCommitFullAccess",
                "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
            ]
        },
        {
            "name": "ReadOnly",
            "policies": [
                "arn:aws:iam::aws:policy/ReadOnlyAccess"
            ]
        }
    ]
}
EOF
    fi
}

# Create IAM Groups
create_iam_groups() {
    log "Creating IAM Groups"
    local groups=$(jq -c '.groups[]' "${GROUPS_FILE}")
    
    while IFS= read -r group; do
        group_name=$(echo "$group" | jq -r '.name')
        
        # Create group if it doesn't exist
        if ! aws iam get-group --group-name "${group_name}" &> /dev/null; then
            aws iam create-group --group-name "${group_name}"
            log "Created IAM Group: ${group_name}"
        fi

        # Attach policies to group
        local policies=$(echo "$group" | jq -r '.policies[]')
        while IFS= read -r policy_arn; do
            aws iam attach-group-policy \
                --group-name "${group_name}" \
                --policy-arn "${policy_arn}"
            log "Attached policy ${policy_arn} to group ${group_name}"
        done <<< "$policies"
    done <<< "$groups"
}

# Create IAM Users
create_iam_users() {
    log "Creating IAM Users"
    local users=$(jq -c '.users[]' "${USERS_FILE}")
    
    while IFS= read -r user; do
        username=$(echo "$user" | jq -r '.username')
        
        # Create user if not exists
        if ! aws iam get-user --user-name "${username}" &> /dev/null; then
            # Generate a secure initial password
            initial_password=$(openssl rand -base64 16)
            
            aws iam create-user --user-name "${username}"
            aws iam create-login-profile \
                --user-name "${username}" \
                --password "${initial_password}" \
                --password-reset-required
            
            log "Created IAM User: ${username}"
            log "Initial Password for ${username}: ${initial_password}" "WARN"
        fi

        # Add user to groups
        local groups=$(echo "$user" | jq -r '.groups[]')
        while IFS= read -r group; do
            aws iam add-user-to-group \
                --user-name "${username}" \
                --group-name "${group}"
            log "Added ${username} to group ${group}"
        done <<< "$groups"
    done <<< "$users"
}

# Enable MFA for all users
enable_mfa() {
    log "Enabling MFA for IAM Users"
    local users=$(aws iam list-users --query 'Users[*].UserName' --output text)
    
    for username in $users; do
        # Skip if MFA already enabled
        if aws iam list-mfa-devices --user-name "${username}" | grep -q 'MFADevices'; then
            log "MFA already enabled for ${username}"
            continue
        fi
        
        log "Generating MFA seed for ${username}"
        mfa_seed=$(aws iam create-virtual-mfa-device \
            --virtual-mfa-device-name "${username}-mfa" \
            --outfile "/tmp/${username}-qr.png" \
            --bootstrap-method QRCodePNG)
        
        log "MFA Setup for ${username}. Please scan QR code at /tmp/${username}-qr.png" "WARN"
    done
}

# Rotate access keys
rotate_access_keys() {
    log "Rotating Access Keys for IAM Users"
    local users=$(aws iam list-users --query 'Users[*].UserName' --output text)
    
    for username in $users; do
        # Deactivate old keys
        aws iam list-access-keys --user-name "${username}" \
            --query 'AccessKeyMetadata[?Status==`Active`].AccessKeyId' \
            --output text | while read -r key_id; do
            aws iam update-access-key \
                --user-name "${username}" \
                --access-key-id "${key_id}" \
                --status Inactive
        done
        
        # Create new access key
        new_key=$(aws iam create-access-key --user-name "${username}")
        
        log "Rotated access keys for ${username}" "WARN"
        echo "${new_key}" | jq .
    done
}

# Main execution
main() {
    # Create default configurations
    create_default_config

    # Create IAM Groups
    create_iam_groups

    # Create IAM Users
    create_iam_users

    # Optional: Enable MFA
    read -p "Enable Multi-Factor Authentication for all users? (y/n): " mfa_choice
    if [[ "${mfa_choice}" == "y" ]]; then
        enable_mfa
    fi

    # Optional: Rotate Access Keys
    read -p "Rotate Access Keys for all users? (y/n): " key_choice
    if [[ "${key_choice}" == "y" ]]; then
        rotate_access_keys
    fi

    log "IAM Security Setup Complete"
}

# Run main function
main