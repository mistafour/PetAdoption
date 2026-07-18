locals {
  name = "var.name"
}

#Creating a VPC

resource "aws_vpc" "pet-vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${local.name}-vpc"
  }
}

# Creating Public subnet 1

resource "aws_subnet" "pet-pubsub-1" {
  vpc_id            = aws_vpc.pet-vpc.id
  cidr_block        = var.pubsub1
  availability_zone = "eu-west-3a"
  tags = {
    Name = "${local.name}-public-subnet-1"
  }
}

# Creating Public subnet 2

resource "aws_subnet" "pet-pubsub-2" {
  vpc_id            = aws_vpc.pet-vpc.id
  cidr_block        = var.pubsub2
  availability_zone = "eu-west-3b"
  tags = {
    Name = "${local.name}-public-subnet-2"
  }
}

# Creating Private subnet 1

resource "aws_subnet" "pet-prisub-1" {
  vpc_id            = aws_vpc.pet-vpc.id
  cidr_block        = var.prisub1
  availability_zone = "eu-west-3a"
  tags = {
    Name = "${local.name}-private-subnet-1"
  }
}

# Creating Private subnet 2

resource "aws_subnet" "pet-prisub-2" {
  vpc_id            = aws_vpc.pet-vpc.id
  cidr_block        = var.prisub2
  availability_zone = "eu-west-3b"
  tags = {
    Name = "${local.name}-private-subnet-2"
  }
}

#creating internet gateway
resource "aws_internet_gateway" "pet-igw" {
  vpc_id = aws_vpc.pet-vpc.id
  tags = {
    Name = "${local.name}-internet-gateway"
  }
}

#creating elastic ip for nat gateway

resource "aws_eip" "pet-eip" {
  domain = "vpc"
  tags = {
    Name = "${local.name}-elastic-ip"
  }
}

#creating nat gateway

resource "aws_nat_gateway" "pet-nat" {
  allocation_id = aws_eip.pet-eip.id
  subnet_id     = aws_subnet.pet-pubsub-1.id
  tags = {
    Name = "${local.name}-nat-gateway"
  }
}

# Creating Public Route Table

resource "aws_route_table" "pet-public-route-table" {
  vpc_id = aws_vpc.pet-vpc.id
  route {
    cidr_block = var.all_cidr_blocks
    gateway_id = aws_internet_gateway.pet-igw.id
  }

  tags = {
    Name = "${local.name}-public-route-table"
  }
}

# Creating Private Route Table

resource "aws_route_table" "pet-private-route-table" {
  vpc_id = aws_vpc.pet-vpc.id
  route {
    cidr_block = var.all_cidr_blocks
    gateway_id = aws_nat_gateway.pet-nat.id
  }

  tags = {
    Name = "${local.name}-private-route-table"
  }
}

# Public subnet 1 route table association

resource "aws_route_table_association" "pet-pubsub-1-association" {
  subnet_id      = aws_subnet.pet-pubsub-1.id
  route_table_id = aws_route_table.pet-public-route-table.id
}

# Public subnet 2 route table association

resource "aws_route_table_association" "pet-pubsub-2-association" {
  subnet_id      = aws_subnet.pet-pubsub-2.id
  route_table_id = aws_route_table.pet-public-route-table.id
}

# Private subnet 1 route table association

resource "aws_route_table_association" "pet-prisub-1-association" {
  subnet_id      = aws_subnet.pet-prisub-1.id
  route_table_id = aws_route_table.pet-private-route-table.id
}

# Private subnet 2 route table association

resource "aws_route_table_association" "pet-prisub-2-association" {
  subnet_id      = aws_subnet.pet-prisub-2.id
  route_table_id = aws_route_table.pet-private-route-table.id
}
# Keypair created for SSH into instance

resource "tls_private_key" "pet_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "pet_key" {
  content         = tls_private_key.pet_key.private_key_pem
  filename        = "pet-keypair.pem"
  file_permission = "0400"
}

resource "aws_key_pair" "pet_key" {
  key_name   = "pet-keypair"
  public_key = tls_private_key.pet_key.public_key_openssh
}

# Security group created for HTTP, HTTPS and SSH access

resource "aws_security_group" "pet_jenkins_sg" {
  name        = "pet-jenkins-sg"
  description = "Allow HTTP, HTTPS and SSH traffic"
  vpc_id      = aws_vpc.pet-vpc.id

  ingress {
    description = "Allow SSH"
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = [var.all_cidr_blocks]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = var.http_port
    to_port     = var.http_port
    protocol    = "tcp"
    cidr_blocks = [var.all_cidr_blocks]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = var.https_port
    to_port     = var.https_port
    protocol    = "tcp"
    cidr_blocks = [var.all_cidr_blocks]
  }

  ingress {
    description = "Allow Jenkins"
    from_port   = var.jenkins_port
    to_port     = var.jenkins_port
    protocol    = "tcp"
    cidr_blocks = [var.all_cidr_blocks]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.all_cidr_blocks]
  }

  tags = {
    Name = "${local.name}-jenkins-sg"
  }
}

# Security group created for SonarQube access

resource "aws_security_group" "pet_sonarqube_sg" {
  name        = "pet-sonarqube-sg"
  description = "Allow HTTP, HTTPS, SSH and SonarQube traffic"
  vpc_id      = aws_vpc.pet-vpc.id

  ingress {
    description = "Allow SSH - Port 22"
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = [var.all_cidr_blocks]
  }

  ingress {
    description = "Allow HTTP - Port 80"
    from_port   = var.http_port
    to_port     = var.http_port
    protocol    = "tcp"
    cidr_blocks = [var.all_cidr_blocks]
  }

  ingress {
    description = "Allow HTTPS - Port 443"
    from_port   = var.https_port
    to_port     = var.https_port
    protocol    = "tcp"
    cidr_blocks = [var.all_cidr_blocks]
  }

  ingress {
    description = "Allow SonarQube - Port 9000"
    from_port   = var.sonar_port
    to_port     = var.sonar_port
    protocol    = "tcp"
    cidr_blocks = [var.all_cidr_blocks]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.all_cidr_blocks]
  }

  tags = {
    Name = "${local.name}-sonarqube-sg"
  }
}

# Security group created for Ansible access
resource "aws_security_group" "pet_ansible_bastion_sg" {
  name        = "pet-ansible-sg"
  description = "Allow SSH traffic for Ansible"
  vpc_id      = aws_vpc.pet-vpc.id

  ingress {
    description = "Allow SSH - Port 22"
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = [var.all_cidr_blocks]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.all_cidr_blocks]
  }

  tags = {
    Name = "${local.name}-ansible-sg"
  }
}

# Security group created for Docker access
resource "aws_security_group" "pet_docker_sg" {
  name        = "pet-docker-sg"
  description = "Allow HTTP, HTTPS, SSH and Docker traffic"
  vpc_id      = aws_vpc.pet-vpc.id

  ingress {
    description = "Allow SSH - Port 22"
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = [var.all_cidr_blocks]
  }

  ingress {
    description = "Allow HTTP - Port 80"
    from_port   = var.http_port
    to_port     = var.http_port
    protocol    = "tcp"
    cidr_blocks = [var.all_cidr_blocks]
  }

  ingress {
    description = "Allow HTTPS - Port 443"
    from_port   = var.https_port
    to_port     = var.https_port
    protocol    = "tcp"
    cidr_blocks = [var.all_cidr_blocks]
  }

  ingress {
    description = "Allow Docker - Port 2375"
    from_port   = var.docker_port
    to_port     = var.docker_port
    protocol    = "tcp"
    cidr_blocks = [var.all_cidr_blocks]
  }

  ingress {
    description = "Allow Docker TLS - Port 2376"
    from_port   = var.dockertls_port
    to_port     = var.dockertls_port
    protocol    = "tcp"
    cidr_blocks = [var.all_cidr_blocks]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.all_cidr_blocks]
  }

  tags = {
    Name = "${local.name}-docker-sg"
  }
}

# Security group created for Nexus access
resource "aws_security_group" "pet_nexus_sg" {
  name        = "pet-nexus-sg"
  description = "Allow HTTP, HTTPS, SSH and Nexus traffic"
  vpc_id      = aws_vpc.pet-vpc.id

  ingress {
    description = "Allow SSH - Port 22"
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = [var.all_cidr_blocks]
  }

  ingress {
    description = "Allow HTTP - Port 80"
    from_port   = var.http_port
    to_port     = var.http_port
    protocol    = "tcp"
    cidr_blocks = [var.all_cidr_blocks]
  }

  ingress {
    description = "Allow HTTPS - Port 443"
    from_port   = var.https_port
    to_port     = var.https_port
    protocol    = "tcp"
    cidr_blocks = [var.all_cidr_blocks]
  }

  ingress {
    description = "Allow Nexus - Port 8081"
    from_port   = var.nexus_port
    to_port     = var.nexus_port
    protocol    = "tcp"
    cidr_blocks = [var.all_cidr_blocks]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.all_cidr_blocks]
  }

  tags = {
    Name = "${local.name}-nexus-sg"
  }
}

# Security group created for RDS access
resource "aws_security_group" "pet_rds_sg" {
  name        = "pet-rds-sg"
  description = "Allow RDS database traffic"
  vpc_id      = aws_vpc.pet-vpc.id

  ingress {
    description = "Allow MySQL RDS - Port 3306"
    from_port   = var.mysql_port
    to_port     = var.mysql_port
    protocol    = "tcp"
    cidr_blocks = [var.rds_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.all_cidr_blocks]
  }

  tags = {
    Name = "${local.name}-rds-sg"
  }
}
#creating ansible server 
resource "aws_instance" "pet-ansible_server" {
  ami                         = var.redhat
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.pet_key.id
  vpc_security_group_ids      = [aws_security_group.pet_ansible_bastion_sg.id]
  subnet_id                   = aws_subnet.pet-prisub-1.id
  associate_public_ip_address = true

  user_data = local.ansible_user_data

  tags = {
    Name = "${local.name}-ansible_server"
  }
}


# Creating Jenkins server
resource "aws_instance" "pet-jenkins" {
  ami                         = var.redhat #redhat instance
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.pet_key.id
  vpc_security_group_ids      = [aws_security_group.pet_jenkins_sg.id]
  subnet_id                   = aws_subnet.pet-pubsub-2.id
  associate_public_ip_address = true

  user_data = local.jenkins_script

  tags = {
    Name = "${local.name}-jenkins-server"
  }
}


#creating bastion server
resource "aws_instance" "pet-bastion_server" {
  ami                         = var.redhat
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.pet_key.id
  vpc_security_group_ids      = [aws_security_group.pet_ansible_bastion_sg.id]
  subnet_id                   = aws_subnet.pet-pubsub-2.id
  associate_public_ip_address = true

  user_data = local.bastion_user_data

  tags = {
    Name = "${local.name}-bastion_server"
  }
}

# SonarQube Server
resource "aws_instance" "pet-sonarqube" {
  ami                         = var.ubuntu # Use Ubuntu AMI
  instance_type               = "t2.medium"
  key_name                    = aws_key_pair.pet_key.id
  vpc_security_group_ids      = [aws_security_group.pet_sonarqube_sg.id]
  subnet_id                   = aws_subnet.pet-pubsub-1.id
  associate_public_ip_address = true

  user_data = local.sonarqube_user_data

  tags = {
    Name = "${local.name}-sonarqube-server"
  }
}

#creating docker host
resource "aws_instance" "pet-docker-server" {
  ami                         = var.ubuntu # Use Ubuntu AMI
  instance_type               = "t2.medium"
  key_name                    = aws_key_pair.pet_key.id
  vpc_security_group_ids      = [aws_security_group.pet_docker_sg.id]
  subnet_id                   = aws_subnet.pet-prisub-1.id
  associate_public_ip_address = true

  user_data = local.docker_user_data

  tags = {
    Name = "${local.name}-docker-server"
  }
}

# Creating Nexus server
resource "aws_instance" "nexus" {
  ami                         = var.redhat
  instance_type               = "t2.medium"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.pet_nexus_sg.id]
  subnet_id                   = aws_subnet.pet-pubsub-1.id
  key_name                    = aws_key_pair.pet_key.id
  user_data                   = local.nexus_user_data
  metadata_options {
    http_tokens = "required"
  }
  tags = {
    Name = "${local.name}-nexus"
  }
}

# Creating Application Load Balancer
resource "aws_lb" "pet-app-lb" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.pet_docker_sg.id]
  subnets            = [aws_subnet.pet-pubsub-1.id, aws_subnet.pet-pubsub-2.id]

  enable_deletion_protection = false

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "target-group-lb-HTTP" {
  name        = "pet-tg-http"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.pet-vpc.id

  health_check {
    path                = "/indextest.html"
    interval            = 60
    timeout             = 30
    healthy_threshold   = 3
    unhealthy_threshold = 5
    port                = 80
  }

  tags = {
    Name = "pet-http-target-group"
  }
}

resource "aws_lb_target_group" "target-group-lb-HTTPS" {
  name        = "pet-tg-https"
  port        = 443
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = aws_vpc.pet-vpc.id

  health_check {
    path                = "/indextest.html"
    interval            = 60
    timeout             = 30
    healthy_threshold   = 3
    unhealthy_threshold = 5
    port                = 80
  }

  tags = {
    Name = "pet-https-target-group"
  }
}

# Load balancer attachment
resource "aws_lb_target_group_attachment" "lb_attachment_http" {
  target_group_arn = aws_lb_target_group.target-group-lb-HTTP.arn
  target_id        = aws_instance.pet-docker-server.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "lb_attachment_https" {
  target_group_arn = aws_lb_target_group.target-group-lb-HTTPS.arn
  target_id        = aws_instance.pet-docker-server.id
  port             = 443
}

#Creating Instance profile for EC2 instances to access AWS resources
resource "aws_iam_instance_profile" "iam-instance-profile1" {
  name = "pet-instance-profile"
  role = aws_iam_role.iam-role1.name
}

//Creating AMI 
resource "aws_ami_from_instance" "asg_ami" {
  name                    = "asg-ami"
  source_instance_id      = aws_instance.pet-docker-server.id
  snapshot_without_reboot = true
  depends_on              = [aws_instance.pet-docker-server, time_sleep.ami-sleep]
}

//Creating time sleep 
resource "time_sleep" "ami-sleep" {
  depends_on      = [aws_instance.pet-docker-server]
  create_duration = "360s"
}

resource "aws_launch_template" "pet-app-lt" {
  name_prefix   = "pet-app-lt"
  image_id      = aws_ami_from_instance.asg_ami.id
  instance_type = "t3.micro"                       #free tier instance type
  key_name      = aws_key_pair.pet_key.key_name # to be defined when keypair is made

  iam_instance_profile {
    name = aws_iam_instance_profile.iam-instance-profile1.id
  }
  network_interfaces {
    #associate_public_ip_address = true
    security_groups = [aws_security_group.pet_docker_sg.id]
  }
  user_data = base64encode(local.docker_user_data)
}

#Creating IAM role for EC2 instances to access AWS resources
resource "aws_iam_role" "iam-role1" {
  name = "pet-iam-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

#auto scaling policy
resource "aws_autoscaling_policy" "pet-asg-policy" {
  name               = "scale-out-policy"
  scaling_adjustment = 1
  adjustment_type    = "ChangeInCapacity"
  cooldown           = 300

  autoscaling_group_name = aws_autoscaling_group.pet-asg.name
}

# Autoscaling group
resource "aws_autoscaling_group" "pet-asg" {
  name                      = "pet-asg"
  desired_capacity          = 2
  max_size                  = 5
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  force_delete              = true

  launch_template {
    id      = aws_launch_template.pet-app-lt.id
    version = "$Latest"
  }

  vpc_zone_identifier = [
    aws_subnet.pet-prisub-1.id,
    aws_subnet.pet-prisub-2.id
  ]

  target_group_arns = [aws_lb_target_group.target-group-lb-HTTP.arn, aws_lb_target_group.target-group-lb-HTTPS.arn]
}

#load balancer listener
resource "aws_lb_listener" "pet-lb-listener" {
  load_balancer_arn = aws_lb.pet-app-lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target-group-lb-HTTP.arn
  }
}
# ACM Certificate for pet domain
resource "aws_acm_certificate" "pet_certificate" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

#creating stage elb

resource "aws_elb" "elb-jenkins" {

name = "elb-jenkins"

security_groups = [aws_security_group.pet_jenkins_sg.id]

subnets = [aws_subnet.pet-pubsub-1.id, aws_subnet.pet-pubsub-2.id]


 listener {

instance_port = 8080

instance_protocol = "http"

lb_port = 443

lb_protocol = "https"

ssl_certificate_id = aws_acm_certificate.pet_certificate.arn

 }



health_check {

healthy_threshold = 2

unhealthy_threshold = 2

timeout = 3

target = "tcp:8080"

interval = 30

 }



instances = [aws_instance.pet-jenkins.id]

cross_zone_load_balancing  = true

idle_timeout = 400

connection_draining = true

connection_draining_timeout = 400

 tags = {

Name = "elb-jenkins"

 }

}

# Creating ELB for Nexus
resource "aws_elb" "elb-nexus" {
  name = "elb-nexus"

  security_groups = [aws_security_group.pet_nexus_sg.id]

  subnets = [
    aws_subnet.pet-pubsub-1.id,
    aws_subnet.pet-pubsub-2.id
  ]

  listener {
    instance_port      = var.nexus_port
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = aws_acm_certificate.pet_certificate.arn
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:${var.nexus_port}"
    interval            = 30
  }

  instances = [aws_instance.nexus.id]

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "elb-nexus"
  }
}

# Creating ELB for SonarQube
resource "aws_elb" "elb-sonarqube" {
  name = "elb-sonarqube"

  security_groups = [aws_security_group.pet_sonarqube_sg.id]

  subnets = [
    aws_subnet.pet-pubsub-1.id,
    aws_subnet.pet-pubsub-2.id
  ]

  listener {
    instance_port      = var.sonar_port
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = aws_acm_certificate.pet_certificate.arn
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:${var.sonar_port}"
    interval            = 30
  }

  instances = [aws_instance.pet-sonarqube.id]

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "elb-sonarqube"
  }
}

# Creating record set in Route53 for Domain Validation
resource "aws_route53_record" "pet_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.pet_certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  type            = each.value.type
  ttl             = 60
  zone_id         = data.aws_route53_zone.pet_zone.zone_id
}

# ACM certificate validation for pet
resource "aws_acm_certificate_validation" "pet_cert_validation" {
  certificate_arn         = aws_acm_certificate.pet_certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.pet_cert_validation : record.fqdn]
}

#Creating Route53 hosted zone for pet domain
data "aws_route53_zone" "pet_zone" {
  name         = var.domain_name
  private_zone = false
}

 
# Route 53 A records for each server as subdomains
resource "aws_route53_record" "jenkins" {
  zone_id = data.aws_route53_zone.pet_zone.zone_id
  name    = "jenkins.gatsby-devops.com"
  type    = "A"
  alias {
    name                   = aws_elb.elb-jenkins.dns_name
    zone_id                = aws_elb.elb-jenkins.zone_id
    evaluate_target_health = true
  }
}
 
 
resource "aws_route53_record" "sonarqube" {
  zone_id = data.aws_route53_zone.pet_zone.zone_id
  name    = "sonarqube.gatsby-devops.com"
  type    = "A"
  alias {
    name                   = aws_elb.elb-sonarqube.dns_name
    zone_id                = aws_elb.elb-sonarqube.zone_id
    evaluate_target_health = true
  }
}
 
resource "aws_route53_record" "docker" {
  zone_id = data.aws_route53_zone.pet_zone.zone_id
  name    = "docker.gatsby-devops.com"
  type    = "A"
  alias {
    name                   = aws_lb.pet-app-lb.dns_name
    zone_id                = aws_lb.pet-app-lb.zone_id
    evaluate_target_health = true
  }
}
 
resource "aws_route53_record" "nexus" {
  zone_id = data.aws_route53_zone.pet_zone.zone_id
  name    = "nexus.gatsby-devops.com"
  type    = "A"
  alias {
    name                   = aws_elb.elb-nexus.dns_name
    zone_id                = aws_elb.elb-nexus.zone_id
    evaluate_target_health = true
  }
}

