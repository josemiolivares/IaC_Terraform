###############################################################
# variables.tf — Paràmetres configurables
###############################################################

variable "aws_region" {
  description = "Regió AWS on desplegar la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nom del projecte (prefix per a tots els recursos)"
  type        = string
  default     = "wordpress-ha"
}

variable "environment" {
  description = "Entorn (prod, staging, dev)"
  type        = string
  default     = "prod"
}

# ─── Xarxa ────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs de les subnets públiques (una per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs de les subnets privades (una per AZ)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

# ─── EC2 / Auto Scaling ───────────────────────────────────────

variable "ec2_instance_type" {
  description = "Tipus d'instància EC2 per a WordPress"
  type        = string
  default     = "t3.small"
}

variable "asg_min_size" {
  description = "Nombre mínim d'instàncies a l'ASG"
  type        = number
  default     = 2  # Mínim 1 per AZ per a HA
}

variable "asg_max_size" {
  description = "Nombre màxim d'instàncies a l'ASG"
  type        = number
  default     = 6
}

variable "asg_desired_capacity" {
  description = "Nombre desitjat d'instàncies a l'ASG"
  type        = number
  default     = 2
}

# ─── RDS ─────────────────────────────────────────────────────

variable "db_instance_class" {
  description = "Classe d'instància RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Emmagatzematge inicial RDS (GB)"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Nom de la base de dades WordPress"
  type        = string
  default     = "wordpress"
}

variable "db_username" {
  description = "Usuari administrador de la BD"
  type        = string
  default     = "wpuser"
  sensitive   = true
}

variable "db_password" {
  description = "Contrasenya de la BD (usar AWS Secrets Manager en producció)"
  type        = string
  sensitive   = true
}

variable "db_deletion_protection" {
  description = "Activa protecció contra eliminació de la BD"
  type        = bool
  default     = true
}

# ─── WordPress ────────────────────────────────────────────────

variable "wp_site_title" {
  description = "Títol del lloc WordPress"
  type        = string
  default     = "El meu WordPress"
}

variable "wp_admin_user" {
  description = "Usuari administrador de WordPress"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "wp_admin_password" {
  description = "Contrasenya de l'administrador de WordPress"
  type        = string
  sensitive   = true
}

variable "wp_admin_email" {
  description = "Email de l'administrador de WordPress"
  type        = string
}
