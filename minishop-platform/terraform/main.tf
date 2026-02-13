terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS provider with the chosen region.
provider "aws" {
  region = var.aws_region
}

# Use the default VPC to keep the demo minimal and free-tier friendly.
data "aws_vpc" "default" {
  default = true
}

# Pick one subnet from the default VPC.
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Latest Amazon Linux 2 AMI for x86_64 (t2.micro compatible).
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Security group allowing SSH, HTTP, and Kubernetes NodePorts.
resource "aws_security_group" "minishop_sg" {
  name        = "minishop-sg"
  description = "Security group for minishop-platform"
  vpc_id      = data.aws_vpc.default.id

  # SSH access from your IP only.
  ingress {
    description = "SSH from your IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  # Public HTTP access for the web service.
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Kubernetes NodePort range for exposing services.
  ingress {
    description = "Kubernetes NodePort"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "minishop-sg"
  }
}

# Single EC2 instance (Free Tier compatible) hosting k3s.
resource "aws_instance" "minishop" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.minishop_sg.id]
  key_name               = var.ssh_key_name

  tags = {
    Name = var.instance_name
  }
}
