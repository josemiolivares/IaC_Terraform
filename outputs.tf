# =============================================================
# outputs.tf
# =============================================================

output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs de les subnets públiques"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs de les subnets privades"
  value       = aws_subnet.private[*].id
}

output "alb_dns_name" {
  description = "DNS name del Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID del ALB (per a Route 53 alias)"
  value       = aws_lb.main.zone_id
}

output "alb_arn" {
  description = "ARN del Application Load Balancer"
  value       = aws_lb.main.arn
}

output "ec2_instance_ids" {
  description = "IDs de les instàncies EC2"
  value       = aws_instance.web[*].id
}

output "ec2_private_ips" {
  description = "IPs privades de les instàncies EC2"
  value       = aws_instance.web[*].private_ip
}

output "ec2_availability_zones" {
  description = "AZs on estan desplegades les instàncies"
  value       = aws_instance.web[*].availability_zone
}

output "certificate_arn" {
  description = "ARN del certificat SSL/TLS"
  value       = aws_acm_certificate.main.arn
}

output "website_url" {
  description = "URL pública del lloc web"
  value       = "https://${var.domain_name}"
}

output "nat_gateway_public_ips" {
  description = "IPs públiques dels NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}
