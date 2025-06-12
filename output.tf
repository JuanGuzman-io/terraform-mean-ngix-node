# output.tf - Outputs del proyecto

# IPs públicas de las instancias EC2
output "web_instance_public_ip" {
  description = "Public IP address of the web server instance"
  value       = "N/A - Instance in private subnet, access via ALB"
}

output "db_instance_public_ip" {
  description = "Public IP address of the database instance"
  value       = "N/A - Private instance, access via NAT Gateway for outbound traffic"
}

# IPs privadas de las instancias EC2
output "web_instance_private_ip" {
  description = "Private IP address of the web server instance"
  value       = module.ec2.web_instance_private_ip
}

output "db_instance_private_ip" {
  description = "Private IP address of the database instance"
  value       = module.ec2.db_instance_private_ip
}

# DNS del balanceador de carga
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.alb.alb_zone_id
}

# IP pública del NAT Gateway
output "nat_gateway_public_ip" {
  description = "Public IP address of the NAT Gateway for MongoDB instance"
  value       = module.nat_gateway.nat_gateway_public_ip
}

# Información adicional de la infraestructura
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

# URLs y cadenas de conexión
output "application_url" {
  description = "URL to access the MEAN application"
  value       = "http://${module.alb.alb_dns_name}"
}

output "mongodb_connection_string_internal" {
  description = "MongoDB connection string for internal application use"
  value       = "mongodb://${var.mongodb_username}:${var.mongodb_password}@${module.ec2.db_instance_private_ip}:27017/meanapp"
  sensitive   = true
}

# Información de seguridad
output "security_group_ids" {
  description = "Security group IDs created"
  value = {
    alb_sg_id = module.security_groups.alb_sg_id
    web_sg_id = module.security_groups.web_sg_id
    db_sg_id  = module.security_groups.db_sg_id
  }
}

# Información de las instancias
output "instance_ids" {
  description = "EC2 instance IDs"
  value = {
    web_instance_id = module.ec2.web_instance_id
    db_instance_id  = module.ec2.db_instance_id
  }
}

# Instrucciones de conexión
output "ssh_connection_instructions" {
  description = "Instructions for SSH connection to instances"
  value = {
    web_server = "ssh -i ${var.key_pair_name}.pem ec2-user@${module.ec2.web_instance_private_ip} (via bastion host)"
    db_server  = "ssh -i ${var.key_pair_name}.pem ec2-user@${module.ec2.db_instance_private_ip} (via bastion host)"
    note       = "Use a bastion host in public subnet for SSH access to private instances"
  }
}
