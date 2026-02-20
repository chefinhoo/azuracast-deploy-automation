#!/bin/bash
# =========================================================
# Script de instalação automatizada do AzuraCast + Nginx Proxy Manager
# Automated installation script for AzuraCast + Nginx Proxy Manager
# 
# Copyright (c) 2026 Danilo Ramos
# Licensed under MIT License (automation script only)
# Licenciado sob MIT (apenas script de automação)
# 
# This script installs and configures:
# Este script instala e configura:
# - AzuraCast (Apache 2.0)
#   https://www.azuracast.com
# - Nginx Proxy Manager (MIT)
#   https://nginxproxymanager.com
# - Docker (Apache 2.0)
#   https://www.docker.com
# =========================================================

set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "[ERRO] Execute como root."
  exit 1
fi

# ---------------------------------------------------------
# Dependências
# ---------------------------------------------------------
echo "[INFO] Atualizando pacotes..."
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg lsb-release software-properties-common

# ---------------------------------------------------------
# Docker
# ---------------------------------------------------------
echo "[INFO] Instalando Docker..."
mkdir -p /etc/apt/keyrings

if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
fi

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
> /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable --now docker

# ---------------------------------------------------------
# Diretórios
# ---------------------------------------------------------
mkdir -p /var/proxy_manager
mkdir -p /var/azuracast
mkdir -p /var/www

# ---------------------------------------------------------
# Nginx Proxy Manager
# ---------------------------------------------------------
echo "[INFO] Subindo Nginx Proxy Manager..."

cat > /var/proxy_manager/docker-compose.yml <<'EOL'
version: "3"
services:
  app:
    image: jc21/nginx-proxy-manager:latest
    restart: always
    ports:
      - "81:81"
      - "80:80"
      - "443:443"
    environment:
      DB_MYSQL_HOST: "db"
      DB_MYSQL_PORT: 3306
      DB_MYSQL_USER: "npm"
      DB_MYSQL_PASSWORD: "npm"
      DB_MYSQL_NAME: "npm"
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt

  db:
    image: mariadb:10.11
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: "npm"
      MYSQL_DATABASE: "npm"
      MYSQL_USER: "npm"
      MYSQL_PASSWORD: "npm"
    volumes:
      - ./data/mysql:/var/lib/mysql
EOL

cd /var/proxy_manager
docker compose up -d

# ---------------------------------------------------------
# AzuraCast
# ---------------------------------------------------------
echo "[INFO] Instalando AzuraCast..."

cd /var/azuracast

curl -fsSL https://raw.githubusercontent.com/AzuraCast/AzuraCast/main/docker.sh -o docker.sh
chmod +x docker.sh

export AZURACAST_HTTP_PORT=8080
export AZURACAST_HTTPS_PORT=8043
export AZURACAST_STATION_PORT=9000
export AZURACAST_STATION_PORT_END=9999

yes '' | ./docker.sh install

# ---------------------------------------------------------
# Override (somente se não existir)
# ---------------------------------------------------------
if [ ! -f docker-compose.override.yml ]; then
cat > docker-compose.override.yml <<'EOL'
version: "3.8"
services:
  web:
    ports:
      - "8080:80"
      - "8043:443"
      - "9000-9999:9000-9999"
EOL
fi

docker compose down
docker compose up -d

# ---------------------------------------------------------
# Container nginx para sites estáticos
# ---------------------------------------------------------
echo "[INFO] Preparando container de site estático..."

if ! docker ps -a --format '{{.Names}}' | grep -q '^site-estatico$'; then

  docker run -d \
    --name site-estatico \
    --restart unless-stopped \
    -p 8085:80 \
    -v /var/www:/var/www \
    nginx:alpine

else
  docker start site-estatico >/dev/null || true
fi

# ---------------------------------------------------------
# Criação de vhost
# ---------------------------------------------------------
echo
echo "===================================================="
echo "CONFIGURAÇÃO DE SITE ESTÁTICO"
echo "===================================================="
echo

read -rp "👉 Informe o domínio (ex: seudominio.com): " DOMINIO

if [ -z "$DOMINIO" ]; then
  echo "[ERRO] Domínio não informado."
  exit 1
fi

echo "[INFO] Criando estrutura /var/www/$DOMINIO"

mkdir -p /var/www/$DOMINIO

cat > /var/www/$DOMINIO/index.html <<EOF
<h1>$DOMINIO funcionando</h1>
<p>Site estático ativo.</p>
EOF

echo "[INFO] Criando vhost no container..."

docker exec site-estatico sh -c "cat > /etc/nginx/conf.d/$DOMINIO.conf <<EOF
server {
    listen 80 default_server;
    server_name _;
    return 444;
}

server {
    listen 80;
    server_name $DOMINIO www.$DOMINIO;

    root /var/www/$DOMINIO;
    index index.html;

    location / {
        try_files \\$uri \\$uri/ =404;
    }
}
EOF"

docker exec site-estatico nginx -t
docker exec site-estatico nginx -s reload

# ---------------------------------------------------------
# Final
# ---------------------------------------------------------
PUBLIC_IP=$(curl -s https://ifconfig.me || true)

echo
echo "===================================================="
echo "FINALIZADO"
echo "===================================================="
echo
echo "Site estático criado: $DOMINIO"
echo
echo "✔ Teste local do site estático:"
echo "  curl -H \"Host: $DOMINIO\" http://127.0.0.1:8085"
echo
echo "✔ Painel do Nginx Proxy Manager:"
echo "  http://$PUBLIC_IP:81"
echo
echo "Crie um Proxy Host para o site estático:"
echo "  Domain Names : $DOMINIO"
echo "  Scheme       : http"
echo "  Forward Host : $PUBLIC_IP"
echo "  Forward Port : 8085"
echo
echo "----------------------------------------------------"
echo "INSTRUÇÕES DO AZURACAST"
echo "----------------------------------------------------"
echo
echo "Acesso direto (somente para configuração inicial):"
echo "  http://$PUBLIC_IP:8080"
echo
echo "No Nginx Proxy Manager, crie um Proxy Host para o AzuraCast:"
echo "  Domain Names : azura.seudominio.com"
echo "  Scheme       : http"
echo "  Forward Host : $PUBLIC_IP"
echo "  Forward Port : 8080"
echo
echo "Depois gere o SSL e ative 'Force SSL'."
echo
echo "Portas configuradas no AzuraCast:"
echo "  Painel HTTP  : 8080"
echo "  Painel HTTPS : 8043 (uso interno)"
echo "  Estações     : 9000 a 9999"
echo
echo "===================================================="
