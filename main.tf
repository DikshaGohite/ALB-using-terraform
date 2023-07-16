provider "aws" {
    region     = "${var.region}"
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
}			


resource "aws_security_group" "my_SG" {

    name = "security-group" 
    description = "Allow incoming HTTP connection"
    ingress {
        from_port = 80
        to_port   = 80
        protocol  = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

}

resource "aws_instance" "my_ec2" {
    
    ami             = "****************"
    instance_type   = "t2.micro"
    count           = 2
    security_groups = ["${aws_security_group.my_SG.name}"]
    user_data       = <<-EOF
    #!/bin/bash
    sudo su
    yum update -y
    yum install -y httpd 
    systemctl start httpd
    systemctl enable httpd
     echo "<h1> Hello from my server $(hostname -f ) </h1>" >> /var/www/html/index.html
     EOF
     tags = {
        Name = "instance-${count.index}"
     }
}


# data blocks are used here to retrieve information about vpc in this case we are using the default vpc

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "subnet1" {
 vpc_id = data.aws_vpc.default.id
 availability_zone = "us-east-1a"
}

data "aws_subnet" "subnet2" {
 vpc_id = data.aws_vpc.default.id
 availability_zone = "us-east-1b"
}

data "aws_subnet" "subnet3" {
 vpc_id = data.aws_vpc.default.id
 availability_zone = "us-east-1c"
}

data "aws_subnet" "subnet4" {
 vpc_id = data.aws_vpc.default.id
 availability_zone = "us-east-1d"
}

resource "aws_lb_target_group" "target-group" {
    health_check {
        interval = 10
        path = "/"
        protocol = "HTTP"
        timeout = 5
        healthy_threshold = 5
        unhealthy_threshold = 2
    }

    name = "my-tg-alb"
    port = 80
    protocol = "HTTP"
    target_type = "instance"
    vpc_id = data.aws_vpc.default.id
}

# Creating Application Load Balancer

resource "aws_lb" "my_alb" {
    name            = "ec2-alb"
    internal        = false
    ip_address_type     = "ipv4"
    load_balancer_type = "application"
    security_groups = [aws_security_group.my_SG.id]
    subnets = [
                data.aws_subnet.subnet1.id,
                data.aws_subnet.subnet2.id
                ]
    tags = {
        Name = "alb"
    }
}
 
# Creating Listener

resource "aws_lb_listener" "alb-listener" {
    load_balancer_arn          = aws_lb.my_alb.arn
    port                       = 80
    protocol                   = "HTTP"
    default_action {
        target_group_arn         = aws_lb_target_group.target-group.arn
        type                     = "forward"
    }
}	

# Attaching ALB and Target group

resource "aws_lb_target_group_attachment" "ec2_and_tg_attach" {
    count = length(aws_instance.my_ec2)
    target_group_arn = aws_lb_target_group.target-group.arn
    target_id        = aws_instance.my_ec2[count.index].id
}			
