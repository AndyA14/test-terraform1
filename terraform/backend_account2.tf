provider "aws" {
  alias   = "backend"
  region  = var.region
  profile = var.aws_profile_backend
}

variable "aws_profile_backend" {
  type    = string
  default = "academy-back"
}

variable "backend_docker_image" {
  type    = string
  default = "TU_USUARIO_DOCKER/pokemon-backend:latest"
}

resource "aws_vpc" "backend_vpc" {
  provider   = aws.backend
  cidr_block = "10.1.0.0/16"
  tags       = { Name = "backend-vpc" }
}

resource "aws_internet_gateway" "backend_igw" {
  provider = aws.backend
  vpc_id   = aws_vpc.backend_vpc.id
  tags     = { Name = "backend-igw" }
}

resource "aws_subnet" "backend_public" {
  provider                = aws.backend
  vpc_id                  = aws_vpc.backend_vpc.id
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"
  tags                    = { Name = "backend-public" }
}

# route table + association (similar a la cuenta 1)

resource "aws_security_group" "backend_sg" {
  provider    = aws.backend
  name        = "backend-sg"
  description = "Allow HTTP from internet"
  vpc_id      = aws_vpc.backend_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "backend_ami" {
  provider    = aws.backend
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "backend1" {
  provider                    = aws.backend
  ami                         = data.aws_ami.backend_ami.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.backend_public.id
  vpc_security_group_ids      = [aws_security_group.backend_sg.id]
  associate_public_ip_address = true

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              systemctl enable docker
              systemctl start docker
              docker pull ${var.backend_docker_image}
              docker run -d -p 80:80 ${var.backend_docker_image}
              EOF
  )

  tags = { Name = "backend1" }
}

resource "aws_instance" "backend2" {
  provider                    = aws.backend
  ami                         = data.aws_ami.backend_ami.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.backend_public.id
  vpc_security_group_ids      = [aws_security_group.backend_sg.id]
  associate_public_ip_address = true

  user_data = aws_instance.backend1.user_data
  tags      = { Name = "backend2" }
}
