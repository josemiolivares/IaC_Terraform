# =============================================================
# variables.tf
# =============================================================

variable "aws_region" {
  description = "Regio AWS on desplegar la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nom del projecte (s_usa com a prefix per als recursos)"
  type        = string
  default     = "aws-tf-josemi"
}

variable "vpc_cidr" {
  description = "Bloc CIDR de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs per a les subnets publiques (una per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs per a les subnets privades (una per AZ)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "instance_type" {
  description = "Tipus d_instancia EC2"
  type        = string
  default     = "t3.micro"
}

variable "ssh_public_key" {
  description = "Clau publica SSH per accedir a les instancies"
  type        = string
  # Afegeix la teua clau pública aquí o passa-la via terraform.tfvars
  # Exemple: ssh-rsa AAAA... user@host
}

variable "domain_name" {
  description = "Nom de domini per al certificat SSL (ha d_existir a Route 53)"
  type        = string
  default = awstf1.josemiolivares.net
  # Exemple: "example.com"
}

variable "health_check_path" {
  description = "Ruta del health check del Target Group"
  type        = string
  default     = "/"
}

variable "common_tags" {
  description = "Tags comuns per a tots els recursos"
  type        = map(string)
  default = {
    Project     = "practica-terraform-aws"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

# Parámetros para la base de datos (RDS MySQL)
variable "db_name" {
description = "Nombre de la base de datos de WordPress en RDS"
type = string
default = "wordpress"
}
variable "db_username" {
description = "Usuario administrador de la base de datos RDS"
type = string
default = "admin"
}
variable "db_password" {
description = "Contraseña del usuario de la base de datos RDS"
type = string
default = "PAssw0rd1234" # En entorno real, usar una contraseña segura y no hardcodeada
sensitive = true # Marcar como sensible para no mostrar en salida de Terraform
}

variable "DOMAIN_NAME" {
  type        = string
  description = "Dominio para la instalación de WordPress"
  default     = "wordpress-iac-tf.midemo.com"
}

variable "DEMO_USERNAME" {
  type        = string
  description = "Usuario administrador para WordPress"
  default     = "wpadmin"
}

variable "DEMO_PASSWORD" {
  type        = string
  description = "Contraseña administrador para WordPress"
  default     = "wppassword123"
  sensitive = true # Marcar como sensible para no mostrar en salida de Terraform
}

variable "DEMO_EMAIL" {
  type        = string
  description = "Email administrador para WordPress"
  default     = "admin@midemo.com"
}
