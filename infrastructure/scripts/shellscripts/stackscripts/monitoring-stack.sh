#!/bin/bash

# Monitoring Stack Deployment Script
# Provides helper functions and deployment logic for monitoring infrastructure

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

deploy_monitoring_stack() {
    local environment="${1:-dev}"
    local region="${2:-us-east-1}"
    
    log "Deploying Monitoring Stacks for ${environment}"
    log "Detailed Monitoring Stack Parameters:"
    log "- Environment: ${environment}"
    log "- Region: ${region}"
    
        # Deploy monitoring SNS topics
        log "Deploying Monitoring SNS Topics"
        local sns_topics_output
        sns_topics_output=$(aws cloudformation deploy \
            --template-file "/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/cloudformation/monitoring-sns-topics.yaml" \
            --stack-name "microservice-monitoring-sns-topics-${environment}" \
            --parameter-overrides \
                Environment="${environment}" \
            --capabilities CAPABILITY_IAM \
            --region "${region}" 2>&1)
        local sns_topics_status=$?
        
        if [[ ${sns_topics_status} -ne 0 ]]; then
            log "Failed to deploy Monitoring SNS Topics" "ERROR"
            log "${sns_topics_output}" "ERROR"
            
            # Log stack events in case of failure
            log_stack_events "microservice-monitoring-sns-topics-${environment}" "${region}"
            
            return 1
        fi
        
        # Retrieve SNS topic ARNs
        local cost_alert_topic_arn
        local replication_test_topic_arn
        local disaster_recovery_topic_arn
        
        # Retrieve Cost Alert Topic ARN
        cost_alert_topic_arn=$(aws cloudformation describe-stacks \
            --stack-name "microservice-monitoring-sns-topics-${environment}" \
            --query 'Stacks[0].Outputs[?OutputKey==`CostOptimizationAlertTopicArn`].OutputValue' \
            --output text \
            --region "${region}")
        
        # Retrieve Replication Test Topic ARN
        replication_test_topic_arn=$(aws cloudformation describe-stacks \
            --stack-name "microservice-monitoring-sns-topics-${environment}" \
            --query 'Stacks[0].Outputs[?OutputKey==`ReplicationTestAlertTopicArn`].OutputValue' \
            --output text \
            --region "${region}")
        
        # Retrieve Disaster Recovery Topic ARN
        disaster_recovery_topic_arn=$(aws cloudformation describe-stacks \
            --stack-name "microservice-monitoring-sns-topics-${environment}" \
            --query 'Stacks[0].Outputs[?OutputKey==`DisasterRecoveryAlertTopicArn`].OutputValue' \
            --output text \
            --region "${region}")
        
        # Validate retrieved ARNs
        if [[ -z "${cost_alert_topic_arn}" || -z "${replication_test_topic_arn}" || -z "${disaster_recovery_topic_arn}" ]]; then
            log "Failed to retrieve all required SNS topic ARNs" "ERROR"
            log "Cost Alert Topic ARN: ${cost_alert_topic_arn}" "ERROR"
            log "Replication Test Topic ARN: ${replication_test_topic_arn}" "ERROR"
            log "Disaster Recovery Topic ARN: ${disaster_recovery_topic_arn}" "ERROR"
            return 1
        fi
        
        # Log retrieved ARNs
        log "Retrieved Topic ARNs:" "INFO"
        log "- Cost Alert Topic: ${cost_alert_topic_arn}" "INFO"
        log "- Replication Test Topic: ${replication_test_topic_arn}" "INFO"
        log "- Disaster Recovery Topic: ${disaster_recovery_topic_arn}" "INFO"
        
        # Deploy main monitoring stack
        log "Deploying Main Monitoring Stack"
        local monitoring_stack_output
        monitoring_stack_output=$(aws cloudformation deploy \
            --template-file "/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/cloudformation/monitoring-stack.yaml" \
            --stack-name "microservice-monitoring-stack-${environment}" \
            --parameter-overrides \
                Environment="${environment}" \
            --capabilities CAPABILITY_IAM \
            --region "${region}" 2>&1)
        local monitoring_stack_status=$?
        
        if [[ ${monitoring_stack_status} -ne 0 ]]; then
            log "Failed to deploy Main Monitoring Stack" "ERROR"
            log "${monitoring_stack_output}" "ERROR"
            
            # Log stack events in case of failure
            log_stack_events "microservice-monitoring-stack-${environment}" "${region}"
            
            return 1
        fi
        
        # Deploy monitoring scheduled jobs
        log "Deploying Monitoring Scheduled Jobs"
        local scheduled_jobs_output
        scheduled_jobs_output=$(aws cloudformation deploy \
            --template-file "/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/cloudformation/monitoring-scheduled-jobs.yaml" \
            --stack-name "microservice-monitoring-scheduled-jobs-${environment}" \
            --parameter-overrides \
                Environment="${environment}" \
            --capabilities CAPABILITY_IAM \
            --region "${region}" 2>&1)
        local scheduled_jobs_status=$?
        
        if [[ ${scheduled_jobs_status} -ne 0 ]]; then
            log "Failed to deploy Monitoring Scheduled Jobs" "ERROR"
            log "${scheduled_jobs_output}" "ERROR"
            
            # Log stack events in case of failure
            log_stack_events "microservice-monitoring-scheduled-jobs-${environment}" "${region}"
            
            return 1
        fi
        
        # Deploy monitoring lambda functions
        log "Deploying Monitoring Lambda Functions"
        local lambda_functions_output
        lambda_functions_output=$(aws cloudformation deploy \
            --template-file "/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/cloudformation/monitoring-lambda-functions.yaml" \
            --stack-name "microservice-monitoring-lambda-functions-${environment}" \
            --parameter-overrides \
                Environment="${environment}" \
                CostAlertTopicArn="${cost_alert_topic_arn}" \
                ReplicationTestTopicArn="${replication_test_topic_arn}" \
                DisasterRecoveryTopicArn="${disaster_recovery_topic_arn}" \
            --capabilities CAPABILITY_IAM \
            --region "${region}" 2>&1)
        local lambda_functions_status=$?
        
        if [[ ${lambda_functions_status} -ne 0 ]]; then
            log "Failed to deploy Monitoring Lambda Functions" "ERROR"
            log "${lambda_functions_output}" "ERROR"
            
            # Log stack events in case of failure
            log_stack_events "microservice-monitoring-lambda-functions-${environment}" "${region}"
            
            return 1
        fi
        
        return 0
}

export -f deploy_monitoring_stack