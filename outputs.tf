output "ami-ouput" {
    description = "My ami output"
    value = aws_instance.myWebServer.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.myWebServer.public_ip
}
