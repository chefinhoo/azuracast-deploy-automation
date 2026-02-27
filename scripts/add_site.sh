#!/bin/bash
# =========================================================
# Add Site - Versão Independente (Sem lib/common.sh)
# =========================================================

set -euo pipefail

WEB_ROOT="/var/www"

# =========================================================
# Funções Utilitárias
# =========================================================

generate_base_slug() {
    echo "$1" | tr '[:upper:]' '[:lower:]' \
        | sed 's/[^a-z0-9]/-/g' \
        | sed 's/--*/-/g' \
        | sed 's/^-\|-$//g'
}

generate_unique_slug() {
    local prefix="$1"
    local base_slug="$2"
    local slug="$base_slug"
    local counter=1

    while docker ps -a --format '{{.Names}}' | grep -qx "${prefix}-${slug}"; do
        slug="${base_slug}-${counter}"
        ((counter++))
    done

    echo "$slug"
}

generate_project_name() {
    echo "proj-$(openssl rand -hex 4)"
}

ensure_directory_is_clean() {
    local path="$1"

    if [ -f "$path/docker-compose.yml" ]; then
        echo "ERRO: Já existe um site configurado neste diretório:"
        echo "$path"
        exit 1
    fi
}

# =========================================================
# WordPress
# =========================================================

provision_wordpress() {

    local domain="$1"
    local client="$2"
    local subdir="$3"

    local base_slug
    base_slug=$(generate_base_slug "$domain")

    local slug
    slug=$(generate_unique_slug "wp-app" "$base_slug")

    local project_name
    project_name=$(generate_project_name)

    local domain_path="$WEB_ROOT/$client/$subdir"

    ensure_directory_is_clean "$domain_path"

    mkdir -p "$domain_path/db_data"

    local db_pass
    db_pass=$(openssl rand -hex 12)

    local root_pass
    root_pass=$(openssl rand -hex 16)

    cat > "$domain_path/docker-compose.yml" <<EOF
services:
  db:
    image: mariadb:10.11
    container_name: wp-db-${slug}
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${root_pass}
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: ${db_pass}
    volumes:
      - ./db_data:/var/lib/mysql
    networks:
      - wp_net

  wordpress:
    image: wordpress:php8.2-apache
    container_name: wp-app-${slug}
    restart: unless-stopped
    depends_on:
      - db
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: ${db_pass}
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - ./:/var/www/html
    networks:
      - wp_net

networks:
  wp_net:
    name: wp-${slug}-network
    driver: bridge
EOF

    (cd "$domain_path" && docker compose -p "$project_name" up -d)

    echo ""
    echo "WordPress criado com sucesso!"
    echo "Container: wp-app-${slug}"
    echo "Projeto Docker: $project_name"
    echo ""
}

# =========================================================
# Site Estático
# =========================================================

provision_static() {

    local domain="$1"
    local client="$2"
    local subdir="$3"

    local base_slug
    base_slug=$(generate_base_slug "$domain")

    local slug
    slug=$(generate_unique_slug "site-app" "$base_slug")

    local project_name
    project_name=$(generate_project_name)

    local domain_path="$WEB_ROOT/$client/$subdir"

    ensure_directory_is_clean "$domain_path"

    mkdir -p "$domain_path"

    cat > "$domain_path/index.html" <<EOF
<h1>Site ativo</h1>
<p>Domínio: $domain</p>
EOF

    cat > "$domain_path/docker-compose.yml" <<EOF
services:
  static:
    image: nginx:alpine
    container_name: site-app-${slug}
    restart: unless-stopped
    volumes:
      - ./:/usr/share/nginx/html:ro
    networks:
      - static_net

networks:
  static_net:
    name: site-${slug}-network
    driver: bridge
EOF

    (cd "$domain_path" && docker compose -p "$project_name" up -d)

    echo ""
    echo "Site estático criado com sucesso!"
    echo "Container: site-app-${slug}"
    echo "Projeto Docker: $project_name"
    echo ""
}

# =========================================================
# MAIN
# =========================================================

echo ""
read -rp "Cliente: " client
read -rp "Subdiretório: " subdir
read -rp "Domínio: " domain

echo ""
echo "1) WordPress"
echo "2) Site Estático"
read -rp "Escolha [1-2]: " option

case "$option" in
    1) provision_wordpress "$domain" "$client" "$subdir" ;;
    2) provision_static "$domain" "$client" "$subdir" ;;
    *) echo "Opção inválida"; exit 1 ;;
esac

echo "Concluído."
