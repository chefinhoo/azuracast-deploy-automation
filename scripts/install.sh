#!/bin/bash
# install.sh - Instalação automatizada AzuraCast + Nginx Proxy Manager (multi-site, ARM-ready)

set -e

echo "[INFO] Verificando portas disponíveis..."
# AzuraCast default HTTP/HTTPS
AZURACAST_HTTP=10080
AZURACAST_HTTPS=10443
STREAM_MIN=9000
STREAM_MAX=9999

# Nginx Proxy Manager default ports
NPM_HTTP=80
NPM_HTTPS=443
NPM_GUI=81

echo "[INFO] Instalando Docker/Docker Compose..."

# Instala Docker (Ubuntu ARM)
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg lsb-release

mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable --now docker.service

echo "[INFO] Instalando Nginx Proxy Manager..."
mkdir -p /var/proxy_manager
cd /var/proxy_manager

# Cria docker-compose.yml do NPM com MariaDB ARM-friendly
cat > docker-compose.yml <<EOF
version: "3"

services:
  app:
    image: jc21/nginx-proxy-manager:latest
    restart: always
    ports:
      - "${NPM_HTTP}:80"
      - "${NPM_GUI}:81"
      - "${NPM_HTTPS}:443"
    environment:
      DB_MYSQL_HOST: db
      DB_MYSQL_PORT: 3306
      DB_MYSQL_USER: npm
      DB_MYSQL_PASSWORD: npm
      DB_MYSQL_NAME: npm
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    depends_on:
      - db

  db:
    image: yobasystems/alpine-mariadb:latest
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: npm
      MYSQL_DATABASE: npm
      MYSQL_USER: npm
      MYSQL_PASSWORD: npm
    volumes:
      - ./mysql:/var/lib/mysql
EOF

docker-compose up -d

echo "[INFO] Nginx Proxy Manager iniciado!"

echo "[INFO] Instalando AzuraCast..."
mkdir -p /var/azuracast
cd /var/azuracast
curl -fsSL https://raw.githubusercontent.com/AzuraCast/AzuraCast/main/docker.sh -o docker.sh
chmod +x docker.sh

echo "[INFO] Instalando Docker/Docker Compose do AzuraCast (se necessário)..."
./docker.sh install-docker
./docker.sh install-docker-compose

# Configura portas do AzuraCast
cat > .env <<EOF
AZURACAST_HTTP_PORT=${AZURACAST_HTTP}
AZURACAST_HTTPS_PORT=${AZURACAST_HTTPS}
AZURACAST_RADIO_PORT_MIN=${STREAM_MIN}
AZURACAST_RADIO_PORT_MAX=${STREAM_MAX}
EOF

echo "[INFO] Instalando AzuraCast em modo Docker..."
yes '' | ./docker.sh install

echo "[INFO] AzuraCast instalado com sucesso!"
echo "HTTP: ${AZURACAST_HTTP}, HTTPS: ${AZURACAST_HTTPS}, STREAM: ${STREAM_MIN}-${STREAM_MAX}"
echo "Configure um Proxy Host no Nginx Proxy Manager apontando para essas portas."
#!/bin/bash
# install.sh - Instalação automatizada AzuraCast + Nginx Proxy Manager (multi-site, ARM-ready)

set -e

echo "[INFO] Verificando portas disponíveis..."
# AzuraCast default HTTP/HTTPS
AZURACAST_HTTP=10080
AZURACAST_HTTPS=10443
STREAM_MIN=9000
STREAM_MAX=9999

# Nginx Proxy Manager default ports
NPM_HTTP=80
NPM_HTTPS=443
NPM_GUI=81

echo "[INFO] Instalando Docker/Docker Compose..."

# Instala Docker (Ubuntu ARM)
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg lsb-release

mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable --now docker.service

echo "[INFO] Instalando Nginx Proxy Manager..."
mkdir -p /var/proxy_manager
cd /var/proxy_manager

# Cria docker-compose.yml do NPM com MariaDB ARM-friendly
cat > docker-compose.yml <<EOF
version: "3"

services:
  app:
    image: jc21/nginx-proxy-manager:latest
    restart: always
    ports:
      - "${NPM_HTTP}:80"
      - "${NPM_GUI}:81"
      - "${NPM_HTTPS}:443"
    environment:
      DB_MYSQL_HOST: db
      DB_MYSQL_PORT: 3306
      DB_MYSQL_USER: npm
      DB_MYSQL_PASSWORD: npm
      DB_MYSQL_NAME: npm
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    depends_on:
      - db

  db:
    image: yobasystems/alpine-mariadb:latest
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: npm
      MYSQL_DATABASE: npm
      MYSQL_USER: npm
      MYSQL_PASSWORD: npm
    volumes:
      - ./mysql:/var/lib/mysql
EOF

docker-compose up -d

echo "[INFO] Nginx Proxy Manager iniciado!"

echo "[INFO] Instalando AzuraCast..."
mkdir -p /var/azuracast
cd /var/azuracast
curl -fsSL https://raw.githubusercontent.com/AzuraCast/AzuraCast/main/docker.sh -o docker.sh
chmod +x docker.sh

echo "[INFO] Instalando Docker/Docker Compose do AzuraCast (se necessário)..."
./docker.sh install-docker
./docker.sh install-docker-compose

# Configura portas do AzuraCast
cat > .env <<EOF
AZURACAST_HTTP_PORT=${AZURACAST_HTTP}
AZURACAST_HTTPS_PORT=${AZURACAST_HTTPS}
AZURACAST_RADIO_PORT_MIN=${STREAM_MIN}
AZURACAST_RADIO_PORT_MAX=${STREAM_MAX}
EOF

echo "[INFO] Instalando AzuraCast em modo Docker..."
yes '' | ./docker.sh install

echo "[INFO] AzuraCast instalado com sucesso!"
echo "HTTP: ${AZURACAST_HTTP}, HTTPS: ${AZURACAST_HTTPS}, STREAM: ${STREAM_MIN}-${STREAM_MAX}"
echo "Configure um Proxy Host no Nginx Proxy Manager apontando para essas portas."
#!/bin/bash
# install.sh - Instalação automatizada AzuraCast + Nginx Proxy Manager (multi-site, ARM-ready)

set -e

echo "[INFO] Verificando portas disponíveis..."
# AzuraCast default HTTP/HTTPS
AZURACAST_HTTP=10080
AZURACAST_HTTPS=10443
STREAM_MIN=9000
STREAM_MAX=9999

# Nginx Proxy Manager default ports
NPM_HTTP=80
NPM_HTTPS=443
NPM_GUI=81

echo "[INFO] Instalando Docker/Docker Compose..."

# Instala Docker (Ubuntu ARM)
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg lsb-release

mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable --now docker.service

echo "[INFO] Instalando Nginx Proxy Manager..."
mkdir -p /var/proxy_manager
cd /var/proxy_manager

# Cria docker-compose.yml do NPM com MariaDB ARM-friendly
cat > docker-compose.yml <<EOF
version: "3"

services:
  app:
    image: jc21/nginx-proxy-manager:latest
    restart: always
    ports:
      - "${NPM_HTTP}:80"
      - "${NPM_GUI}:81"
      - "${NPM_HTTPS}:443"
    environment:
      DB_MYSQL_HOST: db
      DB_MYSQL_PORT: 3306
      DB_MYSQL_USER: npm
      DB_MYSQL_PASSWORD: npm
      DB_MYSQL_NAME: npm
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    depends_on:
      - db

  db:
    image: yobasystems/alpine-mariadb:latest
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: npm
      MYSQL_DATABASE: npm
      MYSQL_USER: npm
      MYSQL_PASSWORD: npm
    volumes:
      - ./mysql:/var/lib/mysql
EOF

docker-compose up -d

echo "[INFO] Nginx Proxy Manager iniciado!"

echo "[INFO] Instalando AzuraCast..."
mkdir -p /var/azuracast
cd /var/azuracast
curl -fsSL https://raw.githubusercontent.com/AzuraCast/AzuraCast/main/docker.sh -o docker.sh
chmod +x docker.sh

echo "[INFO] Instalando Docker/Docker Compose do AzuraCast (se necessário)..."
./docker.sh install-docker
./docker.sh install-docker-compose

# Configura portas do AzuraCast
cat > .env <<EOF
AZURACAST_HTTP_PORT=${AZURACAST_HTTP}
AZURACAST_HTTPS_PORT=${AZURACAST_HTTPS}
AZURACAST_RADIO_PORT_MIN=${STREAM_MIN}
AZURACAST_RADIO_PORT_MAX=${STREAM_MAX}
EOF

echo "[INFO] Instalando AzuraCast em modo Docker..."
yes '' | ./docker.sh install

echo "[INFO] AzuraCast instalado com sucesso!"
echo "HTTP: ${AZURACAST_HTTP}, HTTPS: ${AZURACAST_HTTPS}, STREAM: ${STREAM_MIN}-${STREAM_MAX}"
echo "Configure um Proxy Host no Nginx Proxy Manager apontando para essas portas."
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
