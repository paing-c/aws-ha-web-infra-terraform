output "vpc_id" {
  description = "ID of the custom VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs in availability zone order."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs in availability zone order."
  value       = aws_subnet.private[*].id
}

output "alb_security_group_id" {
  description = "ID of the load balancer security group."
  value       = aws_security_group.alb_sg.id
}

output "ec2_security_group_id" {
  description = "ID of the web instance security group."
  value       = aws_security_group.ec2_sg.id
}

output "alb_dns_name" {
  description = "Public DNS name of the application load balancer."
  value       = aws_lb.web.dns_name
}

output "alb_url" {
  description = "HTTP URL for the web application."
  value       = "http://${aws_lb.web.dns_name}"
}
