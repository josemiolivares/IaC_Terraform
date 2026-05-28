#!/bin/bash
# =============================================================
# user_data.sh - Script d'inici per a les instàncies EC2
# Variables injectades per Terraform:
#   ${project_name}  - Nom del projecte
#   ${az_index}      - Índex de la zona de disponibilitat (1 o 2)
# =============================================================

set -euo pipefail
exec > /var/log/user-data.log 2>&1

echo "=== Iniciant configuració del servidor web ==="
echo "Projecte: ${project_name}"
echo "AZ Index: ${az_index}"
echo "Data: $(date)"

# Actualitzar el sistema
dnf update -y

# Instal·lar Nginx
dnf install -y nginx

# Obtenir metadades de la instància (IMDSv2)
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/local-ipv4)

# Crear la pàgina web
cat > /usr/share/nginx/html/index.html <<HTML
<!DOCTYPE html>
<html lang="ca">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${project_name} - Servidor Web</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
        }
        .card {
            background: rgba(255,255,255,0.15);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255,255,255,0.3);
            border-radius: 16px;
            padding: 40px 48px;
            max-width: 520px;
            width: 90%;
            text-align: center;
        }
        h1 { font-size: 2rem; margin-bottom: 8px; }
        .subtitle { opacity: 0.85; margin-bottom: 32px; font-size: 1.1rem; }
        .badge {
            display: inline-block;
            background: rgba(255,255,255,0.25);
            border-radius: 8px;
            padding: 6px 14px;
            font-size: 0.85rem;
            margin: 4px;
        }
        .info-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 12px;
            margin-top: 24px;
        }
        .info-item {
            background: rgba(0,0,0,0.2);
            border-radius: 8px;
            padding: 12px;
        }
        .info-label { font-size: 0.75rem; opacity: 0.75; text-transform: uppercase; letter-spacing: 0.05em; }
        .info-value { font-size: 1rem; font-weight: 600; margin-top: 4px; }
        .https-badge {
            background: #22c55e;
            color: white;
            padding: 4px 10px;
            border-radius: 6px;
            font-size: 0.8rem;
            font-weight: 700;
            margin-bottom: 20px;
            display: inline-block;
        }
    </style>
</head>
<body>
    <div class="card">
        <div class="https-badge">🔒 HTTPS ACTIU</div>
        <h1>🚀 ${project_name}</h1>
        <p class="subtitle">Alta Disponibilitat amb 2 Zones de Disponibilitat</p>
        <span class="badge">⚡ AWS EC2</span>
        <span class="badge">🌍 ALB</span>
        <span class="badge">🔐 TLS 1.3</span>
        <div class="info-grid">
            <div class="info-item">
                <div class="info-label">Instància</div>
                <div class="info-value" style="font-size:0.85rem">$INSTANCE_ID</div>
            </div>
            <div class="info-item">
                <div class="info-label">Zona AZ</div>
                <div class="info-value">$AZ</div>
            </div>
            <div class="info-item">
                <div class="info-label">IP Privada</div>
                <div class="info-value">$PRIVATE_IP</div>
            </div>
            <div class="info-item">
                <div class="info-label">Servidor #</div>
                <div class="info-value">${az_index}</div>
            </div>
        </div>
    </div>
</body>
</html>
HTML

# Pàgina de health check
cat > /usr/share/nginx/html/health <<'HEALTH'
OK
HEALTH

# Configurar Nginx
cat > /etc/nginx/conf.d/app.conf <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # Health check del ALB
    location /health {
        access_log off;
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }

    location / {
        try_files $uri $uri/ =404;
    }

    # Headers de seguretat (el TLS el gestiona el ALB)
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";
}
NGINX

# Habilitar i iniciar Nginx
systemctl enable nginx
systemctl start nginx

echo "=== Configuració completada correctament ==="
