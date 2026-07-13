locals {
  docker_user_data = <<-EOF
#!/bin/bash
set -euxo pipefail

# =========================================================
# System update
# =========================================================

sudo apt-get update -y

# =========================================================
# Install prerequisite packages
# =========================================================

sudo apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  wget \
  unzip

# =========================================================
# Configure Docker repository
# =========================================================

sudo install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
$$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# =========================================================
# Refresh package cache
# =========================================================

sudo apt-get update -y

# =========================================================
# Install Docker Engine
# =========================================================

sudo apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# =========================================================
# Enable and start Docker
# =========================================================

sudo systemctl enable docker
sudo systemctl start docker

# =========================================================
# Add Ubuntu user to Docker group
# =========================================================

sudo usermod -aG docker ubuntu || true

# =========================================================
# Verify Docker installation
# =========================================================

docker --version

sudo docker version

# =========================================================
# Create health-check page
# =========================================================

sudo mkdir -p /var/www/html

echo "Docker server is healthy" | \
sudo tee /var/www/html/indextest.html > /dev/null

# =========================================================
# Install Nginx for health checks (optional)
# =========================================================

sudo apt-get install -y nginx

sudo systemctl enable nginx
sudo systemctl start nginx

# =========================================================
# Configure simple web page
# =========================================================

echo "<h1>Docker Host Running Successfully</h1>" | \
sudo tee /var/www/html/index.html > /dev/null

# =========================================================
# Install New Relic Infrastructure Agent
# =========================================================

echo "Installing New Relic Infrastructure Agent..."

curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash

sudo NEW_RELIC_API_KEY="${var.newrelic_api_key}" \
NEW_RELIC_ACCOUNT_ID="${var.newrelic_account_id}" \
NEW_RELIC_REGION="EU" \
/usr/local/bin/newrelic install -y || true

# =========================================================
# Set hostname
# =========================================================

sudo hostnamectl set-hostname Docker

# =========================================================
# Final output
# =========================================================

PUBLIC_IP=$$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "================================================="
echo "Docker installation completed successfully"
echo "Docker Host URL: http://$${PUBLIC_IP}"
echo "Health Check URL: http://$${PUBLIC_IP}/indextest.html"
echo "================================================="

EOF
}