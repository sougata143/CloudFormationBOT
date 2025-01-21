aws cloudformation create-stack \
  --stack-name monitoring-sns-topics-dev \
  --template-body file://infrastructure/cloudformation/monitoring-sns-topics.yaml \
  --parameters ParameterKey=Environment,ParameterValue=dev \
  --capabilities CAPABILITY_IAM