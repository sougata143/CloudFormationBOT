import subprocess
import sys
import json
from datetime import datetime

class DependencyScanner:
    def __init__(self, requirements_file):
        """
        Initialize Dependency Scanner
        
        :param requirements_file: Path to requirements file
        """
        self.requirements_file = requirements_file
        self.scan_report = {
            'timestamp': datetime.now().isoformat(),
            'vulnerabilities': [],
            'summary': {
                'total_dependencies': 0,
                'vulnerable_dependencies': 0,
                'severity_counts': {
                    'critical': 0,
                    'high': 0,
                    'medium': 0,
                    'low': 0
                }
            }
        }

    def run_safety_scan(self):
        """
        Run safety vulnerability scan
        """
        try:
            # Run safety check
            result = subprocess.run(
                ['safety', 'check', '-r', self.requirements_file, '--output', 'json'],
                capture_output=True,
                text=True
            )
            
            # Parse vulnerability results
            vulnerabilities = json.loads(result.stdout)
            
            for vuln in vulnerabilities:
                self.scan_report['vulnerabilities'].append({
                    'package': vuln['package'],
                    'version': vuln['version'],
                    'vulnerability_id': vuln['vulnerability_id'],
                    'severity': vuln['severity'],
                    'description': vuln['description']
                })
                
                # Update severity counts
                severity = vuln['severity'].lower()
                if severity in self.scan_report['summary']['severity_counts']:
                    self.scan_report['summary']['severity_counts'][severity] += 1
            
            # Update summary
            self.scan_report['summary']['total_dependencies'] = len(self._get_dependencies())
            self.scan_report['summary']['vulnerable_dependencies'] = len(vulnerabilities)
        
        except Exception as e:
            print(f"Vulnerability scan error: {e}")

    def _get_dependencies(self):
        """
        Get list of dependencies from requirements file
        """
        with open(self.requirements_file, 'r') as f:
            return [line.strip() for line in f if line.strip() and not line.startswith('#') and not line.startswith('-')]

    def generate_report(self, output_file=None):
        """
        Generate and optionally save vulnerability report
        
        :param output_file: Path to save JSON report
        """
        if output_file:
            with open(output_file, 'w') as f:
                json.dump(self.scan_report, f, indent=2)
        
        return self.scan_report

def main():
    # Scan production and development requirements
    production_scanner = DependencyScanner('/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/requirements/production.txt')
    development_scanner = DependencyScanner('/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/requirements/development.txt')

    # Run vulnerability scans
    production_scanner.run_safety_scan()
    development_scanner.run_safety_scan()

    # Generate reports
    production_report = production_scanner.generate_report(
        '/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/reports/production_vulnerabilities.json'
    )
    development_report = development_scanner.generate_report(
        '/Users/sougataroy/Documents/Developer/Code/BOT/CloudFormationBOT/reports/development_vulnerabilities.json'
    )

    # Print summary
    print("Production Vulnerabilities Summary:")
    print(json.dumps(production_report['summary'], indent=2))
    print("\nDevelopment Vulnerabilities Summary:")
    print(json.dumps(development_report['summary'], indent=2))

if __name__ == '__main__':
    main()