output "frontend_alb_dns_name" {
  description = "DNS name of the frontend load balancer"
  value       = aws_lb.front_alb.dns_name
}

output "frontend_asg_name" {
  description = "Name of the frontend Auto Scaling Group"
  value       = aws_autoscaling_group.front_asg.name
}

