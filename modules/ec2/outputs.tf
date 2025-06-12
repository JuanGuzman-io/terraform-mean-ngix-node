# Outputs del módulo EC2

output "web_instance_id" {
  description = "ID of the web server instance"
  value       = aws_instance.web.id
}

output "db_instance_id" {
  description = "ID of the database server instance"
  value       = aws_instance.db.id
}

output "web_instance_private_ip" {
  description = "Private IP address of the web server instance"
  value       = aws_instance.web.private_ip
}

output "db_instance_private_ip" {
  description = "Private IP address of the database server instance"
  value       = aws_instance.db.private_ip
}

output "web_instance_public_ip" {
  description = "Public IP address of the web server instance"
  value       = aws_instance.web.public_ip
}

output "db_instance_public_ip" {
  description = "Public IP address of the database server instance"
  value       = aws_instance.db.public_ip
}

output "web_instance_dns" {
  description = "Public DNS name of the web server instance"
  value       = aws_instance.web.public_dns
}

output "db_instance_dns" {
  description = "Public DNS name of the database server instance"
  value       = aws_instance.db.public_dns
}

output "mongodb_data_volume_id" {
  description = "ID of the MongoDB data EBS volume"
  value       = aws_ebs_volume.mongodb_data.id
}

output "web_instance_arn" {
  description = "ARN of the web server instance"
  value       = aws_instance.web.arn
}

output "db_instance_arn" {
  description = "ARN of the database server instance"
  value       = aws_instance.db.arn
}

output "iam_role_arn" {
  description = "ARN of the IAM role for EC2 instances"
  value       = aws_iam_role.ec2_role.arn
}

output "instances_summary" {
  description = "Summary of all EC2 instances"
  value = {
    web_server = {
      instance_id = aws_instance.web.id
      private_ip  = aws_instance.web.private_ip
      public_ip   = aws_instance.web.public_ip
      az          = aws_instance.web.availability_zone
    }
    db_server = {
      instance_id = aws_instance.db.id
      private_ip  = aws_instance.db.private_ip
      public_ip   = aws_instance.db.public_ip
      az          = aws_instance.db.availability_zone
    }
  }
}
