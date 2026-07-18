locals {
  nexus_user_data = <<-EOF
#!/bin/bash
set -euxo pipefail

# =========================================================
# System preparation
# =========================================================

sudo dnf clean all || true
sudo rm -rf /var/cache/dnf || true
sudo dnf makecache || true

# Install required packages
sudo dnf -y install \
  java-21-openjdk \
  wget \
  tar \
  curl \
  unzip \
  shadow-utils

# =========================================================
# Verify Java installation
# =========================================================

echo "Java version:"
java -version

# =========================================================
# Create Nexus directories
# =========================================================

sudo mkdir -p /app

cd /app

# =========================================================
# Create Nexus user
# =========================================================

if ! id nexus >/dev/null 2>&1; then
  sudo useradd \
    --system \
    --home-dir /app/nexus \
    --shell /sbin/nologin \
    nexus
fi

# =========================================================
# Download Nexus Repository Manager
# =========================================================

NEXUS_VERSION="3.87.1-01"

echo "Downloading Nexus Repository Manager..."

sudo wget -O /app/nexus.tar.gz \
https://download.sonatype.com/nexus/3/nexus-$${NEXUS_VERSION}-linux-x86_64.tar.gz

# Extract package
sudo tar -xzf /app/nexus.tar.gz -C /app

# Backup old installation if it exists
if [ -d /app/nexus ]; then
  sudo mv /app/nexus /app/nexus-old-$(date +%s)
fi

# Rename extracted directory
sudo mv /app/nexus-$${NEXUS_VERSION} /app/nexus

# Create Sonatype work directory
sudo mkdir -p /app/sonatype-work

# =========================================================
# Set ownership and permissions
# =========================================================

sudo chown -R nexus:nexus \
  /app/nexus \
  /app/sonatype-work

sudo chmod 755 \
  /app \
  /app/nexus \
  /app/nexus/bin

# =========================================================
# Configure Nexus to run as nexus user
# =========================================================

sudo tee /app/nexus/bin/nexus.rc > /dev/null <<NEXUSRC
run_as_user="nexus"
NEXUSRC

# =========================================================
# Configure Nexus JVM memory
# =========================================================

echo "Configuring JVM memory..."

sudo sed -i 's/^-Xms.*/-Xms512m/' \
/app/nexus/bin/nexus.vmoptions

sudo sed -i 's/^-Xmx.*/-Xmx512m/' \
/app/nexus/bin/nexus.vmoptions

sudo sed -i 's/^-XX:MaxDirectMemorySize=.*/-XX:MaxDirectMemorySize=512m/' \
/app/nexus/bin/nexus.vmoptions

# =========================================================
# Create systemd service
# =========================================================

echo "Creating Nexus systemd service..."

sudo tee /etc/systemd/system/nexus.service > /dev/null <<SERVICE
[Unit]
Description=Nexus Repository Manager
After=network.target

[Service]
Type=forking

LimitNOFILE=65536

User=nexus
Group=nexus

ExecStart=/app/nexus/bin/nexus start
ExecStop=/app/nexus/bin/nexus stop

Restart=on-abort

TimeoutStartSec=600
TimeoutStopSec=600

[Install]
WantedBy=multi-user.target
SERVICE

# =========================================================
# SELinux support (if enabled)
# =========================================================

if command -v getenforce >/dev/null 2>&1; then
  sudo chcon -t bin_t /app/nexus/bin/nexus || true
fi

# =========================================================
# Start Nexus
# =========================================================

sudo systemctl daemon-reload

sudo systemctl enable nexus

sudo systemctl start nexus

# =========================================================
# Wait for Nexus startup
# =========================================================

echo "Waiting for Nexus to start..."

for i in {1..90}; do
  if curl -fsS http://localhost:8081 >/dev/null; then
    echo "Nexus is running"
    break
  fi

  echo "Still waiting for Nexus..."
  sleep 10
done

# =========================================================
# Install New Relic Infrastructure Agent
# =========================================================

echo "Installing New Relic Infrastructure Agent..."

curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash

sudo NEW_RELIC_API_KEY="" \
NEW_RELIC_ACCOUNT_ID="" \
NEW_RELIC_REGION="EU" \
/usr/local/bin/newrelic install -y || true

# =========================================================
# Set hostname
# =========================================================

sudo hostnamectl set-hostname Nexus

# =========================================================
# Final output
# =========================================================

PUBLIC_IP=\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "================================================="
echo "Nexus Repository Manager installation completed"
echo "Access URL: http://$${PUBLIC_IP}:8081"
echo "================================================="

# Print Nexus admin password location
echo "Initial Nexus admin password:"
sudo cat /app/sonatype-work/nexus3/admin.password || true

EOF
}