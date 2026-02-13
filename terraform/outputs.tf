output "instance_public_ip" {
  description = "Public IP address of the EC2 instance."
  value       = aws_instance.minishop.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance."
  value       = aws_instance.minishop.public_dns
}
