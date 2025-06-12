# Outputs del módulo Security Groups

output "alb_sg_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb_sg.id
}

output "web_sg_id" {
  description = "ID of the web server security group"
  value       = aws_security_group.web_sg.id
}

output "db_sg_id" {
  description = "ID of the database security group"
  value       = aws_security_group.db_sg.id
}

output "alb_sg_arn" {
  description = "ARN of the ALB security group"
  value       = aws_security_group.alb_sg.arn
}

output "web_sg_arn" {
  description = "ARN of the web server security group"
  value       = aws_security_group.web_sg.arn
}

output "db_sg_arn" {
  description = "ARN of the database security group"
  value       = aws_security_group.db_sg.arn
}

output "security_groups_summary" {
  description = "Summary of all security groups created"
  value = {
    alb_sg = {
      id   = aws_security_group.alb_sg.id
      name = aws_security_group.alb_sg.name
    }
    web_sg = {
      id   = aws_security_group.web_sg.id
      name = aws_security_group.web_sg.name
    }
    db_sg = {
      id   = aws_security_group.db_sg.id
      name = aws_security_group.db_sg.name
    }
  }
}
