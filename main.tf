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

# resource "aws_instance" "first-server" {
#     ami = " ami-0b9064170e32bde34"
#     instance_type = "t2.micro"
#     tags = {
#       Name = "ubuntu"
#     }
# }

resource "aws_vpc" "first-vpc" {
  cidr_block = "10.0.0.6/16"
  tags = {
    Name = "production"
  }
}
