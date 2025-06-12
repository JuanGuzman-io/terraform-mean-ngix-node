# Outputs del módulo ALB

output "alb_id" {
  description = "ID of the Application Load Balancer"
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer"
  value       = aws_lb.main.arn_suffix
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "target_group_arn" {
  description = "ARN of the web target group"
  value       = aws_lb_target_group.web.arn
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the web target group"
  value       = aws_lb_target_group.web.arn_suffix
}

output "api_target_group_arn" {
  description = "ARN of the API target group (if enabled)"
  value       = var.enable_api_target_group ? aws_lb_target_group.api[0].arn : null
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.web_http.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener (if enabled)"
  value       = var.ssl_certificate_arn != "" ? aws_lb_listener.web_https[0].arn : null
}

output "alb_hosted_zone_id" {
  description = "The canonical hosted zone ID of the load balancer (to be used in Route 53)"
  value       = aws_lb.main.zone_id
}

output "alb_security_group_id" {
  description = "Security group ID of the ALB"
  value       = var.security_group_id
}

output "load_balancer_summary" {
  description = "Summary of load balancer configuration"
  value = {
    name             = aws_lb.main.name
    dns_name         = aws_lb.main.dns_name
    zone_id          = aws_lb.main.zone_id
    target_group_arn = aws_lb_target_group.web.arn
    https_enabled    = var.ssl_certificate_arn != ""
    api_enabled      = var.enable_api_target_group
  }
}
