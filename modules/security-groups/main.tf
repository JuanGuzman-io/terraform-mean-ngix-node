# Módulo de Security Groups

# Security Group para Application Load Balancer
resource "aws_security_group" "alb_sg" {
  name_prefix = "${var.project_name}-${var.environment}-alb-"
  vpc_id      = var.vpc_id
  description = "Security group for Application Load Balancer"

  # Reglas de entrada - Tráfico HTTP/HTTPS desde internet
  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Reglas de salida - Hacia servidores web
  egress {
    description = "HTTP to Web Servers"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Node.js to Web Servers"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Health checks
  egress {
    description = "Health Check"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb-sg"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "Application Load Balancer"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group para servidor web (Nginx + Node.js)
resource "aws_security_group" "web_sg" {
  name_prefix = "${var.project_name}-${var.environment}-web-"
  vpc_id      = var.vpc_id
  description = "Security group for Web Server (Nginx + Node.js)"

  # Reglas de entrada - Solo desde ALB
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description     = "Node.js from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # SSH desde bastion host o administración
  ingress {
    description = "SSH access from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Monitoreo y métricas (opcional)
  ingress {
    description = "CloudWatch agent"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Reglas de salida
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-web-sg"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "Web Server (Nginx + Node.js)"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group para MongoDB
resource "aws_security_group" "db_sg" {
  name_prefix = "${var.project_name}-${var.environment}-db-"
  vpc_id      = var.vpc_id
  description = "Security group for MongoDB database"

  # Reglas de entrada - Solo desde servidor web
  ingress {
    description     = "MongoDB from Web Server"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  # MongoDB replica set communication (si se necesita en el futuro)
  ingress {
    description = "MongoDB replica set"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    self        = true
  }

  # SSH para administración
  ingress {
    description = "SSH access from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Monitoreo de MongoDB
  ingress {
    description = "MongoDB monitoring"
    from_port   = 28017
    to_port     = 28017
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Reglas de salida - Solo tráfico necesario
  egress {
    description = "DNS resolution"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS for updates"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP for updates"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NTP para sincronización de tiempo
  egress {
    description = "NTP"
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-sg"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "MongoDB Database"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Reglas adicionales de seguridad
resource "aws_security_group_rule" "web_to_db_mongodb" {
  type                     = "egress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.db_sg.id
  security_group_id        = aws_security_group.web_sg.id
  description              = "Allow web server to connect to MongoDB"
}

# Regla para health checks del ALB
resource "aws_security_group_rule" "alb_health_check" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.web_sg.id
  description       = "Allow ALB health checks"
}
