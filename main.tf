#---------My task 1------------

provider "aws" {
    region     = "us-east-1"
}


data "aws_availability_zones" "available" {}
data "aws_ami" "latest_ubuntu" {
  owners      = ["099720109477"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
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

resource "aws_launch_template" "web" {
  name = "web"

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = 10
    }
  }

  capacity_reservation_specification {
    capacity_reservation_preference = "open"
  }

  cpu_options {
    core_count       = 2
    threads_per_core = 1
  }

  credit_specification {
    cpu_credits = "standard"
  }

  disable_api_termination = true

  ebs_optimized = true

    iam_instance_profile {
    name = "WebServerDiplom"
  }

  image_id = data.aws_ami.latest_ubuntu.id

  instance_initiated_shutdown_behavior = "terminate"

  instance_type = "t3.micro"

  key_name = "hw41"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = false
  }

  network_interfaces {
    associate_public_ip_address = true
  }

#   placement {
#     availability_zone = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
#   }

  ram_disk_id = "test"

  vpc_security_group_ids = [aws_security_group.webSG.id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "MyWebServer"
    }
  }

  user_data = filebase64("${path.module}/user_data.sh")
}

# resource "aws_launch_configuration" "web" {
#   //  name            = "WebServer-Highly-Available-LC"
#   name_prefix     = "WebServer-Highly-Available-LC-"
#   image_id        = data.aws_ami.latest_ubuntu.id
#   instance_type   = "t3.micro"
#   security_groups = [aws_security_group.webSG.id]
#   user_data       = file("user_data.sh")
#   key_name        = "hw41"

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# "aws_launch_template" "web"

resource "aws_autoscaling_group" "web" {
  name                 = "ASG-${aws_launch_template.web.name}"
#   launch_configuration = aws_launch_configuration.web.name
  min_size             = 2
  max_size             = 2
  min_elb_capacity     = 2
  health_check_type    = "ELB"
  vpc_zone_identifier  = [aws_default_subnet.default_az1.id, aws_default_subnet.default_az2.id]
  load_balancers       = [aws_elb.web.name]
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

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_elb" "web" {
  name               = "WebServer-HA-ELB"
  availability_zones = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  security_groups    = [aws_security_group.webSG.id]
  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = 80
    instance_protocol = "http"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 10
  }
  tags = {
    Name = "WebServer-Highly-Available-ELB"
  }
}


resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available.names[0]
}

resource "aws_default_subnet" "default_az2" {
  availability_zone = data.aws_availability_zones.available.names[1]
}

#--------------------------------------------------
