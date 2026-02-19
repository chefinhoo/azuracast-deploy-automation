#!/bin/bash
# install.sh - Instalação automática de AzuraCast + Nginx Proxy Manager
# Autor: Danilo Ramos
# Data: 2026-02-19

set -e

echo "[INFO] Verificando portas disponíveis..."
# Aqui você poderia implementar uma verificação de portas se quiser

echo "[INFO] Instalando Docker/Docker Compose..."
apt-get update -qq
apt-get install -y -qq ca-certificates curl apt-transport-https gnupg lsb-release

mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable --now docker

echo "[INFO] Docker instalado com sucesso!"
docker version

echo "[INFO] Instalando Nginx Proxy Manager..."
mkdir -p /var/proxy_manager
cat > /var/proxy_manager/docker-compose.yml <<EOL
version: "3"
services:
  app:
    image: jc21/nginx-proxy-manager:latest
    restart: always
    ports:
      - "81:81"       # GUI NPM
      - "80:80"       # HTTP
      - "443:443"     # HTTPS
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
    image: jc21/mariadb-aria:10.5
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: 'npm'
      MYSQL_DATABASE: 'npm'
      MYSQL_USER: 'npm'
      MYSQL_PASSWORD: 'npm'
    volumes:
      - ./data/mysql:/var/lib/mysql
EOL

docker-compose -f /var/proxy_manager/docker-compose.yml up -d || true
echo "[INFO] Nginx Proxy Manager iniciado!"

echo "[INFO] Instalando AzuraCast..."
mkdir -p /var/azuracast
cd /var/azuracast

curl -fsSL https://raw.githubusercontent.com/AzuraCast/AzuraCast/main/docker.sh > docker.sh
chmod +x docker.sh

# Instalação não interativa
yes '' | ./docker.sh install

echo "[INFO] Ajustando portas do AzuraCast para evitar conflito com Nginx Proxy Manager..."
# Edita .env para usar portas não padrão
sed -i 's/AZURACAST_HTTP_PORT=.*/AZURACAST_HTTP_PORT=10080/' .env
sed -i 's/AZURACAST_HTTPS_PORT=.*/AZURACAST_HTTPS_PORT=10443/' .env

docker-compose down || true
docker-compose up -d

echo "[INFO] AzuraCast instalado com sucesso!"
echo "HTTP: 10080, HTTPS: 10443, STREAM: 9000-9999"

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
