import os
import sys
import json
import logging
import subprocess
from typing import List, Dict, Optional, Any, Union
from datetime import datetime
import boto3
from botocore.exceptions import ClientError
import yaml
import inquirer  # For interactive mode
import jsonschema  # For advanced validation
import argparse  # For CLI support

class ConfigValidationError(Exception):
    """Custom exception for configuration validation errors"""
    pass

class CloudFormationDeployerConfig:
    DEFAULT_CONFIG_SCHEMA = {
        "type": "object",
        "properties": {
            "global": {
                "type": "object",
                "required": ["default_region", "infrastructure_dir", "stack_prefix"],
                "properties": {
                    "default_region": {"type": "string"},
                    "infrastructure_dir": {"type": "string"},
                    "stack_prefix": {"type": "string"}
                }
            },
            "logging": {
                "type": "object",
                "properties": {
                    "level": {"type": "string", "enum": ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]},
                    "directory": {"type": "string"},
                    "filename_format": {"type": "string"},
                    "console_output": {"type": "boolean"}
                }
            },
            "deployment": {
                "type": "object",
                "properties": {
                    "interactive_mode": {"type": "boolean"},
                    "default_environment": {"type": "string"},
                    "supported_environments": {
                        "type": "array",
                        "items": {"type": "string"}
                    }
                }
            }
        },
        "required": ["global", "logging", "deployment"]
    }

    def __init__(self, config_path: str = None, env: str = None):
        """
        Load configuration from YAML file with environment-specific overrides
        
        :param config_path: Path to configuration file
        :param env: Environment name for specific overrides
        """
        # Default configuration
        self.config = {
            "global": {
                "default_region": "us-west-2",
                "infrastructure_dir": "/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/cloudformation",
                "stack_prefix": "microservice"
            },
            "logging": {
                "level": "INFO",
                "directory": "logs",
                "filename_format": "cloudformation_deploy_{timestamp}.log",
                "console_output": True
            },
            "deployment": {
                "interactive_mode": True,
                "default_environment": "dev",
                "supported_environments": ["dev", "staging", "prod"]
            }
        }

        # Load configuration file if provided
        if config_path is None:
            config_path = os.path.join(
                os.path.dirname(__file__), 
                '../config/cloudformation_deployer_config.yaml'
            )
        
        if os.path.exists(config_path):
            with open(config_path, 'r') as config_file:
                file_config = yaml.safe_load(config_file)
                self._deep_merge(self.config, file_config)
        
        # Apply environment-specific overrides
        self._apply_env_overrides(env)
        
        # Apply environment variables
        self._apply_env_variables()
        
        # Validate configuration
        self._validate_config()
    
    def _deep_merge(self, base: Dict, update: Dict):
        """
        Deep merge two dictionaries
        
        :param base: Base dictionary
        :param update: Dictionary to merge into base
        """
        for key, value in update.items():
            if isinstance(value, dict):
                base[key] = self._deep_merge(base.get(key, {}), value)
            else:
                base[key] = value
        return base
    
    def _apply_env_overrides(self, env: str = None):
        """
        Apply environment-specific configuration overrides
        
        :param env: Environment name
        """
        if not env:
            env = os.environ.get('CLOUDFORMATION_ENV', 
                                 self.config['deployment']['default_environment'])
        
        # Environment-specific override file
        env_config_path = os.path.join(
            os.path.dirname(__file__), 
            f'../config/cloudformation_deployer_{env}.yaml'
        )
        
        if os.path.exists(env_config_path):
            with open(env_config_path, 'r') as env_config_file:
                env_config = yaml.safe_load(env_config_file)
                self._deep_merge(self.config, env_config)
    
    def _apply_env_variables(self):
        """
        Override configuration with environment variables
        """
        env_mapping = {
            'CLOUDFORMATION_REGION': ['global', 'default_region'],
            'CLOUDFORMATION_INFRASTRUCTURE_DIR': ['global', 'infrastructure_dir'],
            'CLOUDFORMATION_STACK_PREFIX': ['global', 'stack_prefix'],
            'CLOUDFORMATION_LOG_LEVEL': ['logging', 'level']
        }
        
        for env_var, config_path in env_mapping.items():
            value = os.environ.get(env_var)
            if value:
                current = self.config
                for key in config_path[:-1]:
                    current = current[key]
                current[config_path[-1]] = value
    
    def _validate_config(self):
        """
        Validate configuration against JSON schema
        """
        try:
            jsonschema.validate(instance=self.config, schema=self.DEFAULT_CONFIG_SCHEMA)
        except jsonschema.ValidationError as e:
            raise ConfigValidationError(f"Configuration validation failed: {e}")
    
    def get(self, *keys, default=None):
        """
        Safely retrieve nested configuration values
        
        :param keys: Nested keys to retrieve
        :param default: Default value if key not found
        :return: Configuration value
        """
        current = self.config
        for key in keys:
            if isinstance(current, dict) and key in current:
                current = current[key]
            else:
                return default
        return current

class CloudFormationDeployerCLI:
    """
    Command-line interface for CloudFormation Deployer
    """

    @staticmethod
    def parse_args():
        """
        Parse command-line arguments for CloudFormation deployment

        :return: Parsed arguments
        """
        parser = argparse.ArgumentParser(description='CloudFormation Deployment Tool')
        
        parser.add_argument('-e', '--env', 
                            choices=['dev', 'staging', 'prod'], 
                            default=None,
                            help='Deployment environment')
        
        parser.add_argument('-c', '--config', 
                            help='Path to custom configuration file')
        
        parser.add_argument('-r', '--region', 
                            help='AWS region for deployment')
        
        parser.add_argument('-i', '--infrastructure-dir', 
                            help='Directory containing CloudFormation templates')
        
        parser.add_argument('-s', '--stacks', 
                            nargs='+', 
                            help='Specific stacks to deploy')
        
        parser.add_argument('--interactive', 
                            action='store_true',
                            help='Enable interactive deployment mode')
        
        return parser.parse_args()

    @staticmethod
    def run():
        """
        Parse command-line arguments and execute deployment
        """
        parser = argparse.ArgumentParser(description='CloudFormation Deployment Tool')
        
        parser.add_argument('-e', '--env', 
                            choices=['dev', 'staging', 'prod'], 
                            default=None,
                            help='Deployment environment')
        
        parser.add_argument('-c', '--config', 
                            help='Path to custom configuration file')
        
        parser.add_argument('--interactive', 
                            action='store_true', 
                            help='Force interactive deployment mode')
        
        parser.add_argument('--dry-run', 
                            action='store_true', 
                            help='Validate templates without deployment')
        
        args = parser.parse_args()
        
        # Load configuration
        config = CloudFormationDeployerConfig(
            config_path=args.config, 
            env=args.env
        )
        
        # Override interactive mode if specified
        if args.interactive:
            config.config['deployment']['interactive_mode'] = True
        
        # Initialize deployer
        deployer = AdvancedCloudFormationDeployer(config)
        
        # Perform deployment or dry run
        if args.dry_run:
            deployer.validate_all_templates()
        else:
            deployer.deploy_stacks()

class AdvancedCloudFormationDeployer:
    def __init__(self, 
                 config: CloudFormationDeployerConfig = None,
                 infrastructure_dir: str = None, 
                 region: str = None, 
                 stack_prefix: str = None):
        """
        Advanced CloudFormation Deployer with enhanced features
        
        :param config: Configuration object
        :param infrastructure_dir: Directory containing CloudFormation templates
        :param region: AWS region for deployment
        :param stack_prefix: Prefix for stack names
        """
        # Load configuration
        self.config = config or CloudFormationDeployerConfig()
        
        # Override configuration with direct parameters
        self.infrastructure_dir = infrastructure_dir or self.config.get('global', 'infrastructure_dir')
        self.region = region or self.config.get('global', 'default_region')
        self.stack_prefix = stack_prefix or self.config.get('global', 'stack_prefix')
        
        # Setup logging
        self._setup_logging()
        
        # AWS Clients
        self.cloudformation_client = boto3.client('cloudformation', region_name=self.region)
        self.sts_client = boto3.client('sts', region_name=self.region)
        
        # Deployment tracking
        self.deployment_report = {
            'timestamp': datetime.now().isoformat(),
            'account_id': self._get_account_id(),
            'region': self.region,
            'stacks': []
        }

        # Rollback tracking
        self.rollback_stack_ids = []

    def _setup_logging(self):
        """
        Configure advanced logging with file and console output
        """
        # Create logs directory
        log_dir = self.config.get('logging', 'directory', default='logs')
        os.makedirs(log_dir, exist_ok=True)
        
        # Prepare log filename
        log_filename = self.config.get('logging', 'filename_format', default='cloudformation_deploy_{timestamp}.log')
        log_filename = log_filename.format(timestamp=datetime.now().strftime("%Y%m%d_%H%M%S"))
        log_path = os.path.join(log_dir, log_filename)
        
        # Configure logging
        logging.basicConfig(
            level=getattr(logging, self.config.get('logging', 'level', default='INFO')),
            format='%(asctime)s - %(levelname)s: %(message)s',
            handlers=[
                logging.FileHandler(log_path),
                logging.StreamHandler(sys.stdout) if self.config.get('logging', 'console_output', default=True) else logging.NullHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)

    def _get_account_id(self) -> str:
        """
        Retrieve AWS Account ID
        
        :return: AWS Account ID
        """
        try:
            return self.sts_client.get_caller_identity()['Account']
        except ClientError as e:
            self.logger.error(f"Could not retrieve AWS Account ID: {e}")
            return 'unknown'

    def find_yaml_templates(self, subdirectory: str = '') -> List[str]:
        """
        Find CloudFormation YAML templates with advanced filtering
        
        :param subdirectory: Optional subdirectory to search within
        :return: List of template file paths
        """
        search_dir = os.path.join(self.infrastructure_dir, subdirectory)
        templates = []
        for root, _, files in os.walk(search_dir):
            for file in files:
                if file.endswith(('.yml', '.yaml')) and not file.startswith('_'):
                    templates.append(os.path.join(root, file))
        return sorted(templates, key=lambda x: os.path.getsize(x))

    def load_parameter_file(self, template_path: str) -> Dict[str, Any]:
        """
        Load parameters for CloudFormation template
        
        :param template_path: Path to CloudFormation template
        :return: Dictionary of parameters
        """
        # Look for parameter files
        param_files = [
            template_path.replace('.yml', '.params.json'),
            template_path.replace('.yaml', '.params.json')
        ]
        
        for param_file in param_files:
            if os.path.exists(param_file):
                try:
                    with open(param_file, 'r') as f:
                        return json.load(f)
                except json.JSONDecodeError:
                    self.logger.warning(f"Invalid JSON in parameter file: {param_file}")
        
        return {}

    def advanced_template_validation(self, template_path: str) -> bool:
        """
        Perform comprehensive template validation
        
        :param template_path: Path to CloudFormation template
        :return: Validation result
        """
        try:
            # Read template
            with open(template_path, 'r') as f:
                template = yaml.safe_load(f)
            
            # JSON Schema for basic CloudFormation validation
            cloudformation_schema = {
                "type": "object",
                "required": ["AWSTemplateFormatVersion", "Resources"],
                "properties": {
                    "AWSTemplateFormatVersion": {"type": "string"},
                    "Description": {"type": "string"},
                    "Resources": {
                        "type": "object",
                        "minProperties": 1
                    },
                    "Parameters": {
                        "type": "object"
                    }
                }
            }
            
            # Validate against schema
            jsonschema.validate(instance=template, schema=cloudformation_schema)
            
            # AWS-specific validation
            self.cloudformation_client.validate_template(
                TemplateBody=yaml.dump(template)
            )
            
            self.logger.info(f"Advanced validation successful: {template_path}")
            return True
        
        except (jsonschema.ValidationError, ClientError) as e:
            self.logger.error(f"Advanced validation failed: {template_path}")
            self.logger.error(f"Error: {e}")
            return False

    def interactive_deployment_mode(self, templates: List[str]) -> List[str]:
        """
        Interactive mode for stack deployment selection
        
        :param templates: List of template paths
        :return: Selected templates for deployment
        """
        # Create choices for interactive selection
        template_choices = [
            (f"{os.path.basename(t)} (Size: {os.path.getsize(t)} bytes)", t) 
            for t in templates
        ]
        
        # Prompt for template selection
        questions = [
            inquirer.Checkbox(
                'templates',
                message="Select CloudFormation templates to deploy",
                choices=template_choices
            )
        ]
        
        answers = inquirer.prompt(questions)
        return answers.get('templates', [])

    def deploy_stack_with_rollback(self, template_path: str, parameters: Dict[str, Any] = None) -> Optional[Dict]:
        """
        Deploy stack with advanced rollback mechanism
        
        :param template_path: Path to CloudFormation template
        :param parameters: Optional parameters for stack
        :return: Stack deployment details
        """
        stack_name = f"{self.stack_prefix}-{os.path.basename(template_path).replace('.yml', '').replace('.yaml', '')}"
        
        try:
            # Read template
            with open(template_path, 'r') as template_file:
                template_body = template_file.read()
            
            # Prepare stack parameters
            stack_parameters = []
            if parameters:
                stack_parameters = [
                    {'ParameterKey': k, 'ParameterValue': str(v)} 
                    for k, v in parameters.items()
                ]
            
            # Deploy stack with rollback configuration
            response = self.cloudformation_client.create_stack(
                StackName=stack_name,
                TemplateBody=template_body,
                Parameters=stack_parameters,
                Capabilities=['CAPABILITY_IAM', 'CAPABILITY_NAMED_IAM'],
                OnFailure='ROLLBACK',  # Automatic rollback on failure
                RollbackConfiguration={
                    'RollbackTriggers': [
                        {
                            'Arn': f'arn:aws:cloudwatch:{self.region}:{self.deployment_report["account_id"]}:alarm:StackDeploymentAlarm',
                            'Type': 'CloudWatchAlarm'
                        }
                    ]
                }
            )
            
            # Track stack for potential manual rollback
            self.rollback_stack_ids.append(response['StackId'])
            
            # Wait for stack creation
            waiter = self.cloudformation_client.get_waiter('stack_create_complete')
            waiter.wait(StackName=stack_name)
            
            # Log successful deployment
            stack_info = {
                'stack_name': stack_name,
                'template_path': template_path,
                'stack_id': response['StackId'],
                'status': 'SUCCESS'
            }
            
            self.deployment_report['stacks'].append(stack_info)
            self.logger.info(f"Stack deployed successfully: {stack_name}")
            
            return stack_info
        
        except ClientError as e:
            error_info = {
                'stack_name': stack_name,
                'template_path': template_path,
                'error': str(e),
                'status': 'FAILED'
            }
            
            self.deployment_report['stacks'].append(error_info)
            self.logger.error(f"Stack deployment failed: {stack_name}")
            self.logger.error(f"Error: {e}")
            
            return None

    def generate_deployment_report(self, output_path: Optional[str] = None) -> Dict:
        """
        Generate deployment report
        
        :param output_path: Optional path to save report
        :return: Deployment report
        """
        # Calculate deployment summary
        self.deployment_report['total_stacks'] = len(self.deployment_report['stacks'])
        self.deployment_report['successful_stacks'] = len([
            stack for stack in self.deployment_report['stacks'] 
            if stack['status'] == 'SUCCESS'
        ])
        self.deployment_report['failed_stacks'] = len([
            stack for stack in self.deployment_report['stacks'] 
            if stack['status'] == 'FAILED'
        ])
        
        # Save report if path provided
        if output_path:
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            with open(output_path, 'w') as report_file:
                json.dump(self.deployment_report, report_file, indent=2)
        
        return self.deployment_report

    def manual_rollback(self, stack_id: str):
        """
        Manually rollback a specific stack
        
        :param stack_id: ID of the stack to rollback
        """
        try:
            self.cloudformation_client.delete_stack(StackId=stack_id)
            self.logger.info(f"Manual rollback initiated for stack: {stack_id}")
        except ClientError as e:
            self.logger.error(f"Rollback failed for stack {stack_id}: {e}")

    def deploy_stacks(self, environment: str = None, selected_stacks: List[str] = None):
        """
        Deploy CloudFormation stacks with advanced deployment strategy

        :param environment: Deployment environment
        :param selected_stacks: Optional list of specific stacks to deploy
        """
        # Find all YAML templates
        templates = self.find_yaml_templates()

        # Interactive mode or pre-selected stacks
        if self.config.get('deployment', 'interactive_mode'):
            templates = self.interactive_deployment_mode(templates)
        elif selected_stacks:
            templates = [t for t in templates if any(stack in t for stack in selected_stacks)]

        # Deploy stacks with rollback
        for template_path in templates:
            try:
                # Load parameters for the template
                parameters = self.load_parameter_file(template_path)

                # Validate template
                validation_result = self.advanced_template_validation(template_path)
                if not validation_result['is_valid']:
                    logging.error(f"Template validation failed: {template_path}")
                    continue

                # Deploy stack with rollback mechanism
                stack_details = self.deploy_stack_with_rollback(template_path, parameters)
                
                # Add to deployment report
                self.deployment_report['stacks'].append({
                    'template': template_path,
                    'stack_id': stack_details.get('StackId'),
                    'status': stack_details.get('StackStatus')
                })

            except Exception as e:
                logging.error(f"Failed to deploy stack {template_path}: {e}")
                # Optional: implement more advanced error handling or recovery

        # Generate deployment report
        self.generate_deployment_report()

def main():
    """
    Main entry point for CloudFormation Deployer CLI
    """
    try:
        # Parse CLI arguments
        args = CloudFormationDeployerCLI.parse_args()

        # Initialize deployer with environment-specific configuration
        deployer = AdvancedCloudFormationDeployer(
            config=CloudFormationDeployerConfig(config_path=args.config, env=args.env),
            region=args.region,
            infrastructure_dir=args.infrastructure_dir
        )

        # Deploy stacks
        deployer.deploy_stacks(
            environment=args.env,
            selected_stacks=args.stacks
        )

    except Exception as e:
        logging.error(f"Deployment failed: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()

# def main():
#     # Infrastructure directory
#     infrastructure_dir = '/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/cloudformation'
    
#     # Load configuration
#     config = CloudFormationDeployerConfig()
    
#     # Initialize advanced deployer
#     deployer = AdvancedCloudFormationDeployer(config)
    
#     # Find templates
#     storage_templates = deployer.find_yaml_templates('.')
    
#     # Interactive deployment mode
#     selected_templates = deployer.interactive_deployment_mode(storage_templates)
    
#     # Deploy selected templates
#     for template in selected_templates:
#         # Determine environment from parameter file
#         env = 'dev'
#         if 'staging' in template:
#             env = 'staging'
#         elif 'prod' in template:
#             env = 'prod'
        
#         # Load parameters
#         parameters = deployer.load_parameter_file(
#             f'/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/infrastructure/cloudformation/params/storage-{env}.params.json'
#         )
        
#         # Advanced validation
#         if deployer.advanced_template_validation(template):
#             # Deploy with rollback
#             deployer.deploy_stack_with_rollback(template, parameters)
    
#     # Generate deployment report
#     report = deployer.generate_deployment_report(
#         '/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/reports/cloudformation_deployment_report.json'
#     )
    
#     # Print summary
#     print("\n--- Deployment Summary ---")
#     print(f"Total Stacks: {report['total_stacks']}")
#     print(f"Successful Stacks: {report['successful_stacks']}")
#     print(f"Failed Stacks: {report['failed_stacks']}")

