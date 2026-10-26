output "public_ip" {
  value       = aws_instance.app.public_ip
  description = "Public IP of the instance"
}

output "app_port" {
  value       = local.app_port
  description = "Port the app listens on (read from the Dockerfile)"
}