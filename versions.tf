# versions.tf - Especificación de versiones de Terraform y providers

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    
    local = {
      source  = "hashicorp/local"
      version = "~> 2.1"
    }
    
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  
  # Backend configuration para remote state (descomentar si se usa)
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "mean-stack/terraform.tfstate"
  #   region = "us-east-1"
  #   
  #   # DynamoDB table para state locking
  #   dynamodb_table = "terraform-state-lock"
  #   encrypt        = true
  # }
}

# Provider configuration con configuración por defecto
provider "aws" {
  region = var.aws_region
  
  # Tags por defecto para todos los recursos
  default_tags {
    tags = {
      Project      = var.project_name
      Environment  = var.environment
      ManagedBy    = "Terraform"
      Team         = "TechOps Solutions"
      Company      = "FinTech Solutions S.A."
      CreatedDate  = formatdate("YYYY-MM-DD", timestamp())
    }
  }
}
