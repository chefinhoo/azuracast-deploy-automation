#!/usr/bin/env bash
#
# Otimizar Nginx Proxy Manager para Performance
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROXY_MANAGER_DIR="/var/proxy_manager"

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERRO]${NC} Este script precisa ser executado como root"
    exit 1
fi

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ OTIMIZAR NGINX PROXY MANAGER                     ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

if [ ! -d "$PROXY_MANAGER_DIR" ]; then
    echo -e "${RED}[ERRO]${NC} Nginx Proxy Manager não encontrado em $PROXY_MANAGER_DIR"
    exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "^nginx-proxy-manager$"; then
    echo -e "${RED}[ERRO]${NC} Container nginx-proxy-manager não está rodando"
    exit 1
fi

echo -e "${YELLOW}Este script irá otimizar o Nginx Proxy Manager para melhor performance.${NC}"
echo ""
echo "Otimizações que serão aplicadas:"
echo "  • Configurações de buffer otimizadas"
echo "  • Timeouts aumentados para streaming"
echo "  • Keepalive connections"
echo "  • DNS resolver rápido"
echo "  • Gzip compression"
echo ""

read -rp "Deseja continuar? [s/N]: " response
if [[ ! "$response" =~ ^[sS]$ ]]; then
    echo "Cancelado."
    exit 0
fi

echo ""
echo -e "${BLUE}[→]${NC} Criando configurações otimizadas..."

# Criar diretório para configurações customizadas
mkdir -p "$PROXY_MANAGER_DIR/nginx-custom"

# Criar arquivo de configuração otimizado (contexto http)
cat > "$PROXY_MANAGER_DIR/nginx-custom/http.conf" <<'EOF'
# ====================================
# Configurações de Performance NPM
# (arquivo incluso dentro do bloco http)
# ====================================

# Timeouts otimizados
proxy_connect_timeout 300s;
proxy_send_timeout 300s;
proxy_read_timeout 300s;
send_timeout 300s;

client_header_timeout 60s;
client_body_timeout 60s;

keepalive_timeout 65s;
keepalive_requests 100;

# Buffers otimizados
client_body_buffer_size 128k;
client_max_body_size 256m;
client_header_buffer_size 4k;
large_client_header_buffers 4 16k;

proxy_buffer_size 8k;
proxy_buffers 16 8k;
proxy_busy_buffers_size 16k;

# FastCGI
fastcgi_buffer_size 16k;
fastcgi_buffers 16 16k;
fastcgi_busy_buffers_size 32k;

# Gzip Compression
gzip on;
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml font/truetype font/opentype application/vnd.ms-fontobject image/svg+xml;
gzip_disable "msie6";
gzip_min_length 256;

# DNS Resolver (Google DNS e Cloudflare)
resolver 8.8.8.8 8.8.4.4 1.1.1.1 valid=300s;
resolver_timeout 10s;

# Proxy Headers Optimization
proxy_http_version 1.1;
proxy_set_header Connection "";
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;

# TCP Settings
tcp_nodelay on;
tcp_nopush on;

# File handling
sendfile on;
sendfile_max_chunk 512k;

# Hide version
server_tokens off;
EOF

echo -e "${GREEN}✓${NC} Arquivo de configuração criado"

# Atualizar docker-compose.yml para incluir configuração customizada
compose_file="$PROXY_MANAGER_DIR/docker-compose.yml"

if grep -q "nginx-custom/http.conf" "$compose_file"; then
    echo -e "${YELLOW}✓${NC} docker-compose.yml já contém configuração customizada"
else
    echo -e "${YELLOW}→${NC} Atualizando docker-compose.yml..."
    
    # Backup
    cp "$compose_file" "$compose_file.bak.$(date +%Y%m%d_%H%M%S)"
    
    # Adicionar volume para configuração customizada
    # Procurar a seção de volumes do app e adicionar
    awk '
    BEGIN {in_app=0; in_volumes=0; added=0}
    /^  app:/ {in_app=1}
    in_app && /^    volumes:/ {in_volumes=1}
    in_app && in_volumes && /^      - app_letsencrypt/ && !added {
        print
        print "      - ./nginx-custom:/data/nginx/custom:ro"
        added=1
        next
    }
    /^  [a-z]/ && !/^  app:/ {in_app=0; in_volumes=0}
    {print}
    ' "$compose_file" > "$compose_file.tmp" && mv "$compose_file.tmp" "$compose_file"
    
    echo -e "${GREEN}✓${NC} docker-compose.yml atualizado"
fi

# Criar arquivo de ambiente otimizado
cat > "$PROXY_MANAGER_DIR/.env" <<'EOF'
# Otimizações de Performance
COMPOSE_HTTP_TIMEOUT=300
COMPOSE_PROJECT_NAME=nginx-proxy-manager

# Database
DB_MYSQL_HOST=db
DB_MYSQL_PORT=3306
DB_MYSQL_USER=npm
DB_MYSQL_PASSWORD=npm
DB_MYSQL_NAME=npm
EOF

echo -e "${GREEN}✓${NC} Arquivo de ambiente criado"

# Reiniciar Nginx Proxy Manager
echo ""
echo -e "${YELLOW}→${NC} Reiniciando Nginx Proxy Manager..."
cd "$PROXY_MANAGER_DIR"

docker compose down || true

# Limpar containers antigos caso tenham ficado presos
if docker ps -a --format '{{.Names}}' | grep -qx "nginx-proxy-manager"; then
    docker rm -f nginx-proxy-manager >/dev/null 2>&1 || true
fi
if docker ps -a --format '{{.Names}}' | grep -qx "nginx-proxy-manager-db"; then
    docker rm -f nginx-proxy-manager-db >/dev/null 2>&1 || true
fi

sleep 2
docker compose up -d

echo -e "${GREEN}✓${NC} Nginx Proxy Manager reiniciado"

# Aguardar container ficar pronto
echo -e "${YELLOW}→${NC} Aguardando container ficar pronto..."
sleep 10

# Verificar se está rodando
if docker ps --format '{{.Names}}' | grep -q "^nginx-proxy-manager$"; then
    echo -e "${GREEN}✓${NC} Container está rodando"
    
    # Testar configuração
    echo ""
    echo -e "${YELLOW}→${NC} Verificando configuração Nginx..."
    if docker exec nginx-proxy-manager nginx -t 2>&1 | grep -q "successful"; then
        echo -e "${GREEN}✓${NC} Configuração Nginx válida"
    else
        echo -e "${RED}✗${NC} Erro na configuração Nginx"
        docker exec nginx-proxy-manager nginx -t
    fi
else
    echo -e "${RED}✗${NC} Container não iniciou corretamente"
    echo ""
    echo "Logs do container:"
    docker logs nginx-proxy-manager --tail 50
    exit 1
fi

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ OTIMIZAÇÃO CONCLUÍDA                             ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Otimizações aplicadas:${NC}"
echo "  • Buffers otimizados para grandes uploads"
echo "  • Timeouts: 300s (para streaming)"
echo "  • Keepalive habilitado"
echo "  • DNS resolver rápido (Google, Cloudflare)"
echo "  • Gzip compression ativado"
echo "  • Upload máximo: 256MB"
echo ""
echo -e "${YELLOW}Importante:${NC}"
echo "  • Reconfigure seus Proxy Hosts no painel do NPM"
echo "  • As otimizações são aplicadas globalmente"
echo "  • Cache de arquivos estáticos ativado em /tmp/nginx-cache"
echo ""
echo -e "${GREEN}Para reverter (se necessário):${NC}"
echo "  cd $PROXY_MANAGER_DIR"
echo "  docker compose down"
echo "  mv docker-compose.yml.bak.* docker-compose.yml"
echo "  rm -rf nginx-config"
echo "  docker compose up -d"
