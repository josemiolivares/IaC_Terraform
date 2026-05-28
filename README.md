# Pràctica Terraform AWS — HTTPS + Alta Disponibilitat (2 AZs)

## Arquitectura

```
Internet
    │
    ▼
┌──────────────────────────────────────────┐
│         Application Load Balancer         │
│    (Port 80 → redirect 301 a HTTPS)       │
│    (Port 443 → TLS 1.3, cert ACM)         │
└──────────┬────────────────────┬──────────┘
           │                    │
     AZ-1 (eu-west-1a)    AZ-2 (eu-west-1b)
           │                    │
    ┌──────▼──────┐      ┌──────▼──────┐
    │  Subnet Pub │      │  Subnet Pub │
    │  10.0.1.0/24│      │  10.0.2.0/24│
    │  NAT GW #1  │      │  NAT GW #2  │
    └──────┬──────┘      └──────┬──────┘
           │                    │
    ┌──────▼──────┐      ┌──────▼──────┐
    │ Subnet Priv │      │ Subnet Priv │
    │ 10.0.11.0/24│      │10.0.12.0/24 │
    │  EC2 Web #1 │      │  EC2 Web #2 │
    └─────────────┘      └─────────────┘
```

## Recursos desplegats

| Recurs | Quantitat | Descripció |
|---|---|---|
| VPC | 1 | 10.0.0.0/16 |
| Subnets públiques | 2 | Una per AZ, amb IGW |
| Subnets privades | 2 | Una per AZ, amb NAT GW |
| Internet Gateway | 1 | Accés públic |
| NAT Gateway | 2 | Un per AZ (HA real) |
| Elastic IP | 2 | Per als NAT GWs |
| EC2 (Amazon Linux 2023) | 2 | Una per AZ, en subxarxa privada |
| Application Load Balancer | 1 | Multi-AZ, HTTPS |
| Target Group | 1 | Health check configurat |
| Listener HTTP (80) | 1 | Redirecció 301 → HTTPS |
| Listener HTTPS (443) | 1 | TLS 1.3, certificat ACM |
| Certificat ACM | 1 | Validat per DNS |
| Route 53 Records | 3 | A (apex), A (www), CNAME validació cert |
| Security Groups | 2 | Per ALB i per EC2 |
| Key Pair | 1 | Accés SSH |

## Requisits previs

1. **AWS CLI** configurat (`aws configure`)
2. **Terraform** >= 1.3.0
3. **Domini** registrat amb **Hosted Zone a Route 53**
4. **Clau SSH** generada localment

## Configuració ràpida

### 1. Clona / copia el projecte

```bash
git clone <repo>
cd practica-terraform-aws
```

### 2. Genera una clau SSH (si no en tens)

```bash
ssh-keygen -t ed25519 -C "terraform-practica" -f ~/.ssh/terraform_practica
```

### 3. Crea el fitxer `terraform.tfvars`

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edita `terraform.tfvars` i omple:
- `ssh_public_key` → contingut de `~/.ssh/terraform_practica.pub`
- `domain_name` → el teu domini (ha d'existir a Route 53)

### 4. Desplega

```bash
terraform init
terraform plan
terraform apply
```

> ⚠️ La validació del certificat ACM pot trigar 5-10 minuts.

### 5. Verifica

Un cop desplegat, comprova:

```bash
# Obtenir la URL
terraform output website_url

# Provar HTTP (ha de redirigir a HTTPS)
curl -I http://<el-teu-domini>

# Provar HTTPS
curl -I https://<el-teu-domini>
```

Cada recàrrega del navegador pot mostrar un servidor diferent (AZ-1 o AZ-2).

## Opció sense domini (certificat autosignat)

Si no tens un domini, pots provar l'arquitectura sense HTTPS i accedir directament al DNS del ALB:

1. Comenta els blocs `aws_acm_certificate`, `aws_acm_certificate_validation`, `aws_route53_*` a `main.tf`
2. Canvia el listener HTTPS per HTTP o usa un certificat autosignat importat
3. Accedeix via: `http://<alb_dns_name>`

## Alta disponibilitat — explicació

| Component | Estratègia HA |
|---|---|
| EC2 | 1 instància per AZ (AZ-1 i AZ-2) |
| NAT Gateway | 1 per AZ (evita single point of failure) |
| ALB | Natiu multi-AZ, distribueix tràfic automàticament |
| Subnets | Públiques i privades en cada AZ |
| Target Group | Health checks actius — exclou instàncies no sanes |

### Flux de tràfic (HTTPS)

```
Usuari
  → Port 80 HTTP → ALB → Redirect 301 → HTTPS
  → Port 443 HTTPS → ALB (termina TLS) → HTTP intern → EC2 (AZ-1 o AZ-2)
```

El TLS es termina al ALB. Les instàncies EC2 reben tràfic HTTP intern (el canal extern ja és xifrat).

## Seguretat

- Les EC2 estan en **subnets privades** (no accessibles des d'internet)
- El **Security Group del ALB** permet 80/443 des de 0.0.0.0/0
- El **Security Group de les EC2** permet port 80 **únicament des del SG del ALB**
- SSH a les EC2 **només des de la VPC** (necessites un bastió o SSM Session Manager)
- Política TLS: `ELBSecurityPolicy-TLS13-1-2-2021-06` (TLS 1.2 mínim, TLS 1.3 preferit)

## Neteja

```bash
terraform destroy
```

## Costos aproximats (us-east-1 / eu-west-1)

| Recurs | Cost mensual estimat |
|---|---|
| 2× EC2 t3.micro | ~$15 |
| 2× NAT Gateway | ~$65 |
| ALB | ~$20 + $0.008/LCU |
| ACM Certificat | Gratuït |
| Route 53 Hosted Zone | $0.50 |
| **Total estimat** | **~$100/mes** |

> 💡 Per reduir costos en entorn de proves: usa 1 NAT Gateway (perd HA a nivell de xarxa privada) canviant `count = 2` a `count = 1` als recursos NAT.
