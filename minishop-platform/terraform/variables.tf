variable "aws_region" {
  description = "AWS region to deploy into (e.g., us-east-1)."
  type        = string
}

variable "ssh_key_name" {
  description = "Name of an existing EC2 key pair to allow SSH access."
  type        = string
}

variable "ssh_cidr" {
  description = "Your public IP in CIDR notation for SSH access (e.g., 203.0.113.10/32)."
  type        = string
}

variable "instance_name" {
  description = "Tag name for the EC2 instance."
  type        = string
  default     = "minishop-k3s"
}
