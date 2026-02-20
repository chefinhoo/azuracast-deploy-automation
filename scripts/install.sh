#!/bin/bash
# =========================================================
# Script de instalação automatizada do AzuraCast + Nginx Proxy Manager
# 
# Copyright (c) 2026 Danilo Ramos
# Licensed under MIT License (automation script only)
# 
# This script removes installations of:
# - AzuraCast © AzuraCast Contributors (Apache 2.0)
#   https://www.azuracast.com
# - Nginx Proxy Manager © Jamie Curnow (MIT License)
#   https://nginxproxymanager.com
# - Docker © Docker, Inc. (Apache 2.0)
#   https://www.docker.com
# =========================================================

set -e

echo "[INFO] Atualizando pacotes e instalando dependências..."
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg lsb-release software-properties-common

# -------------------------------
# Docker e Docker Compose Plugin
# -------------------------------
echo "[INFO] Instalando Docker e Docker Compose plugin..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable --now docker
echo "[INFO] Docker instalado com sucesso!"
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
echo "[INFO] Configurando Nginx Proxy Manager..."
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

echo "[INFO] Iniciando Nginx Proxy Manager..."
cd /var/proxy_manager
docker compose up -d

# -------------------------------
# AzuraCast
# -------------------------------
echo "[INFO] Instalando AzuraCast..."
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
    echo "[INFO] Criando docker-compose.override.yml para expor portas..."
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
    echo "[INFO] Atualizando docker-compose.override.yml existente..."
    sed -i "/ports:/a \      - '8080:80'\n      - '8043:443'\n      - '9000-9999:9000-9999'" "$OVERRIDE_FILE"
fi

# Reinicia AzuraCast para aplicar portas
docker compose down
docker compose up -d

# -------------------------------
# Limpeza e mensagem final
# -------------------------------
echo "[INFO] Limpando arquivos temporários..."
cd ~
rm -rf azuracast-deploy-automation

PUBLIC_IP=$(curl -s https://ifconfig.me)

echo "[INFO] Instalação concluída e arquivos temporários removidos."
echo "[INFO] AzuraCast instalado com sucesso!"
echo "HTTP interno: 8080"
echo "HTTPS interno: 8043"
echo "Streaming: 9000-9999"
echo "Acesse via Nginx Proxy Manager usando seu domínio."

# -------------------------------
# Próximos passos
# -------------------------------
echo -e "\n===================================================="
echo "PRÓXIMOS PASSOS RECOMENDADOS:"
echo ""
echo "1️⃣ Acesse o Nginx Proxy Manager GUI:"
echo "   http://$PUBLIC_IP:81"
echo ""
echo "2️⃣ Crie um Proxy Host:"
echo "   - Domain Names: seudominio.com"
echo "   - Scheme: https"
echo "   - Forward Hostname/IP: localhost"
echo "   - Forward Port: 8043 (HTTPS AzuraCast)"
echo "   - Enable Websockets: ✅"
echo ""
echo "3️⃣ Aba SSL:"
echo "   - Request a new SSL certificate"
echo "   - Force SSL"
echo "   - Habilite HTTP/2"
echo "   - Informe seu e-mail e aceite os termos Let’s Encrypt"
echo ""
echo "4️⃣ Para outras aplicações (WordPress, Node, etc.):"
echo "   - Use portas internas na faixa 8000-8999"
echo "   - Crie Proxy Hosts apontando para essas portas"
echo ""
echo "===================================================="
