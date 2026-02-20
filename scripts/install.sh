#!/bin/bash
# =========================================================
# Script de instalação automatizada do AzuraCast + Nginx Proxy Manager
# Automated installation script for AzuraCast + Nginx Proxy Manager
# 
# Copyright (c) 2026 Danilo Ramos
# Licensed under MIT License (automation script only)
# Licenciado sob MIT (apenas script de automação)
# 
# This script installs and configures:
# Este script instala e configura:
# - AzuraCast (Apache 2.0)
#   https://www.azuracast.com
# - Nginx Proxy Manager (MIT)
#   https://nginxproxymanager.com
# - Docker (Apache 2.0)
#   https://www.docker.com
# =========================================================

set -euo pipefail

# ==========================================================
# IMPORTAÇÃO DE BIBLIOTECA COMUM
# ==========================================================
SCRIPT_FILE="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_FILE")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Carregar biblioteca comum
if [ ! -f "${SCRIPT_DIR}/lib/common.sh" ]; then
    echo "[ERRO] Biblioteca comum não encontrada: ${SCRIPT_DIR}/lib/common.sh" >&2
    exit 1
fi

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/common.sh"

# ==========================================================

# ==========================================================
# INSTALAÇÃO DO DOCKER
# ==========================================================
install_docker() {
    log_info "Iniciando instalação do Docker..."
    
    if command_exists docker; then
        log_success "Docker já está instalado: $(docker_version)"
        return 0
    fi
    
    # Remover configurações antigas do Docker ANTES de atualizar pacotes
    log_info "Removendo configurações antigas do Docker..."
    rm -f /etc/apt/sources.list.d/docker.list
    rm -f /etc/apt/keyrings/docker.gpg
    
    log_info "Atualizando pacotes do sistema..."
    apt-get update -qq || { log_error "Falha ao atualizar pacotes"; return 1; }
    
    log_info "Instalando dependências..."
    apt-get install -y -qq ca-certificates curl gnupg lsb-release software-properties-common || \
        { log_error "Falha ao instalar dependências"; return 1; }

    
    log_info "Configurando repositório do Docker..."
    
    # Criar diretório para chaves
    mkdir -p /etc/apt/keyrings
    
    # Adicionar chave GPG do Docker
    log_info "Baixando chave GPG do Docker..."
    if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
         gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null; then
        log_error "Falha ao adicionar chave GPG do Docker."
        return 1
    fi
    
    # Definir permissões corretas para a chave
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    log_success "Chave GPG do Docker adicionada."
    
    # Configurar repositório do Docker
    local arch=$(dpkg --print-architecture)
    local distro=$(lsb_release -cs)
    echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu ${distro} stable" \
        > /etc/apt/sources.list.d/docker.list || \
        { log_error "Falha ao configurar repositório Docker"; return 1; }
    
    log_info "Atualizando índices de pacotes..."
    apt-get update -qq || { log_error "Falha ao atualizar pacotes"; return 1; }
    
    log_info "Instalando Docker Engine, CLI e plugins..."
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin || \
        { log_error "Falha ao instalar Docker"; return 1; }
    
    log_info "Habilitando e iniciando Docker daemon..."
    if ! systemctl enable docker 2>/dev/null; then
        log_error "Falha ao habilitar Docker daemon."
        return 1
    fi
    
    if ! systemctl start docker 2>/dev/null; then
        log_error "Falha ao iniciar Docker daemon."
        return 1
    fi
    
    sleep 2
    log_success "Docker instalado com sucesso: $(docker_version)"
    return 0
}

# ==========================================================
# NGINX PROXY MANAGER
# ==========================================================
setup_nginx_proxy_manager() {
    log_info "Configurando Nginx Proxy Manager..."
    
    # Verificar portas
    for port in "$NPM_ADMIN_PORT" "$NPM_HTTP_PORT" "$NPM_HTTPS_PORT"; do
        if ! check_port_available "$port"; then
            log_error "Porta $port já está em uso. Não é possível continuar."
            return 1
        fi
    done
    
    log_info "Criando diretório da aplicação: $PROXY_MANAGER_DIR"
    mkdir -p "$PROXY_MANAGER_DIR" || { log_error "Falha ao criar diretório"; return 1; }
    
    log_info "Criando docker-compose para Nginx Proxy Manager..."
    cat > "${PROXY_MANAGER_DIR}/docker-compose.yml" <<'EOL' || \
        { log_error "Falha ao criar docker-compose"; return 1; }
version: "3.8"

services:
  app:
    image: jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
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
      DISABLE_IPV6: "true"
    volumes:
      - app_data:/data
      - app_letsencrypt:/etc/letsencrypt
    depends_on:
      - db
    networks:
      - npm_network
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:81/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  db:
    image: mariadb:10.11
    container_name: nginx-proxy-manager-db
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: "npm"
      MYSQL_DATABASE: "npm"
      MYSQL_USER: "npm"
      MYSQL_PASSWORD: "npm"
      MYSQL_INITDB_SKIP_TZINFO: "yes"
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - npm_network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 3

volumes:
  app_data:
  app_letsencrypt:
  db_data:

networks:
  npm_network:
    driver: bridge
EOL
    
    log_info "Iniciando containers do Nginx Proxy Manager..."
    cd "$PROXY_MANAGER_DIR" || { log_error "Falha ao acessar diretório"; return 1; }
    
    if ! docker compose up -d; then
        log_error "Falha ao iniciar containers do Nginx Proxy Manager."
        return 1
    fi
    
    log_info "Aguardando serviços estarem prontos..."
    if ! wait_container_healthy "nginx-proxy-manager" 60; then
        log_error "Nginx Proxy Manager não ficou saudável. Verifique os logs."
        docker compose logs
        return 1
    fi
    
    log_success "Nginx Proxy Manager iniciado com sucesso."
    return 0
}

# ==========================================================
# AZURACAST
# ==========================================================
setup_azuracast() {
    log_info "Configurando AzuraCast..."
    
    log_info "Criando diretório da aplicação: $AZURACAST_DIR"
    mkdir -p "$AZURACAST_DIR" || { log_error "Falha ao criar diretório"; return 1; }
    
    # Parar e remover containers antigos do AzuraCast se existirem
    cd "$AZURACAST_DIR" || { log_error "Falha ao acessar diretório"; return 1; }
    
    if [ -f docker-compose.yml ] || [ -f docker-compose.override.yml ]; then
        log_info "Removendo containers antigos do AzuraCast..."
        docker compose down -v 2>/dev/null || true
        sleep 3
    fi
    
    # Limpar containers órfãos que possam estar usando as portas
    log_info "Limpando containers órfãos..."
    docker ps -a --filter "name=azuracast" --format "{{.ID}}" | xargs -r docker rm -f 2>/dev/null || true
    sleep 2
    
    # Forçar liberação das portas necessárias
    log_info "Verificando e liberando portas necessárias..."
    force_free_port "$AZURACAST_HTTP_PORT" || log_warn "Porta $AZURACAST_HTTP_PORT pode estar em uso"
    force_free_port "$AZURACAST_HTTPS_PORT" || log_warn "Porta $AZURACAST_HTTPS_PORT pode estar em uso"
    
    # Parar qualquer container Docker usando as portas do AzuraCast
    log_info "Parando containers nas portas do AzuraCast..."
    docker ps -q --filter "publish=$AZURACAST_HTTP_PORT" | xargs -r docker stop 2>/dev/null || true
    docker ps -q --filter "publish=$AZURACAST_HTTPS_PORT" | xargs -r docker stop 2>/dev/null || true
    docker ps -aq --filter "publish=$AZURACAST_HTTP_PORT" | xargs -r docker rm -f 2>/dev/null || true
    docker ps -aq --filter "publish=$AZURACAST_HTTPS_PORT" | xargs -r docker rm -f 2>/dev/null || true
    sleep 3
    
    cd "$AZURACAST_DIR" || { log_error "Falha ao acessar diretório"; return 1; }
    
    log_info "Baixando script de instalação do AzuraCast..."
    if ! curl -fsSL https://raw.githubusercontent.com/AzuraCast/AzuraCast/main/docker.sh \
         -o docker.sh; then
        log_error "Falha ao baixar script do AzuraCast."
        return 1
    fi
    
    chmod +x docker.sh || { log_error "Falha ao configurar permissões"; return 1; }
    
    log_info "Configurando instalação automatizada do AzuraCast..."
    log_info "Idioma: Português do Brasil (pt_BR)"
    log_info "Porta HTTP: $AZURACAST_HTTP_PORT"
    log_info "Porta HTTPS: $AZURACAST_HTTPS_PORT"
    log_info "Porta SFTP: 2022"
    log_info "Portas de Estações: $AZURACAST_STATION_PORT_START-$AZURACAST_STATION_PORT_END"
    
    log_info "Executando instalação do AzuraCast..."
    log_info "O instalador usará as portas configuradas automaticamente."
    
    # Preparar respostas para o instalador interativo
    # 1. Idioma: pt_BR
    # 2. Personalizar portas: yes
    # 3. Porta HTTP: $AZURACAST_HTTP_PORT
    # 4. Porta HTTPS: $AZURACAST_HTTPS_PORT
    # 5. Porta SFTP: 2022
    # 6. Porta Station mínima: $AZURACAST_STATION_PORT_START
    # 7. Porta Station máxima: $AZURACAST_STATION_PORT_END
    cat <<EOF | ./docker.sh install
pt_BR
yes
${AZURACAST_HTTP_PORT}
${AZURACAST_HTTPS_PORT}
2022
${AZURACAST_STATION_PORT_START}
${AZURACAST_STATION_PORT_END}
EOF
    
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        log_error "Falha durante instalação do AzuraCast."
        return 1
    fi
    
    log_success "AzuraCast instalado com sucesso!"
    log_info "Aguarde alguns minutos para os serviços iniciarem completamente."
    
    return 0
}

# ==========================================================
# SITE ESTÁTICO
# ==========================================================
setup_static_site() {
    log_info "Configurando container de site estático..."
    
    # Verificar porta
    if ! check_port_available "$STATIC_SITE_PORT"; then
        log_error "Porta $STATIC_SITE_PORT já está em uso."
        return 1
    fi
    
    mkdir -p "$WEB_ROOT" || { log_error "Falha ao criar diretório"; return 1; }
    
    # Verificar se container já existe
    if docker ps -a --format '{{.Names}}' | grep -q '^site-estatico$'; then
        log_info "Container 'site-estatico' já existe. Iniciando..."
        docker start site-estatico >/dev/null 2>&1 || true
    else
        log_info "Criando container de site estático..."
        docker run -d \
            --name site-estatico \
            --restart unless-stopped \
            -p "$STATIC_SITE_PORT:80" \
            -v "$WEB_ROOT:$WEB_ROOT" \
            nginx:alpine || { log_error "Falha ao criar container"; return 1; }
    fi
    
    log_success "Site estático container pronto."
    return 0
}

# ==========================================================
# CRIAR VHOST
# ==========================================================
create_vhost() {
    print_section "CONFIGURAÇÃO DE SITE ESTÁTICO"
    
    local domain=$(prompt_domain)
    
    local domain_path="$WEB_ROOT/$domain"
    log_info "Criando estrutura em $domain_path"
    mkdir -p "$domain_path" || { log_error "Falha ao criar diretório"; return 1; }
    
    # Criar index.html padrão
    cat > "$domain_path/index.html" <<EOF || { log_error "Falha ao criar index.html"; return 1; }
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$domain</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 50px; }
        h1 { color: #333; }
    </style>
</head>
<body>
    <h1>$domain</h1>
    <p>Site estático ativo via AzuraCast Deploy Automation</p>
</body>
</html>
EOF
EOF
    
    log_info "Configurando Nginx com domínio $domain..."
    docker exec site-estatico sh -c "cat > /etc/nginx/conf.d/${domain}.conf" <<EOF || \
        { log_error "Falha ao criar config Nginx"; return 1; }
server {
    listen 80 default_server;
    server_name _;
    return 444;
}

server {
    listen 80;
    server_name ${domain} www.${domain};

    root ${domain_path};
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
EOF
    
    log_info "Testando configuração Nginx..."
    if ! docker exec site-estatico nginx -t > /dev/null 2>&1; then
        log_error "Erro na configuração Nginx."
        return 1
    fi
    
    log_info "Recarregando Nginx..."
    docker exec site-estatico nginx -s reload || { log_error "Falha ao recarregar Nginx"; return 1; }
    
    log_success "Site estático '$domain' criado com sucesso."
    echo "$domain" > /tmp/deployed_domain
    return 0
}

# ==========================================================
# EXIBIR INFORMAÇÕES FINAIS
# ==========================================================
display_summary() {
    local domain=""
    [ -f /tmp/deployed_domain ] && domain=$(cat /tmp/deployed_domain)
    
    local public_ip=$(get_public_ip)
    
    print_info_box "✓ INSTALAÇÃO CONCLUÍDA COM SUCESSO"
    
    if [ -n "$domain" ]; then
        echo "📝 Site Estático: $domain"
        echo "   Diretório: $WEB_ROOT/$domain"
        echo "   Teste: curl -H 'Host: $domain' http://127.0.0.1:${STATIC_SITE_PORT}"
        echo
    fi
    
    echo "🌐 Nginx Proxy Manager"
    echo "   URL: http://$public_ip:$NPM_ADMIN_PORT"
    echo "   Login padrão: admin@example.com / changeme"
    echo
    
    echo "🎙️  AzuraCast"
    echo "   URL direta: http://$public_ip:$AZURACAST_HTTP_PORT"
    echo "   Portas internas: $AZURACAST_HTTP_PORT (HTTP), $AZURACAST_HTTPS_PORT (HTTPS)"
    echo "   Streaming: portas $AZURACAST_STATION_PORT_START-$AZURACAST_STATION_PORT_END"
    echo
    
    echo "----- PRÓXIMOS PASSOS -----"
    echo "1. Acessar painel do Nginx Proxy Manager"
    echo "2. Criar Proxy Hosts para:"
    if [ -n "$domain" ]; then
        echo "   - $domain → http://$public_ip:$STATIC_SITE_PORT"
    fi
    echo "   - azura.seudominio.com → http://$public_ip:$AZURACAST_HTTP_PORT"
    echo "3. Gerar certificados SSL com Let's Encrypt"
    echo "4. Ativar 'Force SSL' nos Proxy Hosts"
    echo
    echo "📋 Logs: $LOG_FILE"
    print_separator
}

# ==========================================================
# FUNÇÃO PRINCIPAL
# ==========================================================
main() {
    # Inicializar logging
    init_logging || { 
        echo "[ERRO] Falha ao inicializar logging" >&2
        exit 1
    }
    
    # Carregar configurações
    load_config
    
    log_info "======================================================="
    log_info "AzuraCast + Nginx Proxy Manager - Instalação"
    log_info "======================================================="
    
    # Validações iniciais
    check_root || exit 1
    check_distribution || exit 1
    check_connectivity || exit 1
    
    # Mostrar configuração
    if [ "${VERBOSE_LOGGING:-0}" = "1" ]; then
        show_config
    fi
    
    # Instalação
    log_info "Iniciando procedimento de instalação..."
    install_docker || { log_error "Instalação do Docker falhou"; exit 1; }
    setup_nginx_proxy_manager || { log_error "Setup Nginx Proxy Manager falhou"; exit 1; }
    setup_azuracast || { log_error "Setup AzuraCast falhou"; exit 1; }
    setup_static_site || { log_error "Setup site estático falhou"; exit 1; }
    
    # Criar vhost (opcional)
    if [ "${PROMPT_FOR_DOMAIN:-1}" = "1" ]; then
        create_vhost || log_warn "Falha na criação do vhost, continuando..."
    fi
    
    # Resumo final
    display_summary
    
    log_success "Instalação concluída com sucesso!"
    log_info "Logs armazenados em: $LOG_FILE"
}

# Execução
main "$@"

