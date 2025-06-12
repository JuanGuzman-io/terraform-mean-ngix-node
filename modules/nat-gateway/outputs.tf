# Outputs del módulo NAT Gateway

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_public_ip" {
  description = "Public IP address of the NAT Gateway"
  value       = aws_eip.nat_gateway.public_ip
}

output "nat_gateway_private_ip" {
  description = "Private IP address of the NAT Gateway"
  value       = aws_nat_gateway.main.private_ip
}

output "elastic_ip_id" {
  description = "ID of the Elastic IP associated with NAT Gateway"
  value       = aws_eip.nat_gateway.id
}

output "elastic_ip_allocation_id" {
  description = "Allocation ID of the Elastic IP"
  value       = aws_eip.nat_gateway.allocation_id
}

output "nat_gateway_subnet_id" {
  description = "Subnet ID where NAT Gateway is located"
  value       = aws_nat_gateway.main.subnet_id
}

output "nat_gateway_network_interface_id" {
  description = "Network interface ID of the NAT Gateway"
  value       = aws_nat_gateway.main.network_interface_id
}

output "nat_gateway_summary" {
  description = "Summary of NAT Gateway configuration"
  value = {
    id         = aws_nat_gateway.main.id
    public_ip  = aws_eip.nat_gateway.public_ip
    private_ip = aws_nat_gateway.main.private_ip
    subnet_id  = aws_nat_gateway.main.subnet_id
  }
}
