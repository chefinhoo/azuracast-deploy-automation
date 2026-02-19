#!/bin/bash
# =========================================================
# Script de instalação AzuraCast + Nginx Proxy Manager
# Multi-site compatível, ajusta automaticamente portas
# 
# Copyright (c) 2026 Danilo Ramos
# Licensed under MIT License (automation script only)
# 
# This script installs the following third-party software:
# - AzuraCast © AzuraCast Contributors (Apache 2.0)
#   https://www.azuracast.com
# - Nginx Proxy Manager © Jamie Curnow (MIT License)
#   https://nginxproxymanager.com
# - Docker © Docker, Inc. (Apache 2.0)
#   https://www.docker.com
# 
# All third-party software is subject to their own licenses.
# =========================================================

set -e

echo "[INFO] Verificando se está rodando como root..."
if [[ $EUID -ne 0 ]]; then
   echo "Este script precisa ser executado como root." 
   exit 1
fi

echo "[INFO] Criando diretórios de instalação..."
mkdir -p /var/azuracast
mkdir -p /var/proxy_manager

# ========================
# Instala Docker e Compose
# ========================
echo "[INFO] Instalando Docker e Docker Compose..."
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg lsb-release

mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
> /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable --now docker

# ========================
# Instala AzuraCast
# ========================
echo "[INFO] Instalando AzuraCast..."

cd /var/azuracast

# Baixa script oficial
curl -fsSL https://raw.githubusercontent.com/AzuraCast/AzuraCast/main/docker.sh -o docker.sh
chmod +x docker.sh

# ========================
# Configura portas antes da instalação
# ========================
cat > .env <<EOL
# Portas da interface web
AZURACAST_HTTP_PORT=10080
AZURACAST_HTTPS_PORT=10443
# Porta base de streaming (Icecast/Shoutcast)
AZURACAST_ICECAST_PORT=9000
EOL

echo "[INFO] Instalando AzuraCast com portas customizadas..."
yes | ./docker.sh install

echo "[INFO] Reiniciando AzuraCast para aplicar portas..."
docker compose down || true
docker compose up -d

# ========================
# Instala Nginx Proxy Manager
# ========================
echo "[INFO] Instalando Nginx Proxy Manager..."

cd /var/proxy_manager

cat > docker-compose.yml <<EOL
version: "3"
services:
  app:
    image: jc21/nginx-proxy-manager:latest
    restart: unless-stopped
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
    depends_on:
      - db
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
  db:
    image: mariadb:10.11
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: "npm"
      MYSQL_DATABASE: "npm"
      MYSQL_USER: "npm"
      MYSQL_PASSWORD: "npm"
    volumes:
      - ./data/mysql:/var/lib/mysql
EOL

docker compose up -d

# ========================
# Finalização
# ========================
echo "[INFO] AzuraCast instalado com sucesso!"
echo "HTTP: 10080, HTTPS: 10443, STREAM: 9000+"
echo "Configure um Proxy Host no Nginx Proxy Manager apontando para essas portas."

cat <<EOL

Próximos passos recomendados:

Acesse o Nginx Proxy Manager GUI:
http://<IP_DO_SERVIDOR>:81

Crie um Proxy Host:

Domain Names: seu domínio (ex: azura.daniloramos.dev.br)
Scheme: https
Forward Hostname/IP: IP público do servidor
Forward Port: 10443 (HTTPS do AzuraCast)
Enable Websockets: ✅

SSL Tab:
Request a new SSL certificate
Force SSL
HTTP/2 Support
Informe seu e-mail e aceite os termos Let’s Encrypt

Acesse o AzuraCast pelo seu domínio:
https://azura.seudominio.com

As rádios estarão disponíveis em streaming a partir da porta 9000.

EOL
