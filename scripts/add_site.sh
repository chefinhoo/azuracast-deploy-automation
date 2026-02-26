#!/bin/bash
# =========================================================
# Adicionar novo domínio (WordPress ou Site Estático)
# =========================================================

set -euo pipefail

SCRIPT_FILE="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_FILE")" && pwd)"

if [ ! -f "${SCRIPT_DIR}/lib/common.sh" ]; then
    echo "[ERRO] Biblioteca comum não encontrada: ${SCRIPT_DIR}/lib/common.sh" >&2
    exit 1
fi

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/common.sh"

PROXY_DOMAIN=""
PROXY_SCHEME="http"
PROXY_FORWARD_HOST=""
PROXY_FORWARD_PORT="80"

connect_npm_to_network() {
    local network_name="$1"
    local backend_host="$2"
    local backend_port="$3"

    if ! docker ps --format '{{.Names}}' | grep -qx "nginx-proxy-manager"; then
        log_warn "Container nginx-proxy-manager não encontrado. Conecte manualmente na rede $network_name"
        return 0
    fi

    if docker inspect -f '{{range $name, $_ := .NetworkSettings.Networks}}{{println $name}}{{end}}' nginx-proxy-manager 2>/dev/null | grep -qx "$network_name"; then
        log_success "NPM já conectado à rede: $network_name"
    else
        if docker network connect "$network_name" nginx-proxy-manager 2>/dev/null; then
            log_success "NPM conectado à rede: $network_name"
        else
            log_warn "Falha ao conectar NPM na rede $network_name"
            return 0
        fi
    fi

    if docker exec nginx-proxy-manager sh -lc "curl -s -o /dev/null -w '%{http_code}' --max-time 8 http://${backend_host}:${backend_port}" 2>/dev/null | grep -Eq '^(200|301|302)$'; then
        log_success "Conectividade interna validada: ${backend_host}:${backend_port}"
    else
        log_warn "Não foi possível validar conectividade para ${backend_host}:${backend_port}"
    fi

    return 0
}

provision_wordpress() {
    local domain="$1"
    local client_name="$2"
    local subdirectory_name="$3"
    
    local slug="${domain//./-}"
    local domain_path="$WEB_ROOT/www/$client_name/$subdirectory_name"
    
    log_info "Caminho do site: $domain_path"
    
    local wp_container_name="wp-app-${slug}"
    local wp_db_container_name="wp-db-${slug}"
    local wp_network_name="wp-${slug}-network"
    local creds_file="$domain_path/wordpress-credentials.txt"

    local wp_db_name="wordpress"
    local wp_db_user="wordpress"
    local wp_db_password=""
    local wp_db_root_password=""

    log_info "Provisionando WordPress para $domain"
    
    # Criar estrutura de diretórios
    mkdir -p "$domain_path" "$domain_path/db_data"
    
    # Gerenciar usuário Filebrowser para o cliente
    manage_filebrowser_user "$client_name" "${CLIENT_IS_NEW:-true}"

    if [ -f "$creds_file" ]; then
        log_info "Credenciais existentes encontradas. Reutilizando..."
        wp_db_name="$(grep '^WORDPRESS_DB_NAME=' "$creds_file" | tail -1 | cut -d= -f2- || true)"
        wp_db_user="$(grep '^WORDPRESS_DB_USER=' "$creds_file" | tail -1 | cut -d= -f2- || true)"
        wp_db_password="$(grep '^WORDPRESS_DB_PASSWORD=' "$creds_file" | tail -1 | cut -d= -f2- || true)"
        wp_db_root_password="$(grep '^WORDPRESS_DB_ROOT_PASSWORD=' "$creds_file" | tail -1 | cut -d= -f2- || true)"

        wp_db_name="${wp_db_name:-wordpress}"
        wp_db_user="${wp_db_user:-wordpress}"
    fi

    if [ -z "$wp_db_password" ]; then
        wp_db_password="$(openssl rand -base64 24 | tr -d '=+/' | cut -c1-24)"
    fi

    if [ -z "$wp_db_root_password" ]; then
        wp_db_root_password="$(openssl rand -base64 48 | tr -d '=+/' | cut -c1-32)"
    fi

    # Volume path sempre aponta para o diretório atual
    local volume_path="./:/var/www/html"

    cat > "$domain_path/docker-compose.yml" <<EOF
services:
  wp-db:
    image: mariadb:10.11
    container_name: ${wp_db_container_name}
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
    container_name: ${wp_container_name}
    restart: unless-stopped
    depends_on:
      - wp-db
    environment:
      WORDPRESS_DB_HOST: wp-db:3306
      WORDPRESS_DB_NAME: ${wp_db_name}
      WORDPRESS_DB_USER: ${wp_db_user}
      WORDPRESS_DB_PASSWORD: ${wp_db_password}
    volumes:
      - ${volume_path}
      - ./php-custom.ini:/usr/local/etc/php/conf.d/custom.ini:ro
    networks:
      - wp_network

networks:
  wp_network:
    name: ${wp_network_name}
    driver: bridge
EOF

    # Criar configuração PHP otimizada
    cat > "$domain_path/php-custom.ini" <<'PHP_EOF'
; Configurações de Performance PHP
memory_limit = 256M
upload_max_filesize = 64M
post_max_size = 64M
max_execution_time = 300
max_input_time = 300

; OPcache
opcache.enable = 1
opcache.memory_consumption = 128
opcache.interned_strings_buffer = 8
opcache.max_accelerated_files = 10000
opcache.revalidate_freq = 2
opcache.fast_shutdown = 1

; Realpath Cache
realpath_cache_size = 4096K
realpath_cache_ttl = 600
PHP_EOF

    # Criar .htaccess otimizado no diretório raiz
    local htaccess_path="$domain_path/.htaccess"
    
    cat > "$htaccess_path" <<'HTACCESS_EOF'
# BEGIN WordPress Optimization
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript application/json application/xml
</IfModule>

<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType image/jpg "access plus 1 year"
    ExpiresByType image/jpeg "access plus 1 year"
    ExpiresByType image/png "access plus 1 year"
    ExpiresByType image/webp "access plus 1 year"
    ExpiresByType text/css "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
    ExpiresByType image/x-icon "access plus 1 year"
    ExpiresDefault "access plus 2 days"
</IfModule>

<IfModule mod_headers.c>
    <FilesMatch "\\.(ico|jpe?g|png|gif|webp|css|js|woff2?)$">
        Header set Cache-Control "max-age=31536000, public"
    </FilesMatch>
</IfModule>

FileETag None
# END WordPress Optimization

# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
HTACCESS_EOF

    (cd "$domain_path" && docker compose up -d)

    cat > "$creds_file" <<EOF
CLIENT_NAME=${client_name}
SUBDIRECTORY_NAME=${subdirectory_name}
DOMAIN=${domain}
WORDPRESS_URL=http://${domain}
WORDPRESS_CONTAINER=${wp_container_name}
WORDPRESS_DB_CONTAINER=${wp_db_container_name}
WORDPRESS_NETWORK=${wp_network_name}
WORDPRESS_PROXY_HOST=${wp_container_name}
WORDPRESS_PROXY_PORT=80
WORDPRESS_DB_NAME=${wp_db_name}
WORDPRESS_DB_USER=${wp_db_user}
WORDPRESS_DB_PASSWORD=${wp_db_password}
WORDPRESS_DB_ROOT_PASSWORD=${wp_db_root_password}
EOF

    chmod 600 "$creds_file" || true

    connect_npm_to_network "$wp_network_name" "$wp_container_name" "80"

    PROXY_DOMAIN="$domain"
    PROXY_SCHEME="http"
    PROXY_FORWARD_HOST="$wp_container_name"
    PROXY_FORWARD_PORT="80"

    log_success "WordPress criado para $domain"
    echo ""
    echo "Configuração no NPM:"
    echo "  Domain Names: $domain"
    echo "  Scheme: http"
    echo "  Forward Hostname/IP: $wp_container_name"
    echo "  Forward Port: 80"
}

provision_static_site() {
    local domain="$1"
    local client_name="$2"
    local subdirectory_name="$3"
    
    local slug="${domain//./-}"
    local domain_path="$WEB_ROOT/www/$client_name/$subdirectory_name"
    
    log_info "Caminho do site: $domain_path"
    
    local static_container_name="site-app-${slug}"
    local static_network_name="site-${slug}-network"

    log_info "Provisionando site estático para $domain"
    
    mkdir -p "$domain_path"
    
    # Gerenciar usuário Filebrowser para o cliente
    manage_filebrowser_user "$client_name" "${CLIENT_IS_NEW:-true}"

    local index_path="$domain_path/index.html"
    
    if [ ! -f "$index_path" ]; then
        cat > "$index_path" <<EOF
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>$domain</title>
</head>
<body>
  <h1>Site estático ativo</h1>
  <p>Domínio: $domain</p>
</body>
</html>
EOF
    fi

    # Volume path sempre aponta para o diretório atual
    local volume_path="./:/usr/share/nginx/html:ro"

    cat > "$domain_path/docker-compose.yml" <<EOF
services:
  static:
    image: nginx:alpine
    container_name: ${static_container_name}
    restart: unless-stopped
    volumes:
      - ${volume_path}
    networks:
      - static_network

networks:
  static_network:
    name: ${static_network_name}
    driver: bridge
EOF

    (cd "$domain_path" && docker compose up -d)

    connect_npm_to_network "$static_network_name" "$static_container_name" "80"

    PROXY_DOMAIN="$domain"
    PROXY_SCHEME="http"
    PROXY_FORWARD_HOST="$static_container_name"
    PROXY_FORWARD_PORT="80"

    log_success "Site estático criado para $domain"
    echo ""
    echo "Configuração no NPM:"
    echo "  Domain Names: $domain"
    echo "  Scheme: http"
    echo "  Forward Hostname/IP: $static_container_name"
    echo "  Forward Port: 80"
}

main() {
    init_logging || {
        echo "[ERRO] Falha ao inicializar logging" >&2
        exit 1
    }

    load_config

    check_root || exit 1
    check_distribution || exit 1

    print_section "ADICIONAR NOVO SITE"

    # 1. Solicitar ou selecionar cliente
    local client_name
    client_name="$(prompt_client_name)"
    
    # 2. Solicitar nome do subdiretório
    local subdirectory_name
    subdirectory_name="$(prompt_subdirectory_name "$client_name")"
    
    # 3. Solicitar domínio
    local domain
    domain="$(prompt_domain)"
    
    # Confirmar estrutura
    echo ""
    log_info "Estrutura configurada:"
    echo "  Cliente: $client_name"
    echo "  Subdiretório: $subdirectory_name"
    echo "  Domínio: $domain"
    echo "  Caminho completo: $WEB_ROOT/$client_name/$subdirectory_name"
    echo ""

    echo "Escolha o modelo do site:"
    echo "  1) WordPress"
    echo "  2) Site estático"

    local option=""
    while true; do
        read -rp "Opção [1-2]: " option
        case "$option" in
            1)
                provision_wordpress "$domain" "$client_name" "$subdirectory_name"
                break
                ;;
            2)
                provision_static_site "$domain" "$client_name" "$subdirectory_name"
                break
                ;;
            *)
                log_warn "Opção inválida. Escolha 1 ou 2."
                ;;
        esac
    done

    echo ""
    log_success "Configuração concluída."
    print_section "CONFIGURAÇÃO FINAL DO PROXY (NPM)"
    echo "  Domain Names: ${PROXY_DOMAIN}"
    echo "  Scheme: ${PROXY_SCHEME}"
    echo "  Forward Hostname/IP: ${PROXY_FORWARD_HOST}"
    echo "  Forward Port: ${PROXY_FORWARD_PORT}"
    echo ""

    local filebrowser_creds_file="$WEB_ROOT/${client_name}/.filebrowser-credentials.txt"
    if [ -f "$filebrowser_creds_file" ]; then
        local fb_user=""
        local fb_pass=""
        fb_user="$(grep -E '^Usuário:' "$filebrowser_creds_file" | head -1 | cut -d: -f2- | xargs || true)"
        fb_pass="$(grep -E '^Senha:' "$filebrowser_creds_file" | head -1 | cut -d: -f2- | xargs || true)"

        print_section "CREDENCIAIS FILEBROWSER"
        echo "  Usuário: ${fb_user:-$client_name}"
        if [ -n "$fb_pass" ]; then
            echo "  Senha: $fb_pass"
        else
            echo "  Senha: (não encontrada no arquivo)"
        fi
        echo "  Arquivo: $filebrowser_creds_file"
        echo ""
    fi

    log_info "Depois, finalize SSL no Nginx Proxy Manager (Let's Encrypt + Force SSL)."
}

main "$@"
