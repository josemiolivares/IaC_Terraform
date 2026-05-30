#!/bin/bash
###############################################################
# user_data.sh.tpl — Script d'inicialització per a instàncies
# WordPress. S'executa una vegada en el primer arrencada.
# Variables injectades per Terraform templatefile():
#   efs_dns_name, db_host, db_name, db_user, db_pass,
#   wp_title, wp_admin, wp_admin_pass, wp_admin_email
###############################################################

set -euxo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Iniciant configuració WordPress ==="

# ─── Actualitzar el sistema ───────────────────────────────────
dnf update -y

# ─── Instal·lar Apache + PHP 8.2 + NFS client ─────────────────
dnf install -y \
  httpd \
  php8.2 \
  php8.2-mysqlnd \
  php8.2-fpm \
  php8.2-gd \
  php8.2-xml \
  php8.2-mbstring \
  php8.2-curl \
  php8.2-zip \
  php8.2-intl \
  nfs-utils \
  amazon-cloudwatch-agent

# ─── Muntar EFS ───────────────────────────────────────────────
EFS_DNS="${efs_dns_name}"
MOUNT_POINT="/var/www/html"

mkdir -p "$MOUNT_POINT"

# Afegir a /etc/fstab per a muntatge persistent
echo "$EFS_DNS:/ $MOUNT_POINT efs defaults,_netdev,tls 0 0" >> /etc/fstab

# Muntar amb reintents (EFS pot trigar uns segons en estar disponible)
for i in {1..10}; do
  mount -a && break
  echo "Reintent $i de muntar EFS..."
  sleep 10
done

# ─── Instal·lar WordPress (només si no existeix) ──────────────
WP_CLI="/usr/local/bin/wp"
WP_PATH="$MOUNT_POINT"

if [ ! -f "$WP_PATH/wp-config.php" ]; then
  echo "Primera instància: instal·lant WordPress..."

  # Descarregar WP-CLI
  curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x wp-cli.phar
  mv wp-cli.phar "$WP_CLI"

  # Descarregar WordPress al muntatge EFS
  wp --allow-root --path="$WP_PATH" core download --locale=ca

  # Configurar wp-config.php
  wp --allow-root --path="$WP_PATH" config create \
    --dbname="${db_name}" \
    --dbuser="${db_user}" \
    --dbpass="${db_pass}" \
    --dbhost="${db_host}" \
    --dbcharset="utf8mb4"

  # Instal·lar WordPress
  wp --allow-root --path="$WP_PATH" core install \
    --url="http://localhost" \
    --title="${wp_title}" \
    --admin_user="${wp_admin}" \
    --admin_password="${wp_admin_pass}" \
    --admin_email="${wp_admin_email}" \
    --skip-email

  # Permissos correctes
  chown -R apache:apache "$WP_PATH"
  find "$WP_PATH" -type d -exec chmod 755 {} \;
  find "$WP_PATH" -type f -exec chmod 644 {} \;

  echo "WordPress instal·lat correctament."
else
  echo "WordPress ja instal·lat (altra instància). Omitint instal·lació."
  chown -R apache:apache "$WP_PATH"
fi

# ─── Configurar Apache ────────────────────────────────────────
cat > /etc/httpd/conf.d/wordpress.conf << 'APACHECONF'
<VirtualHost *:80>
    DocumentRoot /var/www/html
    <Directory /var/www/html>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    # Health check de l'ALB
    <Location /wp-login.php>
        Require all granted
    </Location>
</VirtualHost>
APACHECONF

# Activar mod_rewrite per als permalinks de WordPress
sed -i 's/^#LoadModule rewrite_module/LoadModule rewrite_module/' \
  /etc/httpd/conf.modules.d/00-base.conf || true

# ─── Configurar PHP-FPM ───────────────────────────────────────
sed -i 's/^listen = .*/listen = \/run\/php-fpm\/www.sock/' \
  /etc/php-fpm.d/www.conf
sed -i 's/^user = .*/user = apache/' /etc/php-fpm.d/www.conf
sed -i 's/^group = .*/group = apache/' /etc/php-fpm.d/www.conf

# ─── Iniciar i habilitar serveis ─────────────────────────────
systemctl enable --now php-fpm
systemctl enable --now httpd

# ─── CloudWatch Agent (mètriques bàsiques) ───────────────────
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWAGENT'
{
  "metrics": {
    "append_dimensions": {
      "AutoScalingGroupName": "$${aws:AutoScalingGroupName}",
      "InstanceId": "$${aws:InstanceId}"
    },
    "metrics_collected": {
      "cpu": { "measurement": ["cpu_usage_idle", "cpu_usage_user"], "metrics_collection_interval": 60 },
      "mem": { "measurement": ["mem_used_percent"], "metrics_collection_interval": 60 },
      "disk": { "measurement": ["disk_used_percent"], "resources": ["/"], "metrics_collection_interval": 60 }
    }
  }
}
CWAGENT

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

echo "=== Configuració WordPress completada ==="
