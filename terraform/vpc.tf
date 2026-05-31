# vpc.tf

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "VPC-01" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "VPC-01-IGW" }
}

# --- PODSIECI PUBLICZNE ---
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "VPC-01-Public-A" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = { Name = "VPC-01-Public-B" }
}

# --- PODSIECI PRYWATNE ---
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "VPC-01-Private-A" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1b"
  tags = { Name = "VPC-01-Private-B" }
}

# --- INSTANCJE NAT (Zastępują NAT Gateway) ---
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

resource "aws_instance" "nat_a" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.nat_a.id]
  source_dest_check      = false # KRYTYCZNE DLA NAT
  tags                   = { Name = "VPC-01-NAT-A" }

  user_data = <<-EOF
              #!/bin/bash
              yum install -y iptables
              sysctl -w net.ipv4.ip_forward=1
              echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
              iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE
              EOF
}

resource "aws_instance" "nat_b" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_b.id
  vpc_security_group_ids = [aws_security_group.nat_b.id]
  source_dest_check      = false
  tags                   = { Name = "VPC-01-NAT-B" }

  user_data = <<-EOF
              #!/bin/bash
              yum install -y iptables
              sysctl -w net.ipv4.ip_forward=1
              echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
              iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE
              EOF
}

# --- ELASTIC IPs DLA NAT ---
resource "aws_eip" "nat_a" {
  domain   = "vpc"
  instance = aws_instance.nat_a.id
  tags     = { Name = "VPC-01-NAT-EIP-A" }
}

resource "aws_eip" "nat_b" {
  domain   = "vpc"
  instance = aws_instance.nat_b.id
  tags     = { Name = "VPC-01-NAT-EIP-B" }
}

# --- TABELE ROUTINGU ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "VPC-01-PublicRT" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_instance.nat_a.primary_network_interface_id
  }
  tags = { Name = "VPC-01-PrivateRT-A" }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_instance.nat_b.primary_network_interface_id
  }
  tags = { Name = "VPC-01-PrivateRT-B" }
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_b.id
}