#!/bin/bash

# Set strict error handling
set -euo pipefail

# Enhanced CloudFormation Deployment Logging
LOG_DIR="/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/logs/deployment_debug"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DEBUG_LOG="$LOG_DIR/cloudformation_debug_${TIMESTAMP}.log"

# Install dependencies
pip install cfn-lint awscli

# Function to log stack events
log_stack_events() {
    local stack_name="$1"
    echo "==== Stack: $stack_name ====" >> "$DEBUG_LOG"
    aws cloudformation describe-stack-events \
        --stack-name "$stack_name" \
        --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]' \
        --region us-east-1 >> "$DEBUG_LOG" 2>&1
}

# Stacks to debug
STACKS=(
    "microservice-monitoring-scheduled-jobs-dev"
    "microservice-route53-stack-dev"
    "microservice-database-stack-dev"
    "microservice-microservices-stack-dev"
    "microservice-frontend-stack-dev"
    "microservice-jenkins-pipeline-dev"
    "microservice-disaster-recovery-stack-dev"
    "microservice-monitoring-stack-dev"
)

# Log events for each stack
for stack in "${STACKS[@]}"; do
    log_stack_events "$stack"
done

# Validate CloudFormation templates
echo "Validating CloudFormation Templates..." >> "$DEBUG_LOG"
for template in infrastructure/cloudformation/*.yaml; do
    echo "Validating $template" >> "$DEBUG_LOG"
    cfn-lint "$template" >> "$DEBUG_LOG" 2>&1
done

echo "Debugging log saved to $DEBUG_LOG"

# Validate all templates
# for template in infrastructure/cloudformation/*.yaml; do
#     cfn-lint "$template"
# done