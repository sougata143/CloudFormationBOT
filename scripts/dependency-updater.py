import subprocess
import sys
import json
from datetime import datetime

class DependencyUpdater:
    def __init__(self, requirements_file):
        """
        Initialize Dependency Updater
        
        :param requirements_file: Path to requirements file
        """
        self.requirements_file = requirements_file
        self.update_report = {
            'timestamp': datetime.now().isoformat(),
            'updated_packages': [],
            'failed_updates': []
        }

    def update_dependencies(self):
        """
        Update dependencies to latest compatible versions
        """
        try:
            # Read current requirements
            with open(self.requirements_file, 'r') as f:
                requirements = [line.strip() for line in f if line.strip() and not line.startswith('#')]

            for req in requirements:
                try:
                    # Extract package name
                    package = req.split('==')[0]
                    
                    # Check for latest version
                    result = subprocess.run(
                        [sys.executable, '-m', 'pip', 'install', f'{package}=='],
                        capture_output=True,
                        text=True
                    )
                    
                    # Parse latest version
                    latest_version = result.stdout.strip().split()[-1]
                    
                    # Update requirements file
                    self._update_requirements_file(package, latest_version)
                    
                    self.update_report['updated_packages'].append({
                        'package': package,
                        'old_version': req,
                        'new_version': f'{package}=={latest_version}'
                    })
                
                except Exception as pkg_error:
                    self.update_report['failed_updates'].append({
                        'package': package,
                        'error': str(pkg_error)
                    })
        
        except Exception as e:
            print(f"Dependency update error: {e}")

    def _update_requirements_file(self, package, version):
        """
        Update requirements file with new package version
        
        :param package: Package name
        :param version: New version
        """
        with open(self.requirements_file, 'r') as f:
            lines = f.readlines()
        
        with open(self.requirements_file, 'w') as f:
            for line in lines:
                if line.startswith(f'{package}=='):
                    f.write(f'{package}=={version}\n')
                else:
                    f.write(line)

    def generate_report(self, output_file=None):
        """
        Generate and optionally save update report
        
        :param output_file: Path to save JSON report
        """
        if output_file:
            with open(output_file, 'w') as f:
                json.dump(self.update_report, f, indent=2)
        
        return self.update_report

def main():
    # Update production and development requirements
    production_updater = DependencyUpdater('/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/requirements/production.txt')
    development_updater = DependencyUpdater('/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/requirements/development.txt')

    # Run dependency updates
    production_updater.update_dependencies()
    development_updater.update_dependencies()

    # Generate reports
    production_report = production_updater.generate_report(
        '/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/reports/production_updates.json'
    )
    development_report = development_updater.generate_report(
        '/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/reports/development_updates.json'
    )

    # Print summary
    print("Production Dependency Updates:")
    print(json.dumps(production_report['updated_packages'], indent=2))
    print("\nDevelopment Dependency Updates:")
    print(json.dumps(development_report['updated_packages'], indent=2))

if __name__ == '__main__':
    main()