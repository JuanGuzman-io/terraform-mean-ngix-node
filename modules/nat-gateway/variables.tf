# Variables del módulo NAT Gateway

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "public_subnet_id" {
  description = "ID of the public subnet where NAT Gateway will be created"
  type        = string
}

variable "private_route_table_ids" {
  description = "List of private route table IDs to add NAT Gateway routes"
  type        = list(string)
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms for NAT Gateway monitoring"
  type        = bool
  default     = true
}

variable "alarm_notification_topic" {
  description = "SNS topic ARN for CloudWatch alarm notifications"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags for NAT Gateway resources"
  type        = map(string)
  default     = {}
}
