# Variables del módulo EC2

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "key_pair_name" {
  description = "Name of the EC2 Key Pair"
  type        = string
}

variable "web_instance_config" {
  description = "Configuration for web server instance"
  type = object({
    ami_id                 = string
    instance_type          = string
    subnet_id              = string
    security_group_ids     = list(string)
    associate_public_ip    = bool
    user_data_script_path  = string
  })
}

variable "db_instance_config" {
  description = "Configuration for database server instance"
  type = object({
    ami_id                 = string
    instance_type          = string
    subnet_id              = string
    security_group_ids     = list(string)
    associate_public_ip    = bool
    user_data_script_path  = string
  })
}

variable "mongodb_private_ip" {
  description = "Private IP of MongoDB instance (for web server configuration)"
  type        = string
  default     = ""
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

variable "web_root_volume_size" {
  description = "Size of root volume for web server (GB)"
  type        = number
  default     = 20
}

variable "db_root_volume_size" {
  description = "Size of root volume for database server (GB)"
  type        = number
  default     = 20
}

variable "mongodb_data_volume_size" {
  description = "Size of additional EBS volume for MongoDB data (GB)"
  type        = number
  default     = 50
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "assign_elastic_ips" {
  description = "Assign Elastic IPs to instances"
  type        = bool
  default     = false
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}
