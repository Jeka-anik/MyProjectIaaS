#---------My Project------------

provider "aws" {
    region     = "us-east-1"
}
#-----------------------------------------
variable "instance_type" {
  description = "EC2 instance type"
  default     = "t3.micro"
}
#-----------------------------------------
variable "app_subnets" { 
    type = list(string) 
    description = "App subnets id" 
    default = ["subnet-4369fc25", "subnet-da21b785"]
} 
#------------------------------------------------
data "aws_availability_zones" "available" {}
#------------------------------------------------
data "aws_ami" "latest_ubuntu" {
  owners      = ["099720109477"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

#--------------------------------------------------------------
resource "aws_security_group" "webSG" {
  name = "Dynamic Security Group"

  dynamic "ingress" {
    for_each = ["80", "443", "22", "8080"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "Dynamic SecurityGroup"
    Owner = "Anik"
  }
}
#----------------------------------------
resource "aws_launch_template" "web" {
  name = "web"
  image_id      = data.aws_ami.latest_ubuntu.id
  instance_type = var.instance_type
  key_name = "hw41"
  user_data = filebase64("${path.module}/user_data.sh")
  disable_api_termination = true
  ebs_optimized = true
    cpu_options {
    core_count       = 2
    threads_per_core = 2
  }
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    security_groups             = [aws_security_group.webSG.id]
  }
  credit_specification {
    cpu_credits = "standard"
  }
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 10
    }
  }
    iam_instance_profile {
    name = "web"
  }
  placement {
    availability_zone = "us-east-1"
  }
  instance_initiated_shutdown_behavior = "terminate"
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  vpc_security_group_ids = [aws_security_group.webSG.id]
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "MyWebServer"
    }
  }
}
#--------------------------------------
resource "aws_lb_target_group" "webtg" {
  name     = "tf-lb-tg"
  port     = 80
  protocol = "HTTP"
  target_type = "instance"
  vpc_id   = aws_vpc.main.id
}
#--------------------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
#--------------------------------------------
resource "aws_placement_group" "test" {
  name     = "test"
  strategy = "cluster"
}
#-------------------------------------------------
resource "aws_autoscaling_group" "webASG" {
  name                 = "ASG-${aws_launch_template.web.name}"
#   launch_configuration = aws_launch_configuration.web.name
  min_size             = 2
  max_size             = 2
  min_elb_capacity     = 2
  placement_group      = aws_placement_group.test.id
  health_check_type    = "ELB"
  vpc_zone_identifier  = [aws_default_subnet.default_az1.id, aws_default_subnet.default_az2.id]
  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }
  dynamic "tag" {
    for_each = {
      Name   = "WebServer in ASG"
      Owner  = "Anik"
      TAGKEY = "TAGVALUE"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  depends_on = [aws_lb.weblb]
  lifecycle {
    create_before_destroy = true
  }
}
#-------------------------------
resource "aws_lb" "weblb" {
  name               = "weblb"
  internal           = false
  load_balancer_type = "application"
  subnets            =  var.app_subnets
  security_groups    = [aws_security_group.webSG.id]
  tags = {
    Name = "WebServer-Highly-Available-ELB"
  }
}
#------------------------------------------
resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = aws_lb_target_group.webtg.arn
  target_id        = data.aws_ami.latest_ubuntu.id
  port             = 80
}
#---------------------------------------------------------
resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.webASG.id
  alb_target_group_arn   = aws_lb_target_group.webtg.arn
}
#--------------------------------------------------------------
resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available.names[0]
}

resource "aws_default_subnet" "default_az2" {
  availability_zone = data.aws_availability_zones.available.names[1]
}

#--------------------------------------------------
