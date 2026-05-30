###############################################################
# outputs.tf — Valors exportats
###############################################################

output "alb_dns_name" {
  description = "DNS públic del balancejador de càrrega (ALB)"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID de l'ALB (per a Route53)"
  value       = aws_lb.main.zone_id
}

output "wordpress_url" {
  description = "URL d'accés a WordPress"
  value       = "http://${aws_lb.main.dns_name}"
}

output "rds_endpoint" {
  description = "Endpoint de connexió a RDS MySQL"
  value       = aws_db_instance.wordpress.address
  sensitive   = true
}

output "rds_port" {
  description = "Port de RDS MySQL"
  value       = aws_db_instance.wordpress.port
}

output "efs_dns_name" {
  description = "DNS de l'Elastic File System"
  value       = aws_efs_file_system.wordpress.dns_name
}

output "efs_id" {
  description = "ID de l'Elastic File System"
  value       = aws_efs_file_system.wordpress.id
}

output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs de les subnets públiques"
  value       = { for k, s in aws_subnet.public : k => s.id }
}

output "private_subnet_ids" {
  description = "IDs de les subnets privades"
  value       = { for k, s in aws_subnet.private : k => s.id }
}

output "autoscaling_group_name" {
  description = "Nom de l'Auto Scaling Group"
  value       = aws_autoscaling_group.wordpress.name
}

output "launch_template_id" {
  description = "ID del Launch Template"
  value       = aws_launch_template.wordpress.id
}

output "nat_gateway_public_ip" {
  description = "IP pública del NAT Gateway"
  value       = aws_eip.nat.public_ip
}
