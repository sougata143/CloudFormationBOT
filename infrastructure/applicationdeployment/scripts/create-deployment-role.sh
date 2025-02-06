#!/bin/bash

# Set variables
ROLE_NAME="ApplicationDeploymentRole"
POLICY_NAME="ApplicationDeploymentPolicy"
POLICY_FILE="$HOME/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/applicationdeployment/cloudformation/deployment-iam-policy.json"

# Logging function
log() {
    echo -e "\033[1;34m[$(date +'%Y-%m-%d %H:%M:%S')] $*\033[0m"
}

# Function to check if role exists
role_exists() {
    aws iam get-role --role-name "$ROLE_NAME" &>/dev/null
}

# Function to check if policy exists
policy_exists() {
    aws iam get-policy --policy-name "$POLICY_NAME" &>/dev/null
}

# Cleanup existing resources
cleanup_existing_resources() {
    log "Checking for existing resources..."
    
    # Check and delete existing role policies
    if role_exists; then
        log "Existing role found. Detaching and deleting..."
        
        # Detach all managed policies
        for policy_arn in $(aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query 'AttachedPolicies[*].PolicyArn' --output text); do
            log "Detaching policy: $policy_arn"
            aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$policy_arn"
        done
        
        # Delete the role
        aws iam delete-role --role-name "$ROLE_NAME"
        log "Existing role deleted."
    fi
    
    # Delete existing policy if it exists
    if policy_exists; then
        log "Existing policy found. Deleting..."
        policy_arn=$(aws iam get-policy --policy-name "$POLICY_NAME" --query 'Policy.Arn' --output text)
        aws iam delete-policy --policy-arn "$policy_arn"
        log "Existing policy deleted."
    fi
}

# Create IAM Role
create_deployment_role() {
    log "Creating IAM role: $ROLE_NAME"
    
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Service": [
                            "cloudformation.amazonaws.com",
                            "ec2.amazonaws.com"
                        ]
                    },
                    "Action": "sts:AssumeRole"
                }
            ]
        }' || {
        log "ERROR: Failed to create IAM role"
        return 1
    }
}

# Create IAM Policy
create_deployment_policy() {
    log "Creating IAM policy: $POLICY_NAME"
    
    aws iam create-policy \
        --policy-name "$POLICY_NAME" \
        --policy-document "file://$POLICY_FILE" || {
        log "ERROR: Failed to create IAM policy"
        return 1
    }
}

# Attach Policies to Role
attach_policies_to_role() {
    log "Attaching policies to role..."
    
    # Attach custom policy
    policy_arn="arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):policy/$POLICY_NAME"
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "$policy_arn" || {
        log "ERROR: Failed to attach custom policy"
        return 1
    }
    
    # Attach AWS managed policies
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess" || {
        log "ERROR: Failed to attach CloudFormation policy"
        return 1
    }
    
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/AmazonEC2FullAccess" || {
        log "ERROR: Failed to attach EC2 policy"
        return 1
    }
}

# Main execution
main() {
    # Ensure AWS CLI is available
    command -v aws >/dev/null 2>&1 || {
        log "ERROR: AWS CLI is not installed"
        exit 1
    }
    
    # Cleanup existing resources
    cleanup_existing_resources
    
    # Create role and policy
    create_deployment_role
    create_deployment_policy
    
    # Attach policies
    attach_policies_to_role
    
    # Verify role creation
    log "Verifying role creation..."
    role_arn=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
    log "Role ARN: $role_arn"
    
    log "IAM Role and Policy created successfully!"
}

# Run the main function
main