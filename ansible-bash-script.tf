locals {
  ansible_user_data = <<-EOF
#!/bin/bash

# Install Ansible and Python tools. Avoid a full yum update here because it can make cloud-init hang for a long time.
sudo yum install -y ansible-core python3 python3-pip

# Install the Docker collection so Ansible can control the remote Docker host.
sudo -u ec2-user ansible-galaxy collection install community.docker
sudo chown -R ec2-user:ec2-user /etc/ansible

# Store the private key on the Ansible server so it can SSH into the Docker host.
sudo mkdir -p /home/ec2-user/.ssh
echo "${tls_private_key.pet_key.private_key_pem}" >> /home/ec2-user/.ssh/id_rsa
sudo chown ec2-user:ec2-user /home/ec2-user/.ssh/id_rsa
chmod 700 /home/ec2-user/.ssh
chmod 400 /home/ec2-user/.ssh/id_rsa
cd /etc/ansible
touch hosts
sudo chown ec2-user:ec2-user hosts
cat <<EOT> /etc/ansible/hosts
[all:vars]
ansible_ssh_common_args='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'

localhost ansible_connection=local

[docker_host]
${aws_instance.pet-docker-server.private_ip} ansible_user=ubuntu ansible_ssh_private_key_file=/home/ec2-user/.ssh/id_rsa
EOT

sudo mkdir /opt/docker
echo "${file(var.newrelicfile)}" >> /opt/docker/newrelic.yml
touch /opt/docker/Dockerfile

# Create the Dockerfile used to build the application image.
# This image runs the Pet Adoption app and includes the New Relic Java APM agent.
cat <<EOT>> /opt/docker/Dockerfile
FROM eclipse-temurin:17-jre-jammy

# Set the working folder inside the container.
WORKDIR /app

# Install tools needed to download and unzip the New Relic Java agent.
RUN apt update -y && apt install curl unzip -y

# Download and extract the New Relic Java agent for application monitoring.
RUN curl -O https://download.newrelic.com/newrelic/java-agent/newrelic-agent/current/newrelic-java.zip && \
    unzip newrelic-java.zip && \
    rm newrelic-java.zip

# Copy the New Relic config and application WAR file into the container.
COPY newrelic.yml /app/newrelic/newrelic.yml
COPY spring-petclinic-1.0.war /app/spring-petclinic-1.0.war

# Set the application name that will appear in New Relic APM.
ENV NEW_RELIC_APP_NAME="Pet-Adoption"
ENV NEW_RELIC_LOG_FILE_NAME=STDOUT

# Start the Java app with the New Relic Java agent enabled.
ENTRYPOINT ["java", "-javaagent:/app/newrelic/newrelic.jar", "-jar", "/app/spring-petclinic-1.0.war", "--server.port=8080"]

EOT

touch /opt/docker/docker-image.yml
cat <<EOT>> /opt/docker/docker-image.yml

---
 - hosts: localhost
   become: true

   tasks:
    - name: Download WAR file from Nexus repository
      get_url:
        url: http://admin:admin123@${aws_instance.nexus.public_ip}:8081/repository/maven-releases/Petclinic/spring-petclinic/1.0/spring-petclinic-1.0.war
        
        dest: /opt/docker/spring-petclinic-1.0.war
        
    - name: Build Docker image from WAR file
      community.docker.docker_image:
        build:
          path: /opt/docker
        name: cloudhight/testapp
        tag: latest
        source: build    
    - name: Login to Docker Hub
      community.docker.docker_login:
        username: cloudhight
        password: Motiva123@    
    - name: Push Docker image to Docker Hub
      community.docker.docker_image:
        name: cloudhight/testapp
        tag: latest
        push: yes
        source: local    
    - name: Remove Docker image from Ansible server
      community.docker.docker_image:
        name: cloudhight/testapp:latest
        state: absent
EOT

touch /opt/docker/docker-container.yml
cat <<EOT>> /opt/docker/docker-container.yml
---
 - hosts: docker_host
   become: true
   tasks:
    - name: Login to Docker Hub
      docker_login:
        username: cloudhight
        password: Motiva123@
    - name: Stop any container running
      docker_container:
        name: testAppContainer
        state: stopped
      ignore_errors: yes
    - name: Remove stopped container
      docker_container:
        name: testAppContainer
        state: absent
      ignore_errors: yes
    - name: Remove docker image
      docker_image:
        state: absent
        name: cloudhight/testapp
        tag: latest
      ignore_errors: yes
    - name: Pull docker image from Docker Hub
      docker_image:
        name: cloudhight/testapp
        tag: latest
        source: pull
    - name: Create container from pet adoption image
      docker_container:
        name: testAppContainer
        image: cloudhight/testapp
        state: started
        ports:
          - "8080:8080"
        detach: true
EOT

touch /opt/docker/newrelic-container.yml

# New Relic Container Monitoring
# This Ansible playbook runs the New Relic infrastructure agent as a Docker container.
# It allows New Relic to monitor Docker containers running on the Docker host.
cat << EOT > /opt/docker/newrelic-container.yml
---
 - hosts: docker_host
   become: true
   tasks:
    - name: Install New Relic container monitoring
      command: >
        docker run -d
        --name newrelic-infra
        --network=host
        --cap-add=SYS_PTRACE
        --privileged
        --pid=host
        --cgroupns=host
        -v "/:/host:ro"
        -v "/var/run/docker.sock:/var/run/docker.sock"
        -e NRIA_LICENSE_KEY="${var.newrelic_license_key}"
        newrelic/infrastructure:latest
      ignore_errors: yes

EOT
sudo chown -R ec2-user:ec2-user /opt/docker
sudo chmod -R 700 /opt/docker

# Install New Relic Infrastructure agent for Ansible server monitoring
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash

sudo NEW_RELIC_API_KEY="" \
NEW_RELIC_ACCOUNT_ID="" \
NEW_RELIC_REGION="EU" \
/usr/local/bin/newrelic install -y

sudo hostnamectl set-hostname Ansible
EOF

}
