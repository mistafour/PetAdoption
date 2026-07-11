variable "name" {}

variable "domain_name" {
  type = string
}

variable "newrelic_license_key" {
  sensitive = true
}

variable "jenkins_admin_password" {
  sensitive = true
}

variable "private_key_path" {}
variable "redhat" {}
variable "ubuntu" {}

variable "vpc_cidr" {}
variable "pubsub1" {}
variable "pubsub2" {}
variable "prisub1" {}
variable "prisub2" {}
variable "rds_cidr" {}
variable "all_cidr_blocks" {}

variable "ssh_port" {}
variable "http_port" {}
variable "https_port" {}
variable "jenkins_port" {}
variable "sonar_port" {}
variable "docker_port" {}
variable "dockertls_port" {}
variable "nexus_port" {}
variable "mysql_port" {}