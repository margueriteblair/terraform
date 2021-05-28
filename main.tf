terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-2"


}

resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
}

resource "aws_route_table" "prod-rt" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}

resouce "aws_subnet" "subnet-1" {
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-2"

  tags = {
    Name = "prod-subnet"
  }
}

#route tables association with the subnet
resource "aws_route_table_association" "a" {
  subnet_id = aws_subnet.subnet-1.id
  router_table_id = aws_route_table.prod-rt.id
}

#now create a security group
#
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  #ingress policy and egress policy
  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [0.0.0.0/0]
    ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }
  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [0.0.0.0/0]
    ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [0.0.0.0/0]
    ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  #we want to connect to any
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1" #any protocol
    cidr_blocks      = ["0.0.0.0/0"] #any IP address
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"] #we can pick any ip address in the subnet
  security_groups = [aws_security_group.allow_web.id]

  attachment {
    instance     = aws_instance.test.id
    device_index = 1
  }
}

resource "aws_eip" "one" {
  vpc = true
  network_interface = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = aws_internet_gateway.gw
}

resource "aws_instance" "web-server-instance" {
  ami = "ami-0b9064170e32bde34"
  instance_type = "t2.micro"
  availability_zone = "us-east-2a" #needs to be the same as the subnet
  key_name = "main-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  user_data = <<-EOF
            #!/bin/bash
            sudo apt update -y
            sudo apt install apache2 -y
            sudo systemctl start apache2
            sudo bash -c 'echo your very first web server > /var/www/html/index.html' 
}

#last step now is to actually create the ubuntu server