#!/bin/bash
# =========================================================
# Script Final de Instalação AzuraCast + Nginx Proxy Manager
# Compatível ARM / Ubuntu 24.04 LTS
# AzuraCast: portas de rádio a partir de 9000
# Interface web: HTTP 10080, HTTPS 10443
# Nginx Proxy Manager: volumes persistentes
# =========================================================

set -e

echo "[INFO] Verificando se está rodando como root..."
if [[ $EUID -ne 0 ]]; then
   echo "Este script precisa ser executado como root."
   exit 1
fi

# ========================
# Função para liberar locks do apt
# ========================
echo "[INFO] Verificando travamentos do apt..."
if fuser /var/lib/dpkg/lock >/dev/null 2>&1 ; then
    echo "[WARN] Encontrado lock do apt. Tentando liberar..."
    fuser -k /var/lib/dpkg/lock
    rm -f /var/lib/apt/lists/lock
    rm -f /var/cache/apt/archives/lock
    rm -f /var/lib/dpkg/lock*
    dpkg --configure -a
fi

# ========================
# Criando diretórios
# ========================
echo "[INFO] Criando diretórios de instalação..."
mkdir -p /var/azuracast
mkdir -p /var/proxy_manager

# ========================
# Instalando Docker e Compose
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

# Cria arquivo .env **antes da instalação**
cat > .env <<EOL
# Portas da interface web
AZURACAST_HTTP_PORT=10080
AZURACAST_HTTPS_PORT=10443
# Porta base de streaming (Icecast/Shoutcast)
AZURACAST_ICECAST_PORT=9000
EOL

echo "[INFO] Executando instalação do AzuraCast..."
yes | ./docker.sh install

echo "[INFO] Reiniciando AzuraCast..."
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
echo "[INFO] Instalação concluída!"
echo "AzuraCast Web: HTTP 10080 / HTTPS 10443"
echo "Rádios: streaming a partir da porta 9000"
echo "Nginx Proxy Manager: http://<IP_DO_SERVIDOR>:81"

cat <<EOL

💡 Próximos passos recomendados:

1️⃣ Acesse Nginx Proxy Manager GUI:
http://<IP_DO_SERVIDOR>:81

2️⃣ Crie um Proxy Host para cada domínio/rádio:
Domain Names: seu domínio (ex: azura.daniloramos.dev.br)
Scheme: https
Forward Hostname/IP: IP público do servidor
Forward Port: 10443 (HTTPS do AzuraCast)
Enable Websockets: ✅
SSL Tab:
Request a new SSL certificate
Force SSL
HTTP/2 Support
Informe seu e-mail e aceite os termos Let's Encrypt

3️⃣ Acesse o AzuraCast pelo seu domínio:
https://azura.seudominio.com

4️⃣ Suas rádios estarão disponíveis a partir da porta 9000 (Icecast/Shoutcast).

EOL
