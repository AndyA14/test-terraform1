########################################
# VPC + Subnets + Internet access
########################################

resource "aws_vpc" "front_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "front-vpc"
    Project = "PokeFinder"
    Role    = "frontend"
  }
}

resource "aws_internet_gateway" "front_igw" {
  vpc_id = aws_vpc.front_vpc.id

  tags = {
    Name = "front-igw"
  }
}

resource "aws_subnet" "front_public_a" {
  vpc_id                  = aws_vpc.front_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "front-public-a"
  }
}

resource "aws_subnet" "front_public_b" {
  vpc_id                  = aws_vpc.front_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "front-public-b"
  }
}

resource "aws_route_table" "front_public_rt" {
  vpc_id = aws_vpc.front_vpc.id

  tags = {
    Name = "front-public-rt"
  }
}

resource "aws_route" "front_public_internet" {
  route_table_id         = aws_route_table.front_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.front_igw.id
}

resource "aws_route_table_association" "front_public_a_assoc" {
  subnet_id      = aws_subnet.front_public_a.id
  route_table_id = aws_route_table.front_public_rt.id
}

resource "aws_route_table_association" "front_public_b_assoc" {
  subnet_id      = aws_subnet.front_public_b.id
  route_table_id = aws_route_table.front_public_rt.id
}

########################################
# Security Groups
########################################

# ALB recibe tráfico HTTP de internet
resource "aws_security_group" "alb_sg" {
  name        = "front-alb-sg"
  description = "Allow HTTP from Internet to ALB"
  vpc_id      = aws_vpc.front_vpc.id

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

  tags = {
    Name = "front-alb-sg"
  }
}

# EC2 recibe tráfico solo del ALB
resource "aws_security_group" "ec2_sg" {
  name        = "front-ec2-sg"
  description = "Allow HTTP from ALB"
  vpc_id      = aws_vpc.front_vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "front-ec2-sg"
  }
}

########################################
# ALB + Target Group + Listener
########################################

resource "aws_lb" "front_alb" {
  name               = "front-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.front_public_a.id, aws_subnet.front_public_b.id]

  tags = {
    Name = "front-alb"
  }
}

resource "aws_lb_target_group" "front_tg" {
  name     = "front-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.front_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "front-tg"
  }
}

resource "aws_lb_listener" "front_listener" {
  load_balancer_arn = aws_lb.front_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.front_tg.arn
  }
}

########################################
# Launch Template + Auto Scaling Group
########################################

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_launch_template" "front_lt" {
  name_prefix   = "front-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              systemctl enable docker
              systemctl start docker

              docker pull ${var.frontend_image}
              docker run -d -p 80:80 ${var.frontend_image}
              EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name    = "front-asg-instance"
      Project = "PokeFinder"
      Role    = "frontend"
    }
  }
}

resource "aws_autoscaling_group" "front_asg" {
  name                      = "front-asg"
  max_size                  = 3
  min_size                  = 2
  desired_capacity          = 2
  vpc_zone_identifier       = [aws_subnet.front_public_a.id, aws_subnet.front_public_b.id]
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.front_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.front_tg.arn]

  tag {
    key                 = "Name"
    value               = "front-asg-instance"
    propagate_at_launch = true
  }
}

########################################
# Reglas de escalado (CPU / network)
########################################

# Ejemplo: escala cuando CPU > 70%
resource "aws_autoscaling_policy" "cpu_scale_out" {
  name                   = "front-cpu-scale-out"
  autoscaling_group_name = aws_autoscaling_group.front_asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 120
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "front-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "High CPU on ASG instances"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.front_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.cpu_scale_out.arn]
}
