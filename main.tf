# =============================================================
# main.tf - Infraestructura AWS amb HA en 2 AZs i HTTPS
# =============================================================

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# -------------------------------------------------------------
# DATA SOURCES
# -------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}


# -------------------------------------------------------------
# VPC
# -------------------------------------------------------------

resource "aws_vpc" "main" {
 
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

# -------------------------------------------------------------
# INTERNET GATEWAY
# -------------------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

# -------------------------------------------------------------
# SUBNETS PÚBLIQUES (una per AZ)
# -------------------------------------------------------------

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
    AZ   = data.aws_availability_zones.available.names[count.index]
  })
}

# -------------------------------------------------------------
# SUBNETS PRIVADES (una per AZ)
# -------------------------------------------------------------

resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
    AZ   = data.aws_availability_zones.available.names[count.index]
  })
}

# -------------------------------------------------------------
# ELASTIC IPs per NAT Gateways
# -------------------------------------------------------------

resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-eip-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# -------------------------------------------------------------
# NAT GATEWAYS (un per AZ per a HA real)
# -------------------------------------------------------------

resource "aws_nat_gateway" "main" {
  count = 2

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-nat-gw-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# -------------------------------------------------------------
# TAULES DE RUTES PÚBLIQUES
# -------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-rt-public"
  })
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# -------------------------------------------------------------
# TAULES DE RUTES PRIVADES (una per AZ)
# -------------------------------------------------------------

resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-rt-private-${count.index + 1}"
  })
}

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# -------------------------------------------------------------
# SECURITY GROUP - ALB
# -------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-sg-alb"
  description = "Permet HTTP (redireccio) i HTTPS des d_internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP des d_internet (redireccio a HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS des d_internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Tot el trafic de sortida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-sg-alb"
  })
}

# -------------------------------------------------------------
# SECURITY GROUP - Instàncies EC2
# -------------------------------------------------------------

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-sg-ec2"
  description = "Permet trafic HTTP des del ALB i SSH des de bastio"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP des del ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "SSH des de la VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Tot el trafic de sortida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-sg-ec2"
  })
}

# -------------------------------------------------------------
# KEY PAIR
# -------------------------------------------------------------

resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-key"
  public_key = var.ssh_public_key

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-key"
  })
}

# -------------------------------------------------------------
# INSTÀNCIES EC2 (una per AZ, en subxarxa privada)
# -------------------------------------------------------------

resource "aws_instance" "web" {
  count = 2
  ami           = "ami-00e801948462f718a"
 # instance_type = "t3.micro"
 # ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.main.key_name
  subnet_id              = aws_subnet.private[count.index].id
  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    project_name = var.project_name
    az_index     = count.index + 1
  }))

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-web-${count.index + 1}"
    AZ   = data.aws_availability_zones.available.names[count.index]
    Role = "webserver"
  })
}

# -------------------------------------------------------------
# ACM - Certificat SSL/TLS
# (Opció A: certificat autogestionat importat)
# (Opció B: certificat AWS Certificate Manager - recomanat)
# -------------------------------------------------------------

# NOTA: Si tens un domini propi, descomenta el bloc següent i
# ajusta la variable domain_name. ACM validarà via DNS.
# Si no tens domini, utilitza un certificat autosignat (veure README).

resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-cert"
  })
}

# Validació DNS del certificat (requereix que gestionis el DNS)
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]

  timeouts {
    create = "10m"
  }
}

# -------------------------------------------------------------
# ROUTE 53 (si uses hosted zone propia)
# -------------------------------------------------------------

data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

resource "aws_route53_record" "alb" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "alb_www" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# -------------------------------------------------------------
# APPLICATION LOAD BALANCER
# -------------------------------------------------------------

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-alb"
  })
}

# -------------------------------------------------------------
# TARGET GROUP
# -------------------------------------------------------------

resource "aws_lb_target_group" "web" {
  name     = "${var.project_name}-tg-web"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200-299"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-tg-web"
  })
}

resource "aws_lb_target_group_attachment" "web" {
  count = 2

  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}

# -------------------------------------------------------------
# LISTENER HTTP → redirecció a HTTPS
# -------------------------------------------------------------

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-listener-http"
  })
}

# -------------------------------------------------------------
# LISTENER HTTPS
# -------------------------------------------------------------

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.main.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-listener-https"
  })
}
