locals {
  sonarqube_user_data = <<-EOF
#!/bin/bash
set -euxo pipefail

# =========================================================
# System update and prerequisites
# =========================================================

sudo apt-get update -y

sudo apt-get install -y \
  openjdk-17-jdk \
  postgresql \
  postgresql-contrib \
  wget \
  unzip \
  curl \
  nginx \
  net-tools \
  gnupg2 \
  ca-certificates

# =========================================================
# Configure Linux kernel settings for SonarQube
# =========================================================

echo "Configuring system limits..."

sudo tee -a /etc/sysctl.conf > /dev/null <<SYSCTL
vm.max_map_count=262144
fs.file-max=65536
SYSCTL

sudo sysctl -p

sudo tee -a /etc/security/limits.conf > /dev/null <<LIMITS
sonar   -   nofile   65536
sonar   -   nproc    4096
LIMITS

# =========================================================
# Verify Java installation
# =========================================================

echo "Java version:"
java -version

# =========================================================
# PostgreSQL setup
# =========================================================

sudo systemctl enable postgresql
sudo systemctl start postgresql

echo "Creating SonarQube database..."

sudo -u postgres psql <<PSQL
CREATE USER sonar WITH ENCRYPTED PASSWORD 'Admin123';
CREATE DATABASE sonarqube OWNER sonar;
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;
PSQL

# =========================================================
# Download and install SonarQube
# =========================================================

SONAR_VERSION="10.4.1.88267"

cd /opt

sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-$${SONAR_VERSION}.zip

sudo unzip sonarqube-$${SONAR_VERSION}.zip

sudo mv sonarqube-$${SONAR_VERSION} sonarqube

# =========================================================
# Create SonarQube user
# =========================================================

echo "Creating SonarQube user..."

sudo groupadd sonar || true

sudo useradd \
  -c "SonarQube User" \
  -d /opt/sonarqube \
  -g sonar \
  sonar || true

sudo chown -R sonar:sonar /opt/sonarqube

# =========================================================
# Configure SonarQube
# =========================================================

echo "Configuring SonarQube..."

sudo tee -a /opt/sonarqube/conf/sonar.properties > /dev/null <<SONARCONF
sonar.jdbc.username=sonar
sonar.jdbc.password=Admin123
sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube

sonar.web.host=0.0.0.0
sonar.web.port=9000

sonar.search.javaOpts=-Xmx512m -Xms512m -XX:+HeapDumpOnOutOfMemoryError
SONARCONF

# =========================================================
# Configure SonarQube startup user
# =========================================================

sudo sed -i 's/#RUN_AS_USER=/RUN_AS_USER=sonar/g' \
/opt/sonarqube/bin/linux-x86-64/sonar.sh

# =========================================================
# Create systemd service
# =========================================================

echo "Creating SonarQube systemd service..."

sudo tee /etc/systemd/system/sonarqube.service > /dev/null <<SERVICE
[Unit]
Description=SonarQube service
After=network.target postgresql.service

[Service]
Type=forking

ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
ExecReload=/opt/sonarqube/bin/linux-x86-64/sonar.sh restart

User=sonar
Group=sonar

Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
SERVICE

# Reload systemd
sudo systemctl daemon-reload

# Enable SonarQube
sudo systemctl enable sonarqube

# Start SonarQube
sudo systemctl start sonarqube

# =========================================================
# Wait for SonarQube startup
# =========================================================

echo "Waiting for SonarQube to start..."

for i in {1..60}; do
  if curl -fsS http://localhost:9000 >/dev/null; then
    echo "SonarQube is running"
    break
  fi

  echo "Still waiting for SonarQube..."
  sleep 10
done

# =========================================================
# Configure Nginx reverse proxy
# =========================================================

echo "Configuring Nginx..."

sudo tee /etc/nginx/sites-available/sonarqube.conf > /dev/null <<NGINX
server {
    listen 80;
    server_name _;

    access_log /var/log/nginx/sonarqube.access.log;
    error_log /var/log/nginx/sonarqube.error.log;

    location / {
        proxy_pass http://127.0.0.1:9000;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_redirect off;
    }
}
NGINX

# Enable site
sudo ln -sf \
/etc/nginx/sites-available/sonarqube.conf \
/etc/nginx/sites-enabled/sonarqube.conf

# Remove default config
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx config
sudo nginx -t

# Enable and restart Nginx
sudo systemctl enable nginx
sudo systemctl restart nginx

# =========================================================
# Install New Relic Infrastructure Agent
# =========================================================

echo "Installing New Relic Infrastructure Agent..."

curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash

sudo NEW_RELIC_API_KEY="${var.newrelic_api_key}" \
NEW_RELIC_ACCOUNT_ID="${var.newrelic_account_id}" \
NEW_RELIC_REGION="EU" \
/usr/local/bin/newrelic install -y

# =========================================================
# Set hostname
# =========================================================

sudo hostnamectl set-hostname Sonarqube

# =========================================================
# Final output
# =========================================================

PUBLIC_IP=$$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "================================================="
echo "SonarQube installation completed successfully"
echo "Access URL: http://$${PUBLIC_IP}"
echo "Default Username: admin"
echo "Default Password: admin"
echo "================================================="

EOF
}