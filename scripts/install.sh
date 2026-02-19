#!/bin/bash
# install.sh - Instalação automática de AzuraCast + Nginx Proxy Manager
# Autor: Danilo Ramos
# Data: 2026-02-19

set -e

echo "[INFO] Atualizando pacotes e instalando dependências..."
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg lsb-release software-properties-common

# Docker
echo "[INFO] Instalando Docker e Docker Compose plugin..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable --now docker
echo "[INFO] Docker instalado com sucesso!"
docker version

# Criar diretórios
mkdir -p /var/proxy_manager
mkdir -p /var/azuracast

# Ajuste de permissões (Docker precisa poder escrever)
chown -R $USER:$USER /var/proxy_manager /var/azuracast

# -------------------------------
# NGINX PROXY MANAGER
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
    image: mariadb:10.5
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
# AZURACAST
# -------------------------------
echo "[INFO] Instalando AzuraCast..."
cd /var/azuracast

# Baixa o script oficial
curl -fsSL https://raw.githubusercontent.com/AzuraCast/AzuraCast/main/docker.sh -o docker.sh
chmod +x docker.sh

# Define portas não padrão antes da instalação
export AZURACAST_HTTP_PORT=10080
export AZURACAST_HTTPS_PORT=10443

# Instalação não interativa
yes '' | ./docker.sh install

echo "[INFO] AzuraCast instalado com sucesso!"
echo "HTTP: 10080, HTTPS: 10443, STREAM: 9000-9999"

# Informa próximos passos
echo -e "\n===================================================="
echo "PRÓXIMOS PASSOS RECOMENDADOS:"
echo ""
echo "1️⃣ Acesse o Nginx Proxy Manager GUI:"
echo "   http://<IP_DO_SERVIDOR>:81"
echo ""
echo "2️⃣ Crie um Proxy Host:"
echo "   Domain Names: seu domínio (ex: azura.daniloramos.dev.br)"
echo "   Scheme: https"
echo "   Forward Hostname/IP: localhost"
echo "   Forward Port: 10443 (HTTPS do AzuraCast)"
echo "   Enable Websockets: ✅"
echo ""
echo "3️⃣ Aba SSL:"
echo "   - Request a new SSL certificate"
echo "   - Force SSL"
echo "   - Habilite HTTP/2"
echo "   - Informe seu e-mail e aceite os termos Let’s Encrypt"
echo ""
echo "4️⃣ Acesse o AzuraCast pelo seu domínio:"
echo "   https://azura.daniloramos.dev.br"
echo "===================================================="

echo -e "\n===================================================="
echo "PRÓXIMOS PASSOS RECOMENDADOS:"
echo ""
echo "1️⃣ Acesse o Nginx Proxy Manager GUI:"
echo "   http://<IP_DO_SERVIDOR>:81"
echo ""
echo "2️⃣ Crie um Proxy Host:"
echo "   Domain Names: seu domínio (ex: azura.daniloramos.dev.br)"
echo "   Scheme: https"
echo "   Forward Hostname/IP: IP público do servidor"
echo "   Forward Port: 10443 (HTTPS do AzuraCast)"
echo "   Enable Websockets: ✅"
echo ""
echo "3️⃣ SSL Tab:"
echo "   - Request a new SSL certificate"
echo "   - Force SSL"
echo "   - HTTP/2 Support"
echo "   - Informe seu e-mail e aceite os termos Let’s Encrypt"
echo ""
echo "4️⃣ Acesse o AzuraCast pelo seu domínio:"
echo "   https://azura.daniloramos.dev.br"
echo "===================================================="
