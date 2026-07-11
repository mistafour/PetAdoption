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
  vpc_id            = aws_vpc.team-1-vpc.id
  cidr_block        = var.pubsub1
  availability_zone = "eu-west-3a"
  tags = {
    Name = "${local.name}-public-subnet-1"
  }
}

# Creating Public subnet 2

resource "aws_subnet" "pet-pubsub-2" {
  vpc_id            = aws_vpc.team-1-vpc.id
  cidr_block        = var.pubsub2
  availability_zone = "eu-west-3b"
  tags = {
    Name = "${local.name}-public-subnet-2"
  }
}

# Creating Private subnet 1

resource "aws_subnet" "pet-prisub-1" {
  vpc_id            = aws_vpc.team-1-vpc.id
  cidr_block        = var.prisub1
  availability_zone = "eu-west-3a"
  tags = {
    Name = "${local.name}-private-subnet-1"
  }
}

# Creating Private subnet 2

resource "aws_subnet" "pet-prisub-2" {
  vpc_id            = aws_vpc.team-1-vpc.id
  cidr_block        = var.prisub2
  availability_zone = "eu-west-3b"
  tags = {
    Name = "${local.name}-private-subnet-2"
  }
}

#creating internet gateway
resource "aws_internet_gateway" "pet-igw" {
  vpc_id = aws_vpc.team-1-vpc.id
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
  allocation_id = aws_eip.team-1-eip.id
  subnet_id     = aws_subnet.team-1-pubsub-1.id
  tags = {
    Name = "${local.name}-nat-gateway"
  }
}

# Creating Public Route Table

resource "aws_route_table" "pet-public-route-table" {
  vpc_id = aws_vpc.team-1-vpc.id
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
  vpc_id = aws_vpc.team-1-vpc.id
  route {
    cidr_block = var.all_cidr_blocks
    gateway_id = aws_nat_gateway.team-1-nat.id
  }

  tags = {
    Name = "${local.name}-private-route-table"
  }
}

# Public subnet 1 route table association

resource "aws_route_table_association" "pet-pubsub-1-association" {
  subnet_id      = aws_subnet.team-1-pubsub-1.id
  route_table_id = aws_route_table.team-1-public-route-table.id
}

# Public subnet 2 route table association

resource "aws_route_table_association" "pet-pubsub-2-association" {
  subnet_id      = aws_subnet.team-1-pubsub-2.id
  route_table_id = aws_route_table.team-1-public-route-table.id
}

# Private subnet 1 route table association

resource "aws_route_table_association" "pet-prisub-1-association" {
  subnet_id      = aws_subnet.team-1-prisub-1.id
  route_table_id = aws_route_table.team-1-private-route-table.id
}

# Private subnet 2 route table association

resource "aws_route_table_association" "pet-prisub-2-association" {
  subnet_id      = aws_subnet.team-1-prisub-2.id
  route_table_id = aws_route_table.team-1-private-route-table.id
}
# Keypair created for SSH into instance

resource "tls_private_key" "pet_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "pet_key" {
  content         = tls_private_key.team_1_key.private_key_pem
  filename        = "pet-keypair.pem"
  file_permission = "0400"
}

resource "aws_key_pair" "pet_key" {
  key_name   = "pet-keypair"
  public_key = tls_private_key.team_1_key.public_key_openssh
}