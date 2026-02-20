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
# - AzuraCast © AzuraCast Contributors (Apache 2.0)
#   https://www.azuracast.com
# - Nginx Proxy Manager © Jamie Curnow (MIT License)
#   https://nginxproxymanager.com
# - Docker © Docker, Inc. (Apache 2.0)
#   https://www.docker.com
# =========================================================

set -e

echo "[INFO] Atualizando pacotes e instalando dependências... / Updating packages and installing dependencies..."
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg lsb-release software-properties-common

# -------------------------------
# Docker e Docker Compose Plugin
# -------------------------------
echo "[INFO] Instalando Docker e Docker Compose plugin... / Installing Docker and Docker Compose plugin..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable --now docker
echo "[INFO] Docker instalado com sucesso! / Docker installed successfully!"
docker version

# -------------------------------
# Diretórios e permissões
# -------------------------------
mkdir -p /var/proxy_manager
mkdir -p /var/azuracast

chown -R root:root /var/proxy_manager /var/azuracast

# -------------------------------
# Nginx Proxy Manager
# -------------------------------
echo "[INFO] Configurando Nginx Proxy Manager... / Configuring Nginx Proxy Manager..."
cat > /var/proxy_manager/docker-compose.yml <<EOL
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
      MYSQL_ROOT_PASSWORD: 'npm'
      MYSQL_DATABASE: 'npm'
      MYSQL_USER: 'npm'
      MYSQL_PASSWORD: 'npm'
    volumes:
      - ./data/mysql:/var/lib/mysql
EOL

echo "[INFO] Iniciando Nginx Proxy Manager... / Starting Nginx Proxy Manager..."
cd /var/proxy_manager
docker compose up -d

# -------------------------------
# AzuraCast
# -------------------------------
echo "[INFO] Instalando AzuraCast... / Installing AzuraCast..."
cd /var/azuracast

# Baixa o script oficial
curl -fsSL https://raw.githubusercontent.com/AzuraCast/AzuraCast/main/docker.sh -o docker.sh
chmod +x docker.sh

# Define portas internas
export AZURACAST_HTTP_PORT=8080
export AZURACAST_HTTPS_PORT=8043
export AZURACAST_STATION_PORT=9000
export AZURACAST_STATION_PORT_END=9999

# Instalação não interativa
yes '' | ./docker.sh install

# -------------------------------
# Adiciona portas HTTP/HTTPS e streaming no docker-compose
# -------------------------------
OVERRIDE_FILE="docker-compose.override.yml"
if [ ! -f "$OVERRIDE_FILE" ]; then
    echo "[INFO] Criando docker-compose.override.yml para expor portas... / Creating docker-compose.override.yml to expose ports..."
    cat > "$OVERRIDE_FILE" <<EOL
version: '3'
services:
  web:
    ports:
      - "8080:80"       # HTTP AzuraCast
      - "8043:443"      # HTTPS AzuraCast
      - "9000-9999:9000-9999" # Streaming
EOL
else
    echo "[INFO] Atualizando docker-compose.override.yml existente... / Updating existing docker-compose.override.yml..."
    sed -i "/ports:/a \      - '8080:80'\n      - '8043:443'\n      - '9000-9999:9000-9999'" "$OVERRIDE_FILE"
fi

# Reinicia AzuraCast para aplicar portas
docker compose down
docker compose up -d

# -------------------------------
# Limpeza e mensagem final
# -------------------------------
echo "[INFO] Limpando arquivos temporários... / Cleaning temporary files..."
cd ~
rm -rf azuracast-deploy-automation

PUBLIC_IP=$(curl -s https://ifconfig.me)

echo "[INFO] Instalação concluída e arquivos temporários removidos. / Installation completed and temporary files removed."
echo "[INFO] AzuraCast instalado com sucesso! / AzuraCast installed successfully!"
echo "HTTP interno / Internal HTTP: 8080"
echo "HTTPS interno / Internal HTTPS: 8043"
echo "Streaming: 9000-9999"
echo "Acesse via Nginx Proxy Manager usando seu domínio. / Access via Nginx Proxy Manager using your domain."

# -------------------------------
# Próximos passos
# -------------------------------
echo -e "\n===================================================="
echo "PRÓXIMOS PASSOS RECOMENDADOS / RECOMMENDED NEXT STEPS:"
echo ""
echo "1️⃣ Acesse o painel do Nginx Proxy Manager / Open Nginx Proxy Manager GUI:"
echo "   http://$PUBLIC_IP:81"
echo ""
echo "2️⃣ Crie um Proxy Host / Create a Proxy Host:"
echo "   - Domain Names: seudominio.com (or yourdomain.com)"
echo "   - Scheme: https"
echo "   - Forward Hostname/IP: localhost"
echo "   - Forward Port: 8043 (HTTPS AzuraCast)"
echo "   - Enable Websockets: ✅"
echo ""
echo "3️⃣ Aba SSL / SSL tab:"
echo "   - Request a new SSL certificate"
echo "   - Force SSL"
echo "   - Habilite HTTP/2 / Enable HTTP/2"
echo "   - Informe seu e-mail e aceite os termos Let’s Encrypt / Enter your email and accept Let’s Encrypt terms"
echo ""
echo "4️⃣ Para outras aplicações (WordPress, Node, etc.) / For other applications (WordPress, Node, etc.):"
echo "   - Use portas internas na faixa 8000-8999 / Use internal ports in the 8000-8999 range"
echo "   - Crie Proxy Hosts apontando para essas portas / Create Proxy Hosts pointing to those ports"
echo ""
echo "===================================================="
