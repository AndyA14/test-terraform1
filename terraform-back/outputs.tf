output "backend1_public_ip" {
  description = "Public IP of backend1"
  value       = aws_instance.backend1.public_ip
}

output "backend2_public_ip" {
  description = "Public IP of backend2"
  value       = aws_instance.backend2.public_ip
}
