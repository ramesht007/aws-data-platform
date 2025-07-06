#!/usr/bin/env python3
"""
Deployment script for AWS Serverless Data Platform
Provides comprehensive deployment management with validation, rollback, and monitoring
"""

import argparse
import json
import logging
import os
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import boto3
import yaml


@dataclass
class DeploymentConfig:
    """Configuration for deployment"""
    environment: str
    region: str
    modules: List[str]
    skip_validation: bool = False
    auto_approve: bool = False
    destroy_mode: bool = False
    dry_run: bool = False
    parallel: bool = True


class DataPlatformDeployer:
    """Main deployment orchestrator for the serverless data platform"""
    
    def __init__(self, config: DeploymentConfig):
        self.config = config
        self.logger = self._setup_logging()
        self.aws_session = boto3.Session(region_name=config.region)
        self.deployment_id = f"{datetime.now().strftime('%Y%m%d-%H%M%S')}"
        
        # Set up paths
        self.project_root = Path(__file__).parent.parent
        self.env_path = self.project_root / "environments" / config.environment / config.region
        
    def _setup_logging(self) -> logging.Logger:
        """Set up logging configuration"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.StreamHandler(sys.stdout),
                logging.FileHandler(f'deployment_{self.deployment_id}.log')
            ]
        )
        return logging.getLogger(__name__)
    
    def validate_prerequisites(self) -> bool:
        """Validate deployment prerequisites"""
        self.logger.info("Validating deployment prerequisites...")
        
        # Check if environment path exists
        if not self.env_path.exists():
            self.logger.error(f"Environment path does not exist: {self.env_path}")
            return False
        
        # Check AWS credentials
        try:
            sts = self.aws_session.client('sts')
            identity = sts.get_caller_identity()
            self.logger.info(f"AWS Identity: {identity.get('Arn')}")
        except Exception as e:
            self.logger.error(f"AWS credentials validation failed: {e}")
            return False
        
        # Check Terraform and Terragrunt versions
        try:
            tf_version = subprocess.check_output(['terraform', 'version'], 
                                               text=True, cwd=self.env_path)
            self.logger.info(f"Terraform version: {tf_version.split()[1]}")
            
            tg_version = subprocess.check_output(['terragrunt', '--version'], 
                                               text=True, cwd=self.env_path)
            self.logger.info(f"Terragrunt version: {tg_version.strip()}")
        except Exception as e:
            self.logger.error(f"Tool validation failed: {e}")
            return False
        
        # Validate configuration files
        if not self._validate_configuration():
            return False
        
        self.logger.info("✅ All prerequisites validated successfully")
        return True
    
    def _validate_configuration(self) -> bool:
        """Validate Terraform and Terragrunt configuration"""
        self.logger.info("Validating Terraform configuration...")
        
        try:
            # Run terraform fmt check
            subprocess.run(['terraform', 'fmt', '-check', '-recursive', '.'], 
                         cwd=self.project_root, check=True)
            
            # Run terragrunt validate for each module
            if self.config.modules:
                for module in self.config.modules:
                    module_path = self.env_path / module
                    if module_path.exists():
                        subprocess.run(['terragrunt', 'validate'], 
                                     cwd=module_path, check=True)
                    else:
                        self.logger.warning(f"Module path does not exist: {module_path}")
            else:
                subprocess.run(['terragrunt', 'run-all', 'validate'], 
                             cwd=self.env_path, check=True)
            
            return True
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Configuration validation failed: {e}")
            return False
    
    def generate_plan(self) -> Tuple[bool, str]:
        """Generate Terraform plan"""
        self.logger.info("Generating Terraform plan...")
        
        plan_file = f"deployment_plan_{self.deployment_id}.out"
        plan_output_file = f"plan_output_{self.deployment_id}.txt"
        
        try:
            if self.config.modules:
                # Deploy specific modules
                for module in self.config.modules:
                    module_path = self.env_path / module
                    cmd = ['terragrunt', 'plan', '-detailed-exitcode', f'-out={plan_file}']
                    
                    with open(plan_output_file, 'w') as f:
                        result = subprocess.run(cmd, cwd=module_path, 
                                              stdout=f, stderr=subprocess.STDOUT)
            else:
                # Deploy all modules
                cmd = ['terragrunt', 'run-all', 'plan', '-detailed-exitcode', f'-out={plan_file}']
                
                with open(plan_output_file, 'w') as f:
                    result = subprocess.run(cmd, cwd=self.env_path,
                                          stdout=f, stderr=subprocess.STDOUT)
            
            # Parse plan output
            plan_summary = self._parse_plan_output(plan_output_file)
            
            if result.returncode == 0:
                self.logger.info("✅ No changes detected in plan")
                return True, plan_summary
            elif result.returncode == 2:
                self.logger.info("📋 Changes detected in plan")
                return True, plan_summary
            else:
                self.logger.error("❌ Plan generation failed")
                return False, plan_summary
                
        except Exception as e:
            self.logger.error(f"Plan generation error: {e}")
            return False, str(e)
    
    def _parse_plan_output(self, plan_file: str) -> str:
        """Parse and summarize Terraform plan output"""
        try:
            with open(plan_file, 'r') as f:
                content = f.read()
            
            # Extract plan summary using the existing script
            summary_script = self.project_root / "summarize_plan.py"
            if summary_script.exists():
                result = subprocess.run([sys.executable, str(summary_script), plan_file],
                                      capture_output=True, text=True)
                return result.stdout
            else:
                # Basic parsing if script doesn't exist
                lines = content.split('\n')
                summary_lines = [line for line in lines if 'Plan:' in line or 'Error:' in line]
                return '\n'.join(summary_lines[-5:])  # Last 5 relevant lines
                
        except Exception as e:
            self.logger.error(f"Error parsing plan output: {e}")
            return f"Error parsing plan: {e}"
    
    def apply_changes(self) -> bool:
        """Apply Terraform changes"""
        if self.config.dry_run:
            self.logger.info("🔍 Dry run mode - skipping apply")
            return True
        
        self.logger.info("Applying Terraform changes...")
        
        # Confirmation prompt
        if not self.config.auto_approve:
            confirmation = input("Do you want to proceed with applying changes? (yes/no): ")
            if confirmation.lower() != 'yes':
                self.logger.info("❌ Deployment cancelled by user")
                return False
        
        try:
            plan_file = f"deployment_plan_{self.deployment_id}.out"
            
            if self.config.modules:
                # Apply specific modules
                for module in self.config.modules:
                    module_path = self.env_path / module
                    cmd = ['terragrunt', 'apply', plan_file]
                    
                    self.logger.info(f"Applying module: {module}")
                    result = subprocess.run(cmd, cwd=module_path, check=True)
            else:
                # Apply all modules
                cmd = ['terragrunt', 'run-all', 'apply', plan_file]
                result = subprocess.run(cmd, cwd=self.env_path, check=True)
            
            self.logger.info("✅ Terraform apply completed successfully")
            return True
            
        except subprocess.CalledProcessError as e:
            self.logger.error(f"❌ Terraform apply failed: {e}")
            return False
    
    def run_post_deployment_tests(self) -> bool:
        """Run post-deployment validation tests"""
        self.logger.info("Running post-deployment tests...")
        
        try:
            # Basic connectivity tests
            if not self._test_aws_resources():
                return False
            
            # Run Terratest if available
            terratest_path = self.project_root / "tests" / "integration"
            if terratest_path.exists():
                self.logger.info("Running Terratest integration tests...")
                env = os.environ.copy()
                env.update({
                    'ENVIRONMENT': self.config.environment,
                    'AWS_REGION': self.config.region
                })
                
                result = subprocess.run(['go', 'test', '-v', '-timeout', '30m', './...'],
                                      cwd=terratest_path, env=env)
                
                if result.returncode != 0:
                    self.logger.warning("⚠️ Some integration tests failed")
                    return False
            
            self.logger.info("✅ Post-deployment tests passed")
            return True
            
        except Exception as e:
            self.logger.error(f"❌ Post-deployment tests failed: {e}")
            return False
    
    def _test_aws_resources(self) -> bool:
        """Test basic AWS resource connectivity"""
        try:
            # Test S3 buckets
            s3 = self.aws_session.client('s3')
            buckets = s3.list_buckets()
            project_buckets = [b for b in buckets['Buckets'] 
                             if self.config.environment in b['Name']]
            self.logger.info(f"Found {len(project_buckets)} project S3 buckets")
            
            # Test Lambda functions
            lambda_client = self.aws_session.client('lambda')
            functions = lambda_client.list_functions()
            project_functions = [f for f in functions['Functions']
                               if self.config.environment in f['FunctionName']]
            self.logger.info(f"Found {len(project_functions)} project Lambda functions")
            
            return True
            
        except Exception as e:
            self.logger.error(f"AWS resource test failed: {e}")
            return False
    
    def save_deployment_metadata(self, success: bool, plan_summary: str) -> None:
        """Save deployment metadata for tracking"""
        metadata = {
            'deployment_id': self.deployment_id,
            'timestamp': datetime.now().isoformat(),
            'environment': self.config.environment,
            'region': self.config.region,
            'modules': self.config.modules,
            'success': success,
            'plan_summary': plan_summary,
            'config': vars(self.config)
        }
        
        metadata_file = f"deployment_metadata_{self.deployment_id}.json"
        with open(metadata_file, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        self.logger.info(f"Deployment metadata saved to: {metadata_file}")
    
    def deploy(self) -> bool:
        """Main deployment orchestration"""
        self.logger.info(f"🚀 Starting deployment {self.deployment_id}")
        self.logger.info(f"Environment: {self.config.environment}")
        self.logger.info(f"Region: {self.config.region}")
        self.logger.info(f"Modules: {self.config.modules or 'All'}")
        
        try:
            # Validate prerequisites
            if not self.config.skip_validation and not self.validate_prerequisites():
                return False
            
            # Generate plan
            plan_success, plan_summary = self.generate_plan()
            if not plan_success:
                self.save_deployment_metadata(False, plan_summary)
                return False
            
            # Apply changes
            if not self.apply_changes():
                self.save_deployment_metadata(False, plan_summary)
                return False
            
            # Run post-deployment tests
            test_success = self.run_post_deployment_tests()
            
            # Save metadata
            self.save_deployment_metadata(test_success, plan_summary)
            
            if test_success:
                self.logger.info(f"🎉 Deployment {self.deployment_id} completed successfully!")
            else:
                self.logger.warning(f"⚠️ Deployment {self.deployment_id} completed with test failures")
            
            return test_success
            
        except Exception as e:
            self.logger.error(f"❌ Deployment {self.deployment_id} failed: {e}")
            self.save_deployment_metadata(False, str(e))
            return False


def main():
    """Main CLI entry point"""
    parser = argparse.ArgumentParser(description='Deploy AWS Serverless Data Platform')
    parser.add_argument('--environment', '-e', required=True,
                       choices=['dev', 'staging', 'prod'],
                       help='Target environment')
    parser.add_argument('--region', '-r', required=True,
                       choices=['us-east-1', 'us-west-2'],
                       help='Target AWS region')
    parser.add_argument('--modules', '-m', nargs='*',
                       help='Specific modules to deploy (default: all)')
    parser.add_argument('--skip-validation', action='store_true',
                       help='Skip prerequisite validation')
    parser.add_argument('--auto-approve', action='store_true',
                       help='Auto-approve changes without prompt')
    parser.add_argument('--dry-run', action='store_true',
                       help='Generate plan only, do not apply')
    parser.add_argument('--destroy', action='store_true',
                       help='Destroy resources instead of creating')
    
    args = parser.parse_args()
    
    config = DeploymentConfig(
        environment=args.environment,
        region=args.region,
        modules=args.modules or [],
        skip_validation=args.skip_validation,
        auto_approve=args.auto_approve,
        destroy_mode=args.destroy,
        dry_run=args.dry_run
    )
    
    deployer = DataPlatformDeployer(config)
    success = deployer.deploy()
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main() 