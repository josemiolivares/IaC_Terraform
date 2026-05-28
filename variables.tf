# =============================================================
# variables.tf
# =============================================================

variable "aws_region" {
  description = "Regió AWS on desplegar la infraestructura"
  type        = string
  default     = "eu-east-1"
}

variable "project_name" {
  description = "Nom del projecte (s'usa com a prefix per als recursos)"
  type        = string
  default     = "practica-tf"
}

variable "vpc_cidr" {
  description = "Bloc CIDR de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs per a les subnets públiques (una per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs per a les subnets privades (una per AZ)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "instance_type" {
  description = "Tipus d'instància EC2"
  type        = string
  default     = "t3.micro"
}

variable "ssh_public_key" {
  description = "Clau pública SSH per accedir a les instàncies"
  type        = string
  # Afegeix la teua clau pública aquí o passa-la via terraform.tfvars
  # Exemple: ssh-rsa AAAA... user@host
}

variable "domain_name" {
  description = "Nom de domini per al certificat SSL (ha d'existir a Route 53)"
  type        = string
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
