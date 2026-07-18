locals {
  jenkins_script = <<-EOT
#!/bin/bash
set -euxo pipefail

# =========================================================
# System preparation
# =========================================================

# Clean DNF cache to avoid broken metadata issues
sudo dnf clean all || true
sudo rm -rf /var/cache/dnf || true
sudo dnf makecache || true

# Install required packages only
sudo dnf -y install \
  fontconfig \
  java-21-openjdk \
  git \
  wget \
  maven \
  curl \
  unzip

# =========================================================
# Jenkins installation
# =========================================================

# Import official Jenkins GPG key
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Add Jenkins repository
sudo wget -O /etc/yum.repos.d/jenkins.repo \
https://pkg.jenkins.io/redhat-stable/jenkins.repo

# Install Jenkins
sudo dnf -y install jenkins

# Create Jenkins admin user automatically
sudo mkdir -p /var/lib/jenkins/init.groovy.d

sudo tee /var/lib/jenkins/init.groovy.d/admin-user.groovy > /dev/null <<GROOVY
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.get()

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin", "${var.jenkins_admin_password}")

instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)

instance.setAuthorizationStrategy(strategy)

instance.save()
GROOVY

# Set correct ownership
sudo chown -R jenkins:jenkins /var/lib/jenkins/init.groovy.d

# Enable and start Jenkins
sudo systemctl daemon-reload
sudo systemctl enable jenkins
sudo systemctl start jenkins

# =========================================================
# Docker installation
# =========================================================

# Remove only old Docker packages
sudo dnf remove -y \
  docker \
  docker-client \
  docker-client-latest \
  docker-common \
  docker-latest \
  docker-latest-logrotate \
  docker-logrotate \
  docker-engine || true

# Install Docker repository
sudo dnf -y install dnf-plugins-core

sudo dnf config-manager --add-repo \
https://download.docker.com/linux/rhel/docker-ce.repo

# Install Docker
sudo dnf -y install \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# Enable Docker
sudo systemctl enable docker
sudo systemctl start docker

# Add users to Docker group
sudo usermod -aG docker ec2-user || true
sudo usermod -aG docker jenkins || true

# =========================================================
# Wait for Jenkins startup
# =========================================================

echo "Waiting for Jenkins to start..."

for i in {1..60}; do
  if curl -fsS http://localhost:8080/login >/dev/null; then
    echo "Jenkins is up"
    break
  fi

  echo "Still waiting for Jenkins..."
  sleep 10
done

# =========================================================
# Jenkins Plugin Manager
# =========================================================

sudo wget -O /opt/jenkins-plugin-manager.jar \
https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.13.0/jenkins-plugin-manager-2.13.0.jar

JENKINS_WAR=/usr/share/java/jenkins.war

# Create plugins directory
sudo mkdir -p /var/lib/jenkins/plugins

# Install plugins
sudo java -jar /opt/jenkins-plugin-manager.jar \
  --war "$${JENKINS_WAR}" \
  --plugin-download-directory /var/lib/jenkins/plugins \
  --plugins \
    ssh-agent \
    slack \
    nexus-artifact-uploader \
    maven-plugin \
    git \
    workflow-aggregator \
    pipeline-stage-view \
    docker-workflow \
    blueocean \
    terraform \
    ansible

# Correct ownership
sudo chown -R jenkins:jenkins /var/lib/jenkins/plugins

# Restart Jenkins after plugin installation
sudo systemctl restart jenkins

# =========================================================
# New Relic Infrastructure Agent
# =========================================================

ARCH=$$(uname -m)
OS_VERSION=$$(rpm -E '%%{rhel}')

# Add New Relic repository
sudo curl -fsSL \
-o /etc/yum.repos.d/newrelic-infra.repo \
https://download.newrelic.com/infrastructure_agent/linux/yum/el/$${OS_VERSION}/$${ARCH}/newrelic-infra.repo

# Refresh repository cache
sudo yum -q makecache -y \
  --disablerepo='*' \
  --enablerepo='newrelic-infra'

# Install New Relic agent
sudo dnf -y install newrelic-infra

# Configure New Relic
echo "license_key: ${var.newrelic_license_key}" | sudo tee /etc/newrelic-infra.yml > /dev/null
echo "display_name: Jenkins" | sudo tee -a /etc/newrelic-infra.yml > /dev/null

# Enable New Relic service
sudo systemctl enable newrelic-infra
sudo systemctl start newrelic-infra

# =========================================================
# Final status
# =========================================================

echo "================================================="
echo "Jenkins setup completed successfully"
echo "Jenkins URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "Username: admin"
echo "================================================="

EOT
}