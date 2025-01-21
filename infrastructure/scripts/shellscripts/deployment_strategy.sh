#!/bin/bash

# Set environment and region
export ENVIRONMENT=dev
export REGION=us-east-1

# First, deploy the network stack
aws cloudformation deploy \
    --template-file infrastructure/cloudformation/network-stack.yaml \
    --stack-name microservice-network-stack-${ENVIRONMENT} \
    --parameter-overrides Environment=${ENVIRONMENT} \
    --region ${REGION} \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM

# Retrieve VPC and Subnet details
VPC_ID=$(aws cloudformation describe-stacks \
    --stack-name microservice-network-stack-${ENVIRONMENT} \
    --query 'Stacks[0].Outputs[?OutputKey==`VPC`].OutputValue' \
    --output text)

PRIVATE_SUBNET_1=$(aws cloudformation describe-stacks \
    --stack-name microservice-network-stack-${ENVIRONMENT} \
    --query 'Stacks[0].Outputs[?OutputKey==`PrivateSubnet1`].OutputValue' \
    --output text)

PRIVATE_SUBNET_2=$(aws cloudformation describe-stacks \
    --stack-name microservice-network-stack-${ENVIRONMENT} \
    --query 'Stacks[0].Outputs[?OutputKey==`PrivateSubnet2`].OutputValue' \
    --output text)

# Deploy Database Stack
aws cloudformation deploy \
    --template-file infrastructure/cloudformation/database-stack.yaml \
    --stack-name microservice-database-stack-${ENVIRONMENT} \
    --parameter-overrides \
        Environment=${ENVIRONMENT} \
        DatabaseUsername=dbadmin \
        DatabasePassword=SecurePassword123! \
        DatabaseName=microservicedb \
        VpcId=${VPC_ID} \
        PrivateSubnet1=${PRIVATE_SUBNET_1} \
        PrivateSubnet2=${PRIVATE_SUBNET_2} \
    --region ${REGION} \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM

# Deploy Storage Stack
aws cloudformation deploy \
    --template-file infrastructure/cloudformation/storage-stack.yaml \
    --stack-name microservice-storage-stack-${ENVIRONMENT} \
    --parameter-overrides \
        Environment=${ENVIRONMENT} \
        BucketNamePrefix=microservice \
        EnableVersioning=true \
        ReplicationRoleName=microservice-replication-role \
        ReplicationRegion=${REGION} \
        ReplicationBucket="" \
    --region ${REGION} \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM

# Deploy Microservices Stack
aws cloudformation deploy \
    --template-file infrastructure/cloudformation/microservices-stack.yaml \
    --stack-name microservice-microservices-stack-${ENVIRONMENT} \
    --parameter-overrides \
        Environment=${ENVIRONMENT} \
        MicroserviceImageUri=954976299892.dkr.ecr.us-west-2.amazonaws.com/microservice-repo:latest \
    --region ${REGION} \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM

# Deploy Monitoring Stack
aws cloudformation deploy \
    --template-file infrastructure/cloudformation/monitoring-stack.yaml \
    --stack-name microservice-monitoring-stack-${ENVIRONMENT} \
    --parameter-overrides Environment=${ENVIRONMENT} \
    --region ${REGION} \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM

# Run debug script
./infrastructure/scripts/debug.sh