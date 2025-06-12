# Módulo NAT Gateway

# Elastic IP para NAT Gateway
resource "aws_eip" "nat_gateway" {
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-gateway-eip"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "NAT Gateway"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = var.public_subnet_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-gateway"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "Internet access for private subnets"
  }

  # Para asegurar el orden correcto de creación
  depends_on = [aws_eip.nat_gateway]
}

# Ruta hacia NAT Gateway en las tablas de enrutamiento privadas
resource "aws_route" "private_nat_gateway" {
  count = length(var.private_route_table_ids)

  route_table_id         = var.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id

  timeouts {
    create = "5m"
  }
}

# CloudWatch Alarms para monitoreo de NAT Gateway
resource "aws_cloudwatch_metric_alarm" "nat_gateway_packet_drop" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-nat-gateway-packet-drop"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "PacketDropCount"
  namespace           = "AWS/NatGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "This metric monitors NAT Gateway packet drops"
  alarm_actions       = var.alarm_notification_topic != "" ? [var.alarm_notification_topic] : []

  dimensions = {
    NatGatewayId = aws_nat_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-gateway-packet-drop-alarm"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "nat_gateway_bandwidth_utilization" {
  count = var.enable_cloudwatch_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-nat-gateway-bandwidth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BytesOutToDestination"
  namespace           = "AWS/NatGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1000000000"  # 1GB
  alarm_description   = "This metric monitors NAT Gateway bandwidth utilization"
  alarm_actions       = var.alarm_notification_topic != "" ? [var.alarm_notification_topic] : []

  dimensions = {
    NatGatewayId = aws_nat_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-gateway-bandwidth-alarm"
    Project     = var.project_name
    Environment = var.environment
  }
}
