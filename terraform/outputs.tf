output "frontend_alb_dns_name" {
  description = "DNS del Load Balancer del frontend"
  value       = aws_lb.frontend_alb.dns_name
}

output "frontend_asg_name" {
  description = "Nombre del Auto Scaling Group"
  value       = aws_autoscaling_group.frontend_asg.name
}

output "backend1_public_ip" {
  description = "IP pública backend1"
  value       = aws_instance.backend1.public_ip
}

output "backend2_public_ip" {
  description = "IP pública backend2"
  value       = aws_instance.backend2.public_ip
}
