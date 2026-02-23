#!/usr/bin/env bash
#
# Otimizar WordPress para Performance
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
echo -e "${BLUE}║ OTIMIZAR WORDPRESS                               ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# Buscar WordPress instalados
wordpress_dirs=()
for dir in "$WEB_ROOT"/*; do
    if [ -d "$dir" ] && [ -f "$dir/docker-compose.yml" ]; then
        domain_name=$(basename "$dir")
        container_name="wp-app-${domain_name//./-}"
        
        if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
            wordpress_dirs+=("$dir")
        fi
    fi
done

if [ ${#wordpress_dirs[@]} -eq 0 ]; then
    echo -e "${YELLOW}[!]${NC} Nenhum WordPress rodando encontrado"
    exit 0
fi

echo -e "${BLUE}WordPress encontrados:${NC}"
for i in "${!wordpress_dirs[@]}"; do
    echo "  $((i+1))) $(basename "${wordpress_dirs[$i]}")"
done
echo ""

read -rp "Deseja otimizar todos? [s/N]: " response
if [[ ! "$response" =~ ^[sS]$ ]]; then
    echo "Cancelado."
    exit 0
fi

echo ""

# Otimizar cada WordPress
for wp_dir in "${wordpress_dirs[@]}"; do
    domain=$(basename "$wp_dir")
    domain_slug="${domain//./-}"
    container_name="wp-app-${domain_slug}"
    
    echo -e "${BLUE}[→]${NC} Otimizando WordPress: $domain"
    echo ""
    
    # Criar arquivo de configuração PHP customizado
    php_ini_file="$wp_dir/php-custom.ini"
    
    echo -e "${YELLOW}  • Criando configurações PHP otimizadas...${NC}"
    cat > "$php_ini_file" <<'EOF'
; ====================================
; Configurações de Performance PHP
; ====================================

; Memória
memory_limit = 256M

; Upload
upload_max_filesize = 64M
post_max_size = 64M

; Timeouts
max_execution_time = 300
max_input_time = 300

; OPcache - Cache de código compilado
opcache.enable = 1
opcache.memory_consumption = 128
opcache.interned_strings_buffer = 8
opcache.max_accelerated_files = 10000
opcache.revalidate_freq = 2
opcache.fast_shutdown = 1
opcache.enable_cli = 0

; Realpath Cache
realpath_cache_size = 4096K
realpath_cache_ttl = 600
EOF
    
    echo -e "${GREEN}  ✓${NC} php-custom.ini criado"
    
    # Criar arquivo .htaccess otimizado
    htaccess_file="$wp_dir/html/.htaccess"
    
    echo -e "${YELLOW}  • Criando .htaccess otimizado...${NC}"
    cat > "$htaccess_file" <<'EOF'
# BEGIN WordPress Optimization

# Compressão GZIP
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript application/x-javascript application/json application/xml application/rss+xml
</IfModule>

# Cache de navegador
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType image/jpg "access plus 1 year"
    ExpiresByType image/jpeg "access plus 1 year"
    ExpiresByType image/gif "access plus 1 year"
    ExpiresByType image/png "access plus 1 year"
    ExpiresByType image/webp "access plus 1 year"
    ExpiresByType text/css "access plus 1 month"
    ExpiresByType application/pdf "access plus 1 month"
    ExpiresByType text/javascript "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
    ExpiresByType application/x-shockwave-flash "access plus 1 month"
    ExpiresByType image/x-icon "access plus 1 year"
    ExpiresDefault "access plus 2 days"
</IfModule>

# Headers de Cache
<IfModule mod_headers.c>
    <FilesMatch "\\.(ico|jpe?g|png|gif|webp|css|js|woff2?)$">
        Header set Cache-Control "max-age=31536000, public"
    </FilesMatch>
</IfModule>

# Desabilitar ETags
<IfModule mod_headers.c>
    Header unset ETag
</IfModule>
FileETag None

# END WordPress Optimization

# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOF
    
    echo -e "${GREEN}  ✓${NC} .htaccess otimizado criado"
    
    # Atualizar docker-compose.yml para incluir php-custom.ini
    compose_file="$wp_dir/docker-compose.yml"
    
    if grep -q "php-custom.ini" "$compose_file"; then
        echo -e "${YELLOW}  • docker-compose.yml já contém php-custom.ini${NC}"
    else
        echo -e "${YELLOW}  • Atualizando docker-compose.yml...${NC}"
        
        # Backup
        cp "$compose_file" "$compose_file.bak"
        
        # Adicionar volume do php-custom.ini
        awk '
        /volumes:/ && /wordpress/ {p=1}
        p && /- \.\/html:\/var\/www\/html/ {
            print
            print "      - ./php-custom.ini:/usr/local/etc/php/conf.d/custom.ini:ro"
            p=0
            next
        }
        {print}
        ' "$compose_file" > "$compose_file.tmp" && mv "$compose_file.tmp" "$compose_file"
        
        echo -e "${GREEN}  ✓${NC} docker-compose.yml atualizado"
    fi
    
    # Reiniciar container
    echo -e "${YELLOW}  • Reiniciando container WordPress...${NC}"
    cd "$wp_dir"
    docker compose down
    docker compose up -d
    
    echo -e "${GREEN}  ✓${NC} Container reiniciado"
    
    # Aguardar container ficar pronto
    echo -e "${YELLOW}  • Aguardando container ficar pronto...${NC}"
    sleep 5
    
    # Verificar se OPcache está ativo
    if docker exec "$container_name" php -m 2>/dev/null | grep -q "Zend OPcache"; then
        echo -e "${GREEN}  ✓${NC} OPcache está ativo"
    else
        echo -e "${RED}  ✗${NC} OPcache não está ativo (a imagem pode não suportar)"
    fi
    
    echo ""
    echo -e "${GREEN}[✓]${NC} WordPress otimizado: $domain"
    echo ""
    echo "   ${BLUE}Otimizações aplicadas:${NC}"
    echo "   • Memória PHP: 256MB"
    echo "   • Upload máximo: 64MB"
    echo "   • Timeout: 300s"
    echo "   • OPcache habilitado"
    echo "   • Compressão GZIP"
    echo "   • Cache de navegador (imagens: 1 ano, CSS/JS: 1 mês)"
    echo ""
    echo "   ${YELLOW}Recomendações adicionais:${NC}"
    echo "   • Instale plugin de cache (WP Super Cache, W3 Total Cache)"
    echo "   • Otimize imagens antes de fazer upload"
    echo "   • Use CDN para conteúdo estático"
    echo "   • Minimize plugins desnecessários"
    echo ""
done

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ OTIMIZAÇÃO CONCLUÍDA                             ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Para verificar melhorias:${NC}"
echo "  sudo bash diagnose_performance.sh"
