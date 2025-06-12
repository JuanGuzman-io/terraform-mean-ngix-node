# Módulo EC2 para instancias

# Data source para obtener la AMI más reciente de Amazon Linux 2023
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Template para user data del servidor web
locals {
  web_user_data = templatefile("${path.module}/../../scripts/nginx-nodejs-setup.sh", {
    mongodb_private_ip = var.mongodb_private_ip != "" ? var.mongodb_private_ip : "TO_BE_UPDATED"
    project_name       = var.project_name
    environment        = var.environment
    mongodb_username   = var.mongodb_username
    mongodb_password   = var.mongodb_password
  })

  db_user_data = templatefile("${path.module}/../../scripts/mongodb-setup.sh", {
    project_name     = var.project_name
    environment      = var.environment
    mongodb_username = var.mongodb_username
    mongodb_password = var.mongodb_password
  })
}

# IAM Role para instancias EC2
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

# IAM Policy para CloudWatch Logs
resource "aws_iam_role_policy" "ec2_cloudwatch_policy" {
  name = "${var.project_name}-${var.environment}-cloudwatch-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

# Instance Profile para EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-profile"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Instancia EC2 para servidor web (Nginx + Node.js)
resource "aws_instance" "web" {
  ami                    = var.web_instance_config.ami_id != "" ? var.web_instance_config.ami_id : data.aws_ami.amazon_linux.id
  instance_type          = var.web_instance_config.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = var.web_instance_config.security_group_ids
  subnet_id              = var.web_instance_config.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  associate_public_ip_address = var.web_instance_config.associate_public_ip

  user_data = base64encode(local.web_user_data)

  # Configuración de volumen raíz
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.web_root_volume_size
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name        = "${var.project_name}-${var.environment}-web-root-volume"
      Project     = var.project_name
      Environment = var.environment
    }
  }

  # Configuración de metadatos
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-web-server"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "Web Server (Nginx + Node.js)"
    Backup      = "true"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Instancia EC2 para base de datos (MongoDB)
resource "aws_instance" "db" {
  ami                    = var.db_instance_config.ami_id != "" ? var.db_instance_config.ami_id : data.aws_ami.amazon_linux.id
  instance_type          = var.db_instance_config.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = var.db_instance_config.security_group_ids
  subnet_id              = var.db_instance_config.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  associate_public_ip_address = var.db_instance_config.associate_public_ip

  user_data = base64encode(local.db_user_data)

  # Configuración de volumen raíz
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.db_root_volume_size
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name        = "${var.project_name}-${var.environment}-db-root-volume"
      Project     = var.project_name
      Environment = var.environment
    }
  }

  # Configuración de metadatos
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-server"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "Database Server (MongoDB)"
    Backup      = "true"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Volumen EBS adicional para datos de MongoDB
resource "aws_ebs_volume" "mongodb_data" {
  availability_zone = aws_instance.db.availability_zone
  size              = var.mongodb_data_volume_size
  type              = "gp3"
  encrypted         = true
  iops              = 3000
  throughput        = 125

  tags = {
    Name        = "${var.project_name}-${var.environment}-mongodb-data-volume"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "MongoDB Data Storage"
    Backup      = "true"
  }
}

# Attachment del volumen EBS al servidor de base de datos
resource "aws_volume_attachment" "mongodb_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.mongodb_data.id
  instance_id = aws_instance.db.id
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "web_server_logs" {
  name              = "/aws/ec2/${var.project_name}-${var.environment}-web-server"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-${var.environment}-web-server-logs"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "db_server_logs" {
  name              = "/aws/ec2/${var.project_name}-${var.environment}-db-server"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-server-logs"
    Project     = var.project_name
    Environment = var.environment
  }
}
