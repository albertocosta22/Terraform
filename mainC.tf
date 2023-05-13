terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1" 
}

// Crear VPC
resource "aws_vpc" "vpc_alberto" {
  cidr_block = "10.0.0.0/16"
}

// Crear subred pública
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.vpc_alberto.id
  availability_zone = "us-east-1a"
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet"
  }
}


resource "aws_subnet" "public_subnet1" {
  vpc_id     = aws_vpc.vpc_alberto.id
  availability_zone = "us-east-1b"
  cidr_block = "10.0.10.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet"
  }
}

resource "aws_subnet" "public_subnet2" {
  vpc_id     = aws_vpc.vpc_alberto.id
  availability_zone = "us-east-1c"
  cidr_block = "10.0.100.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet2"
  }
}

// Crear subred privada
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.vpc_alberto.id
  availability_zone = "us-east-1a"
  cidr_block = "10.0.2.0/24"
  map_public_ip_on_launch = false
  tags = {
    Name = "Private Subnet"
  }
}

resource "aws_subnet" "private_subnet1" {
  vpc_id     = aws_vpc.vpc_alberto.id
  availability_zone = "us-east-1b"
  cidr_block = "10.0.20.0/24"
  map_public_ip_on_launch = false
  tags = {
    Name = "Private Subnet1"
  }
}

resource "aws_subnet" "private_subnet2" {
  vpc_id     = aws_vpc.vpc_alberto.id
  availability_zone = "us-east-1c"
  cidr_block = "10.0.200.0/24"
  map_public_ip_on_launch = false
  tags = {
    Name = "Private Subnet2"
  }
}

// Crear grupos de seguridad que permita todo el tráfico

resource "aws_security_group" "ssh_sg" {
  name_prefix = "ssh-sg"
  vpc_id = aws_vpc.vpc_alberto.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "http_sg" {
  name_prefix = "http-sg"
  vpc_id = aws_vpc.vpc_alberto.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

// Crear una puerta de enlace
resource "aws_internet_gateway" "example_igw" {
  vpc_id = aws_vpc.vpc_alberto.id
}

//Crear Elastic IP
resource "aws_eip" "eip" {
  vpc = true
}

//Crear nat gateway
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.eip.id
  subnet_id = ["${aws_subnet.public_subnet.id}","${aws_subnet.public_subnet1.id}","${aws_subnet.public_subnet2.id}"]
}

// Crear una tabla de enrutamiento
resource "aws_route_table" "example_rt" {
  vpc_id = aws_vpc.vpc_alberto.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example_igw.id
  }
}

resource "aws_route_table" "example_pt" {
  vpc_id = aws_vpc.vpc_alberto.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
}

// Asociar tabla de enrutamiento con subred pública
resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.example_rt.id
}

resource "aws_route_table_association" "public_rt_assoc1" {
  subnet_id = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.example_rt.id
}
resource "aws_route_table_association" "public_rt_assoc2" {
  subnet_id = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.example_rt.id
}

//Asociar tabla enrutamiento a subredes privadas
resource "aws_route_table_association" "private_rt_assoc" {
  subnet_id = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.example_pt.id
}

resource "aws_route_table_association" "private_rt_assoc1" {
  subnet_id = aws_subnet.private_subnet1.id
  route_table_id = aws_route_table.example_pt.id
}

resource "aws_route_table_association" "private_rt_assoc2" {
  subnet_id = aws_subnet.private_subnet2.id
  route_table_id = aws_route_table.example_pt.id
}

// Crear un balanceador de carga
resource "aws_lb" "example_lb" {
  name               = "balanceador"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.http_sg.id]
  subnets            = ["${aws_subnet.public_subnet.id}","${aws_subnet.public_subnet1.id}", "${aws_subnet.public_subnet2.id}"]
}

resource "aws_lb_target_group" "tg-group" {
  name     = "tg-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc_alberto.id

  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 6
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "lb-listener" {
  load_balancer_arn = aws_lb.example_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-group.arn
  }
}

// Crear plantilla de lanzamiento
resource "aws_launch_template" "lanzamiento_alberto" {
  name = "instancia-alberto"
  image_id = "ami-0a242269c4b530c5e" 
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.http_sg.id}","${aws_security_group.ssh_sg.id}"]
  key_name = "Clave-Alberto" 
  user_data = filebase64("http.sh")
}

// Crear un grupo de autoescalado
resource "aws_autoscaling_group" "asg" {
  name                = "asg"
  max_size            = 4
  min_size            = 1
  desired_capacity    = 2
  vpc_zone_identifier =  ["${aws_subnet.private_subnet.id}","${aws_subnet.private_subnet1.id}", "${aws_subnet.private_subnet2.id}"]
  health_check_type   = "EC2"

  launch_template {
    id      = aws_launch_template.lanzamiento_alberto.id
    version = aws_launch_template.lanzamiento_alberto.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 10
    }
  }

}

resource "aws_autoscaling_attachment" "asg-attach" {
  autoscaling_group_name  = aws_autoscaling_group.asg.id
  alb_target_group_arn    = aws_lb_target_group.tg-group.arn
}

resource "aws_autoscaling_policy" "asg-policy" {
  name                    = "policy-asg"
  autoscaling_group_name  = aws_autoscaling_group.asg.id
  policy_type             = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}
