#!/bin/bash
# =========================================================
# Adicionar novo domínio (WordPress ou Site Estático) - Atualizado
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
        docker network connect "$network_name" nginx-proxy-manager 2>/dev/null && log_success "NPM conectado à rede: $network_name"
    fi

    if docker exec nginx-proxy-manager sh -lc "curl -s -o /dev/null -w '%{http_code}' --max-time 8 http://${backend_host}:${backend_port}" 2>/dev/null | grep -Eq '^(200|301|302)$'; then
        log_success "Conectividade interna validada: ${backend_host}:${backend_port}"
    else
        log_warn "Não foi possível validar conectividade para ${backend_host}:${backend_port}"
    fi

    return 0
}

create_npm_proxy() {
    local domain="$1"
    local wp_container_name="$2"

    if docker exec nginx-proxy-manager sqlite3 /data/database.sqlite "SELECT id FROM proxy_host WHERE domain_names LIKE '%$domain%'" 2>/dev/null | grep -q .; then
        log_warn "Proxy já existe para $domain → não será criado novamente"
    else
        docker exec nginx-proxy-manager sqlite3 /data/database.sqlite \
            "INSERT INTO proxy_host (domain_names, forward_host, forward_port, scheme, block_exploits, cache_assets, allow_websocket_upgrade, access_list_id, ssl_forced, meta) VALUES ('$domain', '$wp_container_name', 80, 'http', 1, 1, 1, NULL, 0, '{}');"
        log_success "Proxy criado automaticamente no NPM para $domain"
    fi
}

provision_wordpress() {
    local domain="$1"
    local client_name="$2"
    local subdirectory_name="$3"

    # Slug + timestamp para garantir unicidade
    local slug
      # Slug único: client, subdir, domínio, timestamp só se necessário
      slug=$(echo "${client_name}-${subdirectory_name}-${domain}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^\-|-$//g')
      while docker ps -a --format '{{.Names}}' | grep -q "wp-app-${slug}" || docker network ls --format '{{.Name}}' | grep -q "wp-${slug}-network"; do
          slug="${slug}-$(date +%s)"
          sleep 1
      done

    local domain_path="$WEB_ROOT/www/$client_name/$subdirectory_name"
    mkdir -p "$domain_path" "$domain_path/db_data"

    local wp_container_name="wp-app-${slug}"
    local wp_db_container_name="wp-db-${slug}"
    local wp_network_name="wp-${slug}-network"
    local creds_file="$domain_path/wordpress-credentials.txt"

    local wp_db_name="wordpress"
    local wp_db_user="wordpress"
    local wp_db_password=""
    local wp_db_root_password=""

    # Reutiliza credenciais existentes
    if [ -f "$creds_file" ]; then
        wp_db_name="$(grep '^WORDPRESS_DB_NAME=' "$creds_file" | tail -1 | cut -d= -f2- || true)"
        wp_db_user="$(grep '^WORDPRESS_DB_USER=' "$creds_file" | tail -1 | cut -d= -f2- || true)"
        wp_db_password="$(grep '^WORDPRESS_DB_PASSWORD=' "$creds_file" | tail -1 | cut -d= -f2- || true)"
        wp_db_root_password="$(grep '^WORDPRESS_DB_ROOT_PASSWORD=' "$creds_file" | tail -1 | cut -d= -f2- || true)"
    fi

    # Gera senhas aleatórias se não houver
    [ -z "$wp_db_password" ] && wp_db_password="$(openssl rand -base64 24 | tr -d '=+/' | cut -c1-24)"
    [ -z "$wp_db_root_password" ] && wp_db_root_password="$(openssl rand -base64 48 | tr -d '=+/' | cut -c1-32)"

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

    # Cria php-custom.ini
    cat > "$domain_path/php-custom.ini" <<'PHP_EOF'
memory_limit = 256M
upload_max_filesize = 64M
post_max_size = 64M
max_execution_time = 300
max_input_time = 300
opcache.enable = 1
opcache.memory_consumption = 128
opcache.interned_strings_buffer = 8
opcache.max_accelerated_files = 10000
opcache.revalidate_freq = 2
opcache.fast_shutdown = 1
realpath_cache_size = 4096K
realpath_cache_ttl = 600
PHP_EOF

# Rodar docker compose
(cd "$domain_path" && docker compose up -d)

# Salvar credenciais
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

# Conecta NPM e cria proxy
connect_npm_to_network "$wp_network_name" "$wp_container_name" "80"
create_npm_proxy "$domain" "$wp_container_name"

log_success "WordPress criado para $domain"
}

# ============================================
# Provisionamento de site estático (igual original)
# ============================================
provision_static_site() {
    local domain="$1"
    local client_name="$2"
    local subdirectory_name="$3"

    local slug
      slug=$(echo "${client_name}-${subdirectory_name}-${domain}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^\-|-$//g')
      while docker ps -a --format '{{.Names}}' | grep -q "site-app-${slug}" || docker network ls --format '{{.Name}}' | grep -q "site-${slug}-network"; do
          slug="${slug}-$(date +%s)"
          sleep 1
      done

    local domain_path="$WEB_ROOT/www/$client_name/$subdirectory_name"
    mkdir -p "$domain_path"

    local static_container_name="site-app-${slug}"
    local static_network_name="site-${slug}-network"

    mkdir -p "$domain_path"
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

    # Conecta NPM e cria proxy
    connect_npm_to_network "$static_network_name" "$static_container_name" "80"
    create_npm_proxy "$domain" "$static_container_name"

    log_success "Site estático criado para $domain"
}

# ============================================
# Função main
# ============================================
main() {
    init_logging || { echo "[ERRO] Falha ao inicializar logging" >&2; exit 1; }
    load_config
    check_root || exit 1
    check_distribution || exit 1

    print_section "ADICIONAR NOVO SITE"

    local client_name
    client_name="$(prompt_client_name)"

    local subdirectory_name
    subdirectory_name="$(prompt_subdirectory_name "$client_name")"

    local domain
    domain="$(prompt_domain)"

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
            1) provision_wordpress "$domain" "$client_name" "$subdirectory_name"; break ;;
            2) provision_static_site "$domain" "$client_name" "$subdirectory_name"; break ;;
            *) log_warn "Opção inválida. Escolha 1 ou 2." ;;
        esac
    done

    log_info "Depois, finalize SSL no Nginx Proxy Manager (Let's Encrypt + Force SSL)."
}

main "$@"
