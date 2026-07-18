locals {
  # This creates a local Terraform variable called bastion_user_data.
  # It stores the startup script that will run when the bastion EC2 instance is created.
  bastion_user_data = <<-EOF
#!/bin/bash

# Writes the private key value from Terraform into the EC2 user's SSH private key file.
# This is used so the bastion host can SSH into private instances.
 echo "${tls_private_key.pet_key.private_key_pem}" >> /home/ec2-user/.ssh/id.rsa

# Sets the private key permissions so only the file owner can read it.
# SSH requires private keys to have strict permissions.
chmod 400 /home/ec2-user/.ssh/id.rsa

# Changes ownership of the private key file to the ec2-user account.
chown ec2-user:ec2-user /home/ec2-user/.ssh/id.rsa

# Install mysql
sudo yum install mysql -y

# Install New Relic Infrastructure agent for Bastion monitoring
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash

sudo NEW_RELIC_API_KEY="" \
NEW_RELIC_ACCOUNT_ID="" \
NEW_RELIC_REGION="EU" \
/usr/local/bin/newrelic install -y

# Sets the server hostname to Bastion.
sudo hostnamectl set-hostname Bastion

EOF 
}