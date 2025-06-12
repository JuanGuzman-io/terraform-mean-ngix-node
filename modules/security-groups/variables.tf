# Variables del módulo Security Groups

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "admin_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access to bastion host"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Cambiar en producción
}

variable "enable_bastion" {
  description = "Enable bastion host security group"
  type        = bool
  default     = false
}

variable "mongodb_port" {
  description = "MongoDB port"
  type        = number
  default     = 27017
}

variable "nodejs_port" {
  description = "Node.js application port"
  type        = number
  default     = 3000
}

variable "nginx_port" {
  description = "Nginx port"
  type        = number
  default     = 80
}
