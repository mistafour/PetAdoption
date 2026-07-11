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

variable "newrelicfile" {
  default = "./newrelic.yml"
}
variable "db-identifier" {
  default = "db-identifier"
}

variable "dbusername" {
  default = "dbadmin"
  
}

variable "dbpassword" {
  default = "dbpassword"
}

variable "dbname" {
  default = "petclinic"
}

variable "mysqlport" {
  default = 3306
}

variable "newrelic_account_id" {
  default = "5144160"
}

variable "newrelic_api_key" {
  default = "NRAK-9R11142QWU2YHZ60A2W8A0AJ8IO"
}