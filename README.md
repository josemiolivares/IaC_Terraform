# WordPress HA a AWS — Terraform

Infraestructura d'alta disponibilitat per a WordPress sobre AWS, replicant les instàncies EC2 en **dues zones de disponibilitat** (AZ).

## Arquitectura

```
Internet
   │
   ▼
Internet Gateway
   │
   ▼
ALB (Application Load Balancer)  ──  subnets públiques (AZ-a, AZ-b)
   │
   ├──► EC2 WordPress (AZ-a, subnet privada)  ─┐
   │                                            ├─► EFS (compartit entre instàncies)
   └──► EC2 WordPress (AZ-b, subnet privada)  ─┘
              │
              ▼  (SQL)
         RDS MySQL Multi-AZ
              │
         NAT Gateway (eixida a Internet per a actualitzacions)
```

### Components

| Component | Descripció |
|-----------|------------|
| **VPC** | `10.0.0.0/16` amb 2 subnets públiques i 2 privades |
| **Internet Gateway** | Punt d'entrada/sortida públic |
| **NAT Gateway** | Permet que les EC2 privades accedeixin a Internet |
| **ALB** | Balanceja tràfic HTTP entre les instàncies de les 2 AZ |
| **Auto Scaling Group** | Manté mínim 2 instàncies (1 per AZ), escala fins a 6 |
| **Launch Template** | Configura les EC2 amb WordPress + EFS muntat |
| **EC2 T3** | Instàncies WordPress en subnets privades |
| **RDS MySQL 8.0** | Multi-AZ, còpies de seguretat 7 dies |
| **EFS** | Sistema de fitxers compartit (wp-content, plugins, temes) |
| **CloudWatch** | Alarmes CPU (RDS) i errors 5xx (ALB) |
| **IAM** | Rol EC2 amb SSM (accés sense SSH) i CloudWatch Agent |

## Requisits previs

- [Terraform](https://www.terraform.io/downloads) >= 1.6.0
- [AWS CLI](https://aws.amazon.com/cli/) configurat (`aws configure`)
- Permisos IAM suficients (EC2, RDS, EFS, VPC, ALB, IAM, CloudWatch)

## Desplegament

### 1. Clonar i configurar

```bash
git clone <repo>
cd terraform-wordpress

cp terraform.tfvars.example terraform.tfvars
# Edita terraform.tfvars amb les teves dades reals
nano terraform.tfvars
```

### 2. Inicialitzar Terraform

```bash
terraform init
```

### 3. Revisar el pla

```bash
terraform plan -out=tfplan
```

### 4. Aplicar

```bash
terraform apply tfplan
```

La instal·lació tarda ~15-20 minuts (principalment l'RDS Multi-AZ).

### 5. Accedir a WordPress

```bash
terraform output wordpress_url
```

## Estructura de fitxers

```
terraform-wordpress/
├── main.tf                  # Tots els recursos AWS
├── variables.tf             # Definició de variables
├── outputs.tf               # Valors exportats
├── user_data.sh.tpl         # Script d'inicialització EC2
├── terraform.tfvars.example # Exemple de configuració
└── README.md
```

## Seguretat

- Les instàncies EC2 estan en **subnets privades** (sense IP pública)
- Accés SSH substituït per **AWS Systems Manager Session Manager**
- IMDSv2 obligatori a totes les instàncies
- RDS i EFS xifrats en repòs
- Security Groups mínims (principi de mínim privilegi)

> ⚠️ **Important**: No commitegis `terraform.tfvars` al control de versions. Afegeix-lo al `.gitignore`.

## Eliminació

```bash
# Desactivar protecció RDS si estava activada
terraform apply -var="db_deletion_protection=false"

terraform destroy
```

## Consideracions de cost (estimació us-east-1)

| Recurs | Estimació mensual |
|--------|------------------|
| 2× EC2 t3.small | ~$30 |
| RDS db.t3.micro Multi-AZ | ~$30 |
| ALB | ~$20 |
| NAT Gateway | ~$35 |
| EFS (20 GB) | ~$6 |
| **Total estimat** | **~$121/mes** |
