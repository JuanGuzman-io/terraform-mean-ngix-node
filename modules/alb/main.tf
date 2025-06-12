# Módulo Application Load Balancer

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  enable_http2              = true
  idle_timeout              = 60

  # Configuración de logs de acceso (opcional)
  dynamic "access_logs" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      prefix  = "${var.project_name}-${var.environment}-alb"
      enabled = true
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "Application Load Balancer"
  }
}

# Target Group para servidores web
resource "aws_lb_target_group" "web" {
  name     = "${var.project_name}-${var.environment}-web-tg"
  port     = var.target_port
  protocol = var.target_protocol
  vpc_id   = var.vpc_id

  # Configuración de health checks
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = var.target_protocol
    timeout             = 5
    unhealthy_threshold = 2
  }

  # Configuración de stickiness (opcional)
  dynamic "stickiness" {
    for_each = var.enable_stickiness ? [1] : []
    content {
      type            = "lb_cookie"
      cookie_duration = 86400  # 24 horas
      enabled         = true
    }
  }

  # Configuración de deregistration delay
  deregistration_delay = 300

  tags = {
    Name        = "${var.project_name}-${var.environment}-web-tg"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "Web Servers Target Group"
  }
}

# Target Group Attachment para instancia web
resource "aws_lb_target_group_attachment" "web" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = var.target_instance_id
  port             = var.target_port
}

# Listener HTTP principal
resource "aws_lb_listener" "web_http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-http-listener"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Listener HTTPS (opcional, si se proporciona certificado SSL)
resource "aws_lb_listener" "web_https" {
  count = var.ssl_certificate_arn != "" ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.ssl_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-https-listener"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Listener rule para redirección HTTP a HTTPS (si HTTPS está habilitado)
resource "aws_lb_listener_rule" "redirect_http_to_https" {
  count = var.ssl_certificate_arn != "" && var.redirect_http_to_https ? 1 : 0

  listener_arn = aws_lb_listener.web_http.arn
  priority     = 100

  action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    http_header {
      http_header_name = "*"
      values           = ["*"]
    }
  }
}

# Target Group adicional para API (Node.js en puerto 3000)
resource "aws_lb_target_group" "api" {
  count = var.enable_api_target_group ? 1 : 0

  name     = "${var.project_name}-${var.environment}-api-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/api/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-api-tg"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "Node.js API Target Group"
  }
}

# Target Group Attachment para API
resource "aws_lb_target_group_attachment" "api" {
  count = var.enable_api_target_group ? 1 : 0

  target_group_arn = aws_lb_target_group.api[0].arn
  target_id        = var.target_instance_id
  port             = 3000
}

# Listener Rule para rutas de API
resource "aws_lb_listener_rule" "api_routing" {
  count = var.enable_api_target_group ? 1 : 0

  listener_arn = aws_lb_listener.web_http.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api[0].arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

# CloudWatch Alarms para ALB
resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "120"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors ALB target response time"
  alarm_actions       = var.alarm_notification_topic != "" ? [var.alarm_notification_topic] : []

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb-response-time-alarm"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors unhealthy targets"
  alarm_actions       = var.alarm_notification_topic != "" ? [var.alarm_notification_topic] : []

  dimensions = {
    TargetGroup  = aws_lb_target_group.web.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb-unhealthy-hosts-alarm"
    Project     = var.project_name
    Environment = var.environment
  }
}
