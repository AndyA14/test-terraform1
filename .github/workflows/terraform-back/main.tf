########################################
# VPC simple para backend
########################################

resource "aws_vpc" "back_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "back-vpc"
    Project = "PokeFinder"
    Role    = "backend"
  }
}

resource "aws_internet_gateway" "back_igw" {
  vpc_id = aws_vpc.back_vpc.id

  tags = {
    Name = "back-igw"
  }
}

resource "aws_subnet" "back_public" {
  vpc_id                  = aws_vpc.back_vpc.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "back-public"
  }
}

resource "aws_route_table" "back_public_rt" {
  vpc_id = aws_vpc.back_vpc.id

  tags = {
    Name = "back-public-rt"
  }
}

resource "aws_route" "back_public_internet" {
  route_table_id         = aws_route_table.back_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.back_igw.id
}

resource "aws_route_table_association" "back_public_assoc" {
  subnet_id      = aws_subnet.back_public.id
  route_table_id = aws_route_table.back_public_rt.id
}

########################################
# Security Group backend
########################################

resource "aws_security_group" "back_sg" {
  name        = "back-sg"
  description = "Allow HTTP from Internet to backend"
  vpc_id      = aws_vpc.back_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # (No exponemos Postgres, solo lo usamos interno vía localhost)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "back-sg"
  }
}

########################################
# AMI para backend
########################################

data "aws_ami" "amazon_linux_back" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

########################################
# User data con Postgres + backend
########################################

locals {
  backend_user_data = <<-EOT
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl enable docker
    systemctl start docker

    # Levantar Postgres
    docker run -d --name pokedx-db \
      -e POSTGRES_DB=${var.db_name} \
      -e POSTGRES_USER=${var.db_user} \
      -e POSTGRES_PASSWORD=${var.db_password} \
      -p 5432:5432 \
      postgres:16

    # Esperar a que Postgres levante
    sleep 20

    # Levantar backend apuntando a ese Postgres (ajusta las env vars según tu app)
    docker pull ${var.backend_image}
    docker run -d -p 80:80 \
      -e DATABASE_URL=postgresql://${var.db_user}:${var.db_password}@localhost:5432/${var.db_name} \
      --link pokedx-db \
      ${var.backend_image}
  EOT
}

########################################
# Dos instancias backend
########################################

resource "aws_instance" "backend1" {
  ami                         = data.aws_ami.amazon_linux_back.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.back_public.id
  vpc_security_group_ids      = [aws_security_group.back_sg.id]
  associate_public_ip_address = true
  user_data                   = base64encode(local.backend_user_data)

  tags = {
    Name    = "backend1"
    Project = "PokeFinder"
    Role    = "backend"
  }
}

resource "aws_instance" "backend2" {
  ami                         = data.aws_ami.amazon_linux_back.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.back_public.id
  vpc_security_group_ids      = [aws_security_group.back_sg.id]
  associate_public_ip_address = true
  user_data                   = base64encode(local.backend_user_data)

  tags = {
    Name    = "backend2"
    Project = "PokeFinder"
    Role    = "backend"
  }
}
