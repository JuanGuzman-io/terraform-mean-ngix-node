# variables.tf - Variables globales del proyecto

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.aws_region))
    error_message = "AWS region must be a valid region identifier."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "mean-stack"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least 2 public subnets are required for ALB."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least 2 private subnets are required."
  }
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones are required."
  }
}

variable "web_ami_id" {
  description = "AMI ID for web server (with Nginx, Node.js pre-installed)"
  type        = string
  default     = "ami-0c7217cdde317cfec"  # Amazon Linux 2023
}

variable "db_ami_id" {
  description = "AMI ID for database server (with MongoDB pre-installed)"
  type        = string
  default     = "ami-0c7217cdde317cfec"  # Amazon Linux 2023
}

variable "web_instance_type" {
  description = "Instance type for web server"
  type        = string
  default     = "t2.micro"
  validation {
    condition     = contains(["t2.micro", "t2.small", "t2.medium", "t3.micro", "t3.small", "t3.medium"], var.web_instance_type)
    error_message = "Instance type must be a valid t2/t3 instance type."
  }
}

variable "db_instance_type" {
  description = "Instance type for database server"
  type        = string
  default     = "t2.micro"
  validation {
    condition     = contains(["t2.micro", "t2.small", "t2.medium", "t3.micro", "t3.small", "t3.medium"], var.db_instance_type)
    error_message = "Instance type must be a valid t2/t3 instance type."
  }
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
  default     = "mean-stack-keypair"
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "enable_mongodb_auth" {
  description = "Enable MongoDB authentication"
  type        = bool
  default     = true
}

variable "mongodb_username" {
  description = "MongoDB admin username"
  type        = string
  default     = "meanadmin"
  sensitive   = true
}

variable "mongodb_password" {
  description = "MongoDB admin password"
  type        = string
  default     = "SecureP@ssw0rd123!"
  sensitive   = true
}
