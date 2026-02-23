#!/usr/bin/env bash
#
# Corrigir instalação WordPress com erro YAML
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WEB_ROOT="/var/www"

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERRO]${NC} Este script precisa ser executado como root"
    exit 1
fi

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ CORRIGIR WORDPRESS COM ERRO YAML                 ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# Buscar diretórios WordPress com erro
wordpress_dirs=()
for dir in "$WEB_ROOT"/*; do
    if [ -d "$dir" ] && [ -f "$dir/docker-compose.yml" ]; then
        # Verificar se o container está rodando
        domain_name=$(basename "$dir")
        container_name="wp-app-${domain_name//./-}"
        
        if ! docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
            echo -e "${YELLOW}[!]${NC} WordPress não está rodando para: $domain_name"
            wordpress_dirs+=("$dir")
        fi
    fi
done

if [ ${#wordpress_dirs[@]} -eq 0 ]; then
    echo -e "${GREEN}[✓]${NC} Nenhum WordPress com erro encontrado"
    exit 0
fi

echo ""
echo -e "${YELLOW}WordPress com problemas encontrados:${NC}"
for i in "${!wordpress_dirs[@]}"; do
    echo "  $((i+1))) $(basename "${wordpress_dirs[$i]}")"
done
echo ""

read -rp "Deseja recriar todos? [s/N]: " response
if [[ ! "$response" =~ ^[sS]$ ]]; then
    echo "Cancelado."
    exit 0
fi

echo ""

# Recriar cada WordPress
for wp_dir in "${wordpress_dirs[@]}"; do
    domain=$(basename "$wp_dir")
    domain_slug="${domain//./-}"
    container_name="wp-app-${domain_slug}"
    db_container_name="wp-db-${domain_slug}"
    network_name="wp-${domain_slug}-network"
    
    echo -e "${BLUE}[→]${NC} Corrigindo WordPress: $domain"
    
    # Parar containers existentes (se houver)
    cd "$wp_dir"
    docker compose down 2>/dev/null || true
    
    # Remover docker-compose.yml com erro
    if [ -f docker-compose.yml ]; then
        rm -f docker-compose.yml
        echo -e "${GREEN}  ✓${NC} docker-compose.yml com erro removido"
    fi
    
    # Ler credenciais existentes
    creds_file="$wp_dir/wordpress-credentials.txt"
    if [ ! -f "$creds_file" ]; then
        echo -e "${RED}  ✗${NC} Arquivo de credenciais não encontrado: $creds_file"
        echo -e "${YELLOW}  →${NC} Pulando este domínio..."
        continue
    fi
    
    wp_db_name=$(grep '^WORDPRESS_DB_NAME=' "$creds_file" | cut -d= -f2)
    wp_db_user=$(grep '^WORDPRESS_DB_USER=' "$creds_file" | cut -d= -f2)
    wp_db_password=$(grep '^WORDPRESS_DB_PASSWORD=' "$creds_file" | cut -d= -f2)
    wp_db_root_password=$(grep '^WORDPRESS_DB_ROOT_PASSWORD=' "$creds_file" | cut -d= -f2)
    
    # Criar docker-compose.yml correto
    cat > "$wp_dir/docker-compose.yml" <<EOF
services:
  wp-db:
    image: mariadb:10.11
    container_name: ${db_container_name}
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${wp_db_root_password}
      MYSQL_DATABASE: ${wp_db_name}
      MYSQL_USER: ${wp_db_user}
      MYSQL_PASSWORD: ${wp_db_password}
    volumes:
      - ./db_data:/var/lib/mysql
    networks:
      - wp_network

  wordpress:
    image: wordpress:php8.2-apache
    container_name: ${container_name}
    restart: unless-stopped
    depends_on:
      - wp-db
    environment:
      WORDPRESS_DB_HOST: wp-db:3306
      WORDPRESS_DB_NAME: ${wp_db_name}
      WORDPRESS_DB_USER: ${wp_db_user}
      WORDPRESS_DB_PASSWORD: ${wp_db_password}
    volumes:
      - ./html:/var/www/html
    networks:
      - wp_network

networks:
  wp_network:
    name: ${network_name}
    driver: bridge
EOF
    
    echo -e "${GREEN}  ✓${NC} docker-compose.yml correto criado"
    
    # Iniciar stack WordPress
    if docker compose up -d; then
        echo -e "${GREEN}  ✓${NC} Stack WordPress iniciado com sucesso"
    else
        echo -e "${RED}  ✗${NC} Falha ao iniciar stack WordPress"
        continue
    fi
    
    # Conectar NPM à rede do WordPress
    if docker ps --format '{{.Names}}' | grep -q "^nginx-proxy-manager$"; then
        if ! docker network connect "$network_name" nginx-proxy-manager 2>/dev/null; then
            # Já está conectado
            :
        fi
        echo -e "${GREEN}  ✓${NC} NPM conectado à rede do WordPress"
        
        # Validar conectividade
        if docker exec nginx-proxy-manager sh -lc "curl -s -o /dev/null -w '%{http_code}' --max-time 8 http://${container_name}:80" 2>/dev/null | grep -Eq '^(200|301|302)$'; then
            echo -e "${GREEN}  ✓${NC} Conectividade NPM -> ${container_name}:80 validada"
        else
            echo -e "${YELLOW}  !${NC} Conectividade não validada, mas pode estar ok"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}[✓]${NC} WordPress corrigido para: $domain"
    echo ""
    echo "   Configuração no NPM:"
    echo "   Domain Names: $domain"
    echo "   Scheme: http"
    echo "   Forward Hostname/IP: $container_name"
    echo "   Forward Port: 80"
    echo ""
done

echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║ CORREÇÃO CONCLUÍDA                               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
