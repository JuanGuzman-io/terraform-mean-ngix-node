# main.tf - Configuración principal del proyecto MEAN Stack

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Team        = "TechOps Solutions"
    }
  }
}

# Data source para obtener zonas de disponibilidad
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module - Infraestructura de red
module "vpc" {
  source = "./modules/vpc"
  
  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

# Security Groups Module - Configuración de firewalls
module "security_groups" {
  source = "./modules/security-groups"
  
  vpc_id       = module.vpc.vpc_id
  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
}

# NAT Gateway Module - Acceso a internet para instancias privadas
module "nat_gateway" {
  source = "./modules/nat-gateway"
  
  public_subnet_id = module.vpc.public_subnet_ids[0]
  project_name     = var.project_name
  environment      = var.environment
  
  # Actualizar tabla de enrutamiento de subredes privadas
  private_route_table_ids = module.vpc.private_route_table_ids
}

# EC2 Instances Module - Servidores de aplicación y base de datos
module "ec2" {
  source = "./modules/ec2"
  
  # Configuración del servidor web (Nginx + Node.js)
  web_instance_config = {
    ami_id                    = var.web_ami_id
    instance_type            = var.web_instance_type
    subnet_id                = module.vpc.private_subnet_ids[0]
    security_group_ids       = [module.security_groups.web_sg_id]
    associate_public_ip      = false
    user_data_script_path    = "./scripts/nginx-nodejs-setup.sh"
  }
  
  # Configuración del servidor de base de datos (MongoDB)
  db_instance_config = {
    ami_id                    = var.db_ami_id
    instance_type            = var.db_instance_type
    subnet_id                = module.vpc.private_subnet_ids[1]
    security_group_ids       = [module.security_groups.db_sg_id]
    associate_public_ip      = false
    user_data_script_path    = "./scripts/mongodb-setup.sh"
  }
  
  project_name  = var.project_name
  environment   = var.environment
  key_pair_name = var.key_pair_name
  
  # Pasar credenciales de MongoDB
  mongodb_username = var.mongodb_username
  mongodb_password = var.mongodb_password
}

# Application Load Balancer Module - Distribución de tráfico
module "alb" {
  source = "./modules/alb"
  
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  security_group_id = module.security_groups.alb_sg_id
  target_instance_id = module.ec2.web_instance_id
  
  project_name = var.project_name
  environment  = var.environment
}
