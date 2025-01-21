#!/bin/bash

# IAM Role and Policy Setup for Microservices Infrastructure

# Set strict error handling
set -euo pipefail

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Function to create role if not exists
create_role_if_not_exists() {
    local role_name="$1"
    local trust_policy_file="$2"
    
    # Check if role exists
    if ! aws iam get-role --role-name "${role_name}" &> /dev/null; then
        log "Creating role: ${role_name}"
        aws iam create-role \
            --role-name "${role_name}" \
            --assume-role-policy-document "file://${trust_policy_file}"
    else
        log "Role ${role_name} already exists. Updating trust policy."
        aws iam update-assume-role-policy \
            --role-name "${role_name}" \
            --policy-document "file://${trust_policy_file}"
    fi
}

# Function to create or update IAM policy
create_or_update_policy() {
    local policy_name="$1"
    local policy_file="$2"
    local account_id="$3"
    
    local policy_arn="arn:aws:iam::${account_id}:policy/${policy_name}"
    
    # Check if policy exists
    if ! aws iam get-policy --policy-arn "${policy_arn}" &> /dev/null; then
        log "Creating policy: ${policy_name}"
        aws iam create-policy \
            --policy-name "${policy_name}" \
            --policy-document "file://${policy_file}"
    else
        log "Policy ${policy_name} already exists. Updating policy."
        # Get the latest version of the policy
        local version=$(aws iam list-policy-versions \
            --policy-arn "${policy_arn}" \
            --query 'Versions[?!IsDefaultVersion].VersionId' \
            --output text)
        
        if [[ -n "${version}" ]]; then
            # Delete the non-default version
            aws iam delete-policy-version \
                --policy-arn "${policy_arn}" \
                --version-id "${version}"
        fi
        
        # Create a new version of the policy
        aws iam create-policy-version \
            --policy-arn "${policy_arn}" \
            --policy-document "file://${policy_file}" \
            --set-as-default
    fi
}

# Function to attach policy if not attached
attach_policy_if_not_exists() {
    local role_name="$1"
    local policy_arn="$2"
    
    # Check if policy is already attached
    if ! aws iam list-attached-role-policies --role-name "${role_name}" \
        --query "AttachedPolicies[?PolicyArn=='${policy_arn}']" \
        --output text | grep -q "${policy_arn}"; then
        
        log "Attaching policy ${policy_arn} to role ${role_name}"
        aws iam attach-role-policy \
            --role-name "${role_name}" \
            --policy-arn "${policy_arn}"
    else
        log "Policy ${policy_arn} already attached to role ${role_name}"
    fi
}

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)

# Create IAM Policy Documents Directory
mkdir -p /tmp/iam-policies

# 1. Comprehensive Deployment Policy
cat > /tmp/iam-policies/microservices-deployment-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudformation:*",
                "ec2:*",
                "rds:*",
                "s3:*",
                "ecs:*",
                "ecr:*",
                "cloudwatch:*",
                "logs:*",
                "sns:*",
                "lambda:*",
                "events:*",
                "iam:*",
                "kms:*",
                "secretsmanager:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF

# 2. Trust Policy
cat > /tmp/iam-policies/trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": [
                    "cloudformation.amazonaws.com",
                    "ec2.amazonaws.com",
                    "ecs.amazonaws.com",
                    "lambda.amazonaws.com"
                ]
            },
            "Action": "sts:AssumeRole"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${ACCOUNT_ID}:root"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

# Create or Update Custom Policy
create_or_update_policy "MicroservicesDeploymentPolicy" "/tmp/iam-policies/microservices-deployment-policy.json" "${ACCOUNT_ID}"

# Create or Update MicroservicesDeploymentRole
create_role_if_not_exists "MicroservicesDeploymentRole" "/tmp/iam-policies/trust-policy.json"

# Attach Deployment Policy to Role
attach_policy_if_not_exists "MicroservicesDeploymentRole" "arn:aws:iam::${ACCOUNT_ID}:policy/MicroservicesDeploymentPolicy"

# Create or Update Instance Profile
if ! aws iam get-instance-profile --instance-profile-name MicroservicesInstanceProfile &> /dev/null; then
    log "Creating Instance Profile"
    aws iam create-instance-profile \
        --instance-profile-name MicroservicesInstanceProfile
fi

# Add Role to Instance Profile if not already added
if ! aws iam get-instance-profile --instance-profile-name MicroservicesInstanceProfile \
    --query 'InstanceProfile.Roles[?RoleName==`MicroservicesDeploymentRole`]' \
    --output text | grep -q "MicroservicesDeploymentRole"; then
    
    log "Adding Role to Instance Profile"
    aws iam add-role-to-instance-profile \
        --instance-profile-name MicroservicesInstanceProfile \
        --role-name MicroservicesDeploymentRole
fi

# Service Roles Configuration
SERVICE_ROLES=(
    "ECSTaskExecutionRole:ecs-tasks.amazonaws.com"
    "LambdaExecutionRole:lambda.amazonaws.com"
    "CloudFormationDeploymentRole:cloudformation.amazonaws.com"
)

# Create Service-Specific Roles
for role_config in "${SERVICE_ROLES[@]}"; do
    # Split role name and service
    IFS=':' read -r ROLE_NAME SERVICE <<< "${role_config}"

    # Create trust policy for specific service
    cat > "/tmp/iam-policies/${ROLE_NAME}-trust-policy.json" << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "${SERVICE}"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

    # Create or update role
    create_role_if_not_exists "${ROLE_NAME}" "/tmp/iam-policies/${ROLE_NAME}-trust-policy.json"

    # Attach appropriate managed policies based on role type
    case "${ROLE_NAME}" in
        ECSTaskExecutionRole)
            attach_policy_if_not_exists "${ROLE_NAME}" "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
            ;;
        LambdaExecutionRole)
            attach_policy_if_not_exists "${ROLE_NAME}" "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
            ;;
        CloudFormationDeploymentRole)
            attach_policy_if_not_exists "${ROLE_NAME}" "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess"
            ;;
    esac
done

# Clean up temporary files
rm -rf /tmp/iam-policies

log "IAM Role and Policy Setup Complete"

# Output role details
echo "Roles Created/Updated:"
echo "1. MicroservicesDeploymentRole"
echo "2. MicroservicesInstanceProfile"
echo "3. ECSTaskExecutionRole"
echo "4. LambdaExecutionRole"
echo "5. CloudFormationDeploymentRole"