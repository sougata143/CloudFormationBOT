#!/bin/bash
set -e

# Jenkins Installation and Configuration Script

# Update system packages
sudo yum update -y

# Install Java
sudo yum install java-11-amazon-corretto-headless -y

# Add Jenkins repository
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key

# Install Jenkins
sudo yum install jenkins -y

# Install Docker
sudo amazon-linux-extras install docker -y
sudo service docker start
sudo usermod -a -G docker jenkins

# Install AWS CLI and tools
sudo yum install awscli -y
sudo pip3 install boto3 github-webhook

# Configure Jenkins service
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Open firewall ports
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload

# Generate initial admin password
JENKINS_PASS=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)
echo "Jenkins Initial Admin Password: $JENKINS_PASS"

# Install recommended plugins
sudo jenkins-plugin-cli --plugins \
    git github amazon-ecr aws-credentials \
    pipeline-aws docker-workflow

# Set up Jenkins security
sudo tee /var/lib/jenkins/config.xml << EOF
<?xml version='1.1' encoding='UTF-8'?>
<hudson>
  <disabledAdministrativeMonitors/>
  <version>2.319.1</version>
  <numExecutors>2</numExecutors>
  <mode>NORMAL</mode>
  <useSecurity>true</useSecurity>
  <authorizationStrategy class="hudson.security.ProjectMatrixAuthorizationStrategy">
    <permission>hudson.model.Computer.Configure:authenticated</permission>
    <permission>hudson.model.Computer.Delete:authenticated</permission>
    <permission>hudson.model.Hudson.Administer:authenticated</permission>
  </authorizationStrategy>
  <securityRealm class="hudson.security.HudsonPrivateSecurityRealm">
    <disableSignup>true</disableSignup>
    <enableCaptcha>false</enableCaptcha>
  </securityRealm>
</hudson>
EOF

echo "Jenkins server setup complete!"