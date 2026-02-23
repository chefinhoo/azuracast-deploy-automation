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
# - Roundcube Webmail (GPL 3.0)
#   https://roundcube.net
# - Filebrowser (Apache 2.0)
#   https://filebrowser.org
# - Docker (Apache 2.0)
#   https://www.docker.com
#
# =========================================================
# CONFIGURAÇÕES OPCIONAIS
# =========================================================
#
# SERVIÇOS ADICIONAIS:
#   export INSTALL_WEBMAIL=1
#     Instala Roundcube para gerenciar emails
#     Requer SMTP configurado (veja WEBMAIL_SETUP.md)
#     Padrão: 1 (habilitado)
#
#   export INSTALL_FILEMANAGER=1
#     Instala Filebrowser para gerenciar arquivos
#     Acesso unificado a WordPress, AzuraCast e arquivos
#     Padrão: 1 (habilitado)
#
# FIREWALL:
#   export BLOCK_DIRECT_AZURACAST_ACCESS=1
#     Bloqueia acesso direto às portas do AzuraCast por IP
#     Força uso de Nginx Proxy Manager (domínio) para acesso
#     Localhost (127.0.0.1) permanece sempre permitido para diagnóstico
#     Padrão: 0 (desabilitado - portas abertas)
#
#   export FIREWALL_INTERFACE=eth0
#     Bloqueia portas apenas na interface específica
#     Se não definido, bloqueia em todas as interfaces (exceto loopback)
#
# DESATIVAR HARDENING DE REDE PÓS-INSTALAÇÃO:
#   export DISABLE_NETWORK_HARDENING=1
#     Desativa todas as regras de firewall durante instalação
#
# =========================================================
# PÓS-INSTALAÇÃO - GERENCIAR FIREWALL
# =========================================================
#
# Após a instalação, use o script manage_firewall.sh para:
#
#   sudo bash manage_firewall.sh
#     Menu interativo com opções de bloquear/desbloquear/status
#
#   sudo bash manage_firewall.sh status
#     Verifica status atual das portas (bloqueadas ou abertas)
#
#   sudo bash manage_firewall.sh block
#     Bloqueia portas 8080, 8043, 2022, 9000-9999
#     Recomendado para PRODUÇÃO
#
#   sudo bash manage_firewall.sh unblock
#     Desbloqueia portas (acesso direto por IP)
#     Recomendado para DESENVOLVIMENTO
#
# Variáveis de ambiente (opcional):
#   export FIREWALL_INTERFACE=eth0
#     Aplica bloqueio/desbloqueio apenas nesta interface
#
# =========================================================
#
# =========================================================

set -euo pipefail

# ==========================================================
# IMPORTAÇÃO DE BIBLIOTECA COMUM
# ==========================================================
SCRIPT_FILE="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_FILE")" && pwd)"

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
    rm -f /etc/apt/sources.list.d/docker-ce.list
    rm -f /etc/apt/sources.list.d/docker.sources
    rm -f /etc/apt/sources.list.d/docker-ce.sources
    rm -f /etc/apt/keyrings/docker.gpg
    rm -f /etc/apt/keyrings/docker.asc

    # Limpar entradas antigas do Docker em arquivos .list/.sources para evitar erro NO_PUBKEY
    if [ -d /etc/apt/sources.list.d ]; then
        find /etc/apt/sources.list.d -type f \( -name "*.list" -o -name "*.sources" \) -print0 2>/dev/null | \
            while IFS= read -r -d '' src_file; do
                if grep -q "download\.docker\.com" "$src_file" 2>/dev/null; then
                    sed -i '/download\.docker\.com/d' "$src_file" 2>/dev/null || true
                fi
            done
    fi

    if [ -f /etc/apt/sources.list ] && grep -q "download\.docker\.com" /etc/apt/sources.list 2>/dev/null; then
        sed -i '/download\.docker\.com/d' /etc/apt/sources.list 2>/dev/null || true
    fi
    
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
    local arch
    local distro
    arch="$(dpkg --print-architecture)"
    distro="$(lsb_release -cs)"
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
    deploy:
      resources:
        limits:
          memory: 1024M
        reservations:
          memory: 256M
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
    command: 
      - --max_connections=200
      - --innodb_buffer_pool_size=256M
      - --innodb_log_file_size=64M
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
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
    
    # Criar configurações customizadas do Nginx para performance
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
    
    local station_ports_csv=""
    station_ports_csv="$(generate_station_ports_csv "$AZURACAST_STATION_PORT_START" "$AZURACAST_STATION_PORT_END")" || {
        log_error "Falha ao gerar lista de portas de estação"
        return 1
    }
    
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
    # 1. Release channel: não trocar (n)
    # 2. Idioma: pt_BR
    # 3. Personalizar portas: yes
    # 4. Porta HTTP: $AZURACAST_HTTP_PORT
    # 5. Porta HTTPS: $AZURACAST_HTTPS_PORT
    # 6. Porta SFTP: 2022
    # 7. Porta Station mínima: $AZURACAST_STATION_PORT_START
    # 8. Porta Station máxima: $AZURACAST_STATION_PORT_END
    # 9. Atualizações de imagem via web: yes
    # 10. Bloqueio de bots/rastreadores: no
    cat <<EOF | ./docker.sh install
n
pt_BR
yes
${AZURACAST_HTTP_PORT}
${AZURACAST_HTTPS_PORT}
2022
${AZURACAST_STATION_PORT_START}
${AZURACAST_STATION_PORT_END}
yes
no
EOF
    
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
        log_error "Falha durante instalação do AzuraCast."
        return 1
    fi
    
    log_success "AzuraCast instalado!"
    
    # O docker.sh deveria ter criado docker-compose.yml, mas caso não tenha, baixar do repositório
    log_info "Verificando arquivo docker-compose.yml..."
    if [ ! -f "$AZURACAST_DIR/docker-compose.yml" ]; then
        log_info "Arquivo docker-compose.yml não encontrado. Baixando docker-compose.sample.yml..."
        if curl -fsSL https://raw.githubusercontent.com/AzuraCast/AzuraCast/main/docker-compose.sample.yml \
                -o "$AZURACAST_DIR/docker-compose.yml"; then
            log_success "docker-compose.yml baixado e configurado com sucesso"
        else
            log_error "Falha ao baixar docker-compose.sample.yml"
            return 1
        fi
    else
        log_success "docker-compose.yml encontrado"
    fi
    
    # Verificar se o arquivo azuracast.env existe (necessário para o docker-compose)
    log_info "Verificando arquivo azuracast.env..."
    if [ ! -f "$AZURACAST_DIR/azuracast.env" ]; then
        log_info "Criando arquivo azuracast.env..."
        touch "$AZURACAST_DIR/azuracast.env" || {
            log_error "Falha ao criar azuracast.env"
            return 1
        }
        log_success "Arquivo azuracast.env criado"
    else
        log_success "Arquivo azuracast.env existe"
    fi
    
    # Corrigir portas de estações hardcoded no docker-compose.yml
    log_info "Corrigindo portas de estações no docker-compose.yml..."
    if [ -f "$AZURACAST_DIR/docker-compose.yml" ]; then
        # Fazer backup do docker-compose.yml
        cp "$AZURACAST_DIR/docker-compose.yml" "$AZURACAST_DIR/docker-compose.yml.backup-$(date +%Y%m%d-%H%M%S)"
        
        # Remover portas hardcoded de estações (8000-9999), preservando HTTP/HTTPS/SFTP.
        # Isso evita que um docker-compose gerado com portas padrão (8000+) ignore o .env.
        local compose_tmp="${AZURACAST_DIR}/docker-compose.yml.tmp"
        awk -v http_port="$AZURACAST_HTTP_PORT" -v https_port="$AZURACAST_HTTPS_PORT" -v sftp_port="2022" '
            {
                if (match($0, /^[[:space:]]*-[[:space:]]'"'"'([0-9]{4}):([0-9]{4})'"'"'[[:space:]]*$/, m)) {
                    port=m[1]+0
                    if (port >= 8000 && port <= 9999 && port != http_port && port != https_port && port != sftp_port) {
                        next
                    }
                }
                print
            }
        ' "$AZURACAST_DIR/docker-compose.yml" > "$compose_tmp" && mv "$compose_tmp" "$AZURACAST_DIR/docker-compose.yml"
        
        log_success "Portas hardcoded removidas do docker-compose.yml"
        log_info "As portas de estações ${AZURACAST_STATION_PORT_START}-${AZURACAST_STATION_PORT_END} serão gerenciadas pelo AzuraCast automaticamente"
    else
        log_warn "docker-compose.yml não encontrado, pulando correção de portas"
    fi
    
    # Verificar e corrigir portas no arquivo .env
    log_info "Verificando configuração de portas no arquivo .env..."
    if [ -f "$AZURACAST_DIR/.env" ]; then
        # Verificar se as portas estão corretas
        local current_http
        local current_https
        current_http="$(grep "^AZURACAST_HTTP_PORT=" "$AZURACAST_DIR/.env" | cut -d= -f2)"
        current_https="$(grep "^AZURACAST_HTTPS_PORT=" "$AZURACAST_DIR/.env" | cut -d= -f2)"
        
        if [ "$current_http" != "$AZURACAST_HTTP_PORT" ] || [ "$current_https" != "$AZURACAST_HTTPS_PORT" ]; then
            log_warn "Portas no .env não correspondem às configuradas. Corrigindo..."
            
            # Fazer backup do .env
            cp "$AZURACAST_DIR/.env" "$AZURACAST_DIR/.env.backup"
            
            # Corrigir portas
            sed -i "s/^AZURACAST_HTTP_PORT=.*/AZURACAST_HTTP_PORT=${AZURACAST_HTTP_PORT}/" "$AZURACAST_DIR/.env"
            sed -i "s/^AZURACAST_HTTPS_PORT=.*/AZURACAST_HTTPS_PORT=${AZURACAST_HTTPS_PORT}/" "$AZURACAST_DIR/.env"
            
            # Se AZURACAST_STATION_PORTS não existir, adicionar
            if ! grep -q "^AZURACAST_STATION_PORTS=" "$AZURACAST_DIR/.env"; then
                echo "AZURACAST_STATION_PORTS=${station_ports_csv}" >> "$AZURACAST_DIR/.env"
            else
                sed -i "s/^AZURACAST_STATION_PORTS=.*/AZURACAST_STATION_PORTS=${station_ports_csv}/" "$AZURACAST_DIR/.env"
            fi

            if grep -q "^AZURACAST_VERSION=" "$AZURACAST_DIR/.env"; then
                sed -i "s/^AZURACAST_VERSION=.*/AZURACAST_VERSION=stable/" "$AZURACAST_DIR/.env"
            else
                echo "AZURACAST_VERSION=stable" >> "$AZURACAST_DIR/.env"
            fi

            if ! grep -q "^COMPOSE_PROJECT_NAME=" "$AZURACAST_DIR/.env"; then
                echo "COMPOSE_PROJECT_NAME=azuracast" >> "$AZURACAST_DIR/.env"
            fi

            if ! grep -q "^COMPOSE_HTTP_TIMEOUT=" "$AZURACAST_DIR/.env"; then
                echo "COMPOSE_HTTP_TIMEOUT=300" >> "$AZURACAST_DIR/.env"
            fi

            if ! grep -q "^NGINX_TIMEOUT=" "$AZURACAST_DIR/.env"; then
                echo "NGINX_TIMEOUT=1800" >> "$AZURACAST_DIR/.env"
            fi
            
            log_success "Portas corrigidas no arquivo .env"
            
            # Evitar down/up imediato aqui para não interromper bootstrap inicial do MariaDB.
            # A subida/reconciliação dos containers acontece no bloco "Iniciando containers do AzuraCast".
            log_info "Alterações no .env serão aplicadas na próxima subida/reconciliação dos containers."
        else
            log_success "Portas no .env estão corretas!"

            # Garantir valores essenciais mesmo quando as portas já estiverem corretas.
            if grep -q "^AZURACAST_VERSION=" "$AZURACAST_DIR/.env"; then
                sed -i "s/^AZURACAST_VERSION=.*/AZURACAST_VERSION=stable/" "$AZURACAST_DIR/.env"
            else
                echo "AZURACAST_VERSION=stable" >> "$AZURACAST_DIR/.env"
            fi

            if ! grep -q "^COMPOSE_PROJECT_NAME=" "$AZURACAST_DIR/.env"; then
                echo "COMPOSE_PROJECT_NAME=azuracast" >> "$AZURACAST_DIR/.env"
            fi

            if ! grep -q "^COMPOSE_HTTP_TIMEOUT=" "$AZURACAST_DIR/.env"; then
                echo "COMPOSE_HTTP_TIMEOUT=300" >> "$AZURACAST_DIR/.env"
            fi

            if ! grep -q "^NGINX_TIMEOUT=" "$AZURACAST_DIR/.env"; then
                echo "NGINX_TIMEOUT=1800" >> "$AZURACAST_DIR/.env"
            fi

            if grep -q "^AZURACAST_STATION_PORTS=" "$AZURACAST_DIR/.env"; then
                sed -i "s/^AZURACAST_STATION_PORTS=.*/AZURACAST_STATION_PORTS=${station_ports_csv}/" "$AZURACAST_DIR/.env"
            else
                echo "AZURACAST_STATION_PORTS=${station_ports_csv}" >> "$AZURACAST_DIR/.env"
            fi
        fi
    else
        log_error "Arquivo .env não encontrado!"
        return 1
    fi
    
    log_info "Aguardando serviços iniciarem..."
    sleep 5
    
    # Iniciar containers do AzuraCast se estiverem parados
    log_info "Iniciando containers do AzuraCast..."
    if [ -f "$AZURACAST_DIR/docker-compose.yml" ]; then
        if (cd "$AZURACAST_DIR" && docker compose up -d 2>/dev/null); then
            log_success "Containers iniciados"
            sleep 10
        else
            log_warn "Não conseguiu iniciar containers via docker compose"
        fi
    else
        log_error "docker-compose.yml não encontrado. Não é possível iniciar containers"
    fi
    
    sleep 5
    
    # Verificar containers e portas
    log_info "Verificando containers do AzuraCast..."
    show_containers_status
    
    # Verificar portas configuradas
    log_info "Verificando configuração de portas..."
    if [ -f "$AZURACAST_DIR/.env" ]; then
        log_info "Configuração de portas no arquivo .env:"
        echo ""
        grep "^AZURACAST_HTTP_PORT=" "$AZURACAST_DIR/.env" 2>/dev/null || echo "  AZURACAST_HTTP_PORT=não encontrado"
        grep "^AZURACAST_HTTPS_PORT=" "$AZURACAST_DIR/.env" 2>/dev/null || echo "  AZURACAST_HTTPS_PORT=não encontrado"
        grep "^AZURACAST_SFTP_PORT=" "$AZURACAST_DIR/.env" 2>/dev/null || echo "  AZURACAST_SFTP_PORT=não encontrado"
        grep "^AZURACAST_STATION_PORTS=" "$AZURACAST_DIR/.env" 2>/dev/null || echo "  AZURACAST_STATION_PORTS=não encontrado"
        echo ""
    fi
    
    # Verificar container web
    local web_container
    web_container="$(docker ps --filter "name=azuracast" --filter "status=running" --format "{{.Names}}" | grep -E "azuracast|web" | head -1)"
    if [ -n "$web_container" ]; then
        log_success "Container web encontrado: $web_container"
        check_container_ports "$web_container"
    else
        log_warn "Container web do AzuraCast não encontrado em execução"
    fi
    
    log_info "Aguarde alguns minutos para os serviços iniciarem completamente."
    
    return 0
}

# ==========================================================
# CONECTAR NPM À REDE DO AZURACAST
# ==========================================================
connect_npm_to_azuracast_network() {
    log_info "Conectando Nginx Proxy Manager à rede do AzuraCast..."

    if ! docker ps --format '{{.Names}}' | grep -qx "nginx-proxy-manager"; then
        log_warn "Container nginx-proxy-manager não está em execução. Pulando conexão de rede."
        return 0
    fi

    if ! docker ps --format '{{.Names}}' | grep -qx "azuracast"; then
        log_warn "Container azuracast não está em execução. Pulando conexão de rede."
        return 0
    fi

    local azuracast_network
    azuracast_network="$(docker inspect -f '{{range $name, $_ := .NetworkSettings.Networks}}{{println $name}}{{end}}' azuracast 2>/dev/null | head -1 | tr -d '[:space:]')"

    if [ -z "$azuracast_network" ]; then
        log_warn "Não foi possível identificar a rede do AzuraCast."
        return 0
    fi

    if docker inspect -f '{{range $name, $_ := .NetworkSettings.Networks}}{{println $name}}{{end}}' nginx-proxy-manager 2>/dev/null | grep -qx "$azuracast_network"; then
        log_success "Nginx Proxy Manager já está conectado à rede: $azuracast_network"
    else
        if docker network connect "$azuracast_network" nginx-proxy-manager 2>/dev/null; then
            log_success "Nginx Proxy Manager conectado à rede: $azuracast_network"
        else
            log_warn "Falha ao conectar Nginx Proxy Manager na rede $azuracast_network"
            return 0
        fi
    fi

    if docker exec nginx-proxy-manager sh -lc "curl -s -o /dev/null -w '%{http_code}' --max-time 8 http://azuracast:${AZURACAST_HTTP_PORT}" 2>/dev/null | grep -Eq '^(200|301|302)$'; then
        log_success "Conectividade interna NPM -> azuracast:${AZURACAST_HTTP_PORT} validada"
    else
        log_warn "Não foi possível validar conectividade NPM -> azuracast:${AZURACAST_HTTP_PORT}. Verifique manualmente."
    fi

    return 0
}

# ==========================================================
# HARDENING DE REDE
# ==========================================================
apply_azuracast_network_hardening() {
    if [ "${DISABLE_NETWORK_HARDENING:-0}" = "1" ]; then
        log_info "Hardening de rede desativado para ambiente de teste (DISABLE_NETWORK_HARDENING=1)."
        return 0
    fi

    if [ "${BLOCK_DIRECT_AZURACAST_ACCESS:-1}" != "1" ]; then
        log_info "Bloqueio de acesso direto por IP desativado (BLOCK_DIRECT_AZURACAST_ACCESS=0)."
        return 0
    fi

    if ! command_exists iptables; then
        log_warn "iptables não encontrado. Pulando hardening de rede."
        return 0
    fi

    local iface="${FIREWALL_INTERFACE:-}"

    add_drop_rule_v4() {
        local chain="$1"
        local port_spec="$2"
        local rule_args=()
        if [ -n "$iface" ]; then
            rule_args=( -i "$iface" )
        elif [ "$chain" = "INPUT" ]; then
            # Não bloquear tráfego local (localhost/loopback).
            # Mantém testes com curl http://127.0.0.1:<porta> funcionando.
            rule_args=( ! -i lo )
        fi

        if iptables -C "$chain" "${rule_args[@]}" -p tcp --dport "$port_spec" -j DROP >/dev/null 2>&1; then
            log_debug "Regra IPv4 já existe em $chain para porta(s): $port_spec"
        else
            iptables -I "$chain" 1 "${rule_args[@]}" -p tcp --dport "$port_spec" -j DROP
            log_info "Regra IPv4 aplicada em $chain para bloquear porta(s): $port_spec"
        fi
    }

    add_drop_rule_v6() {
        local chain="$1"
        local port_spec="$2"
        local rule_args=()

        if ! command_exists ip6tables; then
            return 0
        fi

        if ! ip6tables -nL "$chain" >/dev/null 2>&1; then
            return 0
        fi

        if [ -n "$iface" ]; then
            rule_args=( -i "$iface" )
        elif [ "$chain" = "INPUT" ]; then
            # Preservar tráfego local IPv6 (::1/loopback)
            rule_args=( ! -i lo )
        fi

        if ip6tables -C "$chain" "${rule_args[@]}" -p tcp --dport "$port_spec" -j DROP >/dev/null 2>&1; then
            log_debug "Regra IPv6 já existe em $chain para porta(s): $port_spec"
        else
            ip6tables -I "$chain" 1 "${rule_args[@]}" -p tcp --dport "$port_spec" -j DROP
            log_info "Regra IPv6 aplicada em $chain para bloquear porta(s): $port_spec"
        fi
    }

    add_drop_rule() {
        local port_spec="$1"

        if iptables -nL DOCKER-USER >/dev/null 2>&1; then
            add_drop_rule_v4 "DOCKER-USER" "$port_spec"
        fi

        add_drop_rule_v4 "INPUT" "$port_spec"

        add_drop_rule_v6 "DOCKER-USER" "$port_spec"
        add_drop_rule_v6 "INPUT" "$port_spec"
    }

    log_info "Hardening de rede desativado por padrão - portas abertas para acesso direto."
    log_info "Para bloquear acesso direto (recomendado em produção), defina:"
    log_info "  export BLOCK_DIRECT_AZURACAST_ACCESS=1"
    log_info "  sudo bash scripts/install.sh"
    return 0
}

# ==========================================================
# WORDPRESS
# ==========================================================
setup_static_site() {
    log_info "Preparando ambiente WordPress..."

    mkdir -p "$WEB_ROOT" || { log_error "Falha ao criar diretório"; return 1; }
    
    log_success "Ambiente WordPress preparado."
    return 0
}

# ==========================================================
# ROUNDCUBE WEBMAIL
# ==========================================================
setup_webmail() {
    local install_webmail
    install_webmail="${INSTALL_WEBMAIL:-1}"
    
    if [ "$install_webmail" != "1" ]; then
        log_info "Webmail desabilitado (INSTALL_WEBMAIL=0)"
        return 0
    fi
    
    log_info "Instalando Roundcube Webmail..."
    
    local webmail_dir="/var/webmail"
    mkdir -p "$webmail_dir" || { log_error "Falha ao criar diretório"; return 1; }
    
    cd "$webmail_dir" || { log_error "Falha ao acessar diretório"; return 1; }
    
    # Banco de dados para Roundcube
    local webmail_db_pass="roundcube_$(openssl rand -hex 8)"
    
    cat > "$webmail_dir/docker-compose.yml" <<'EOL'
services:
  webmail-db:
    image: mariadb:10.11
    container_name: webmail-db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: "roundcube_root_change_me"
      MYSQL_DATABASE: "roundcubemail"
      MYSQL_USER: "roundcube"
      MYSQL_PASSWORD: "roundcube_change_me"
      MYSQL_INITDB_SKIP_TZINFO: "yes"
    volumes:
      - webmail_db_data:/var/lib/mysql
    networks:
      - webmail_network

  webmail:
    image: roundcube/roundcubemail:latest-fpm
    container_name: webmail
    restart: unless-stopped
    environment:
      ROUNDCUBEMAIL_DB_TYPE: "mysql"
      ROUNDCUBEMAIL_DB_HOST: "webmail-db"
      ROUNDCUBEMAIL_DB_USER: "roundcube"
      ROUNDCUBEMAIL_DB_PASSWORD: "roundcube_change_me"
      ROUNDCUBEMAIL_DB_NAME: "roundcubemail"
      ROUNDCUBEMAIL_SMTP_SERVER: "localhost"
      ROUNDCUBEMAIL_SMTP_PORT: "587"
      ROUNDCUBEMAIL_IMAP_HOST: "localhost"
      ROUNDCUBEMAIL_IMAP_PORT: "143"
      ROUNDCUBEMAIL_PLUGINS: "archive,zipdownload"
    volumes:
      - webmail_data:/var/www/html
    depends_on:
      - webmail-db
    networks:
      - webmail_network

  webmail-nginx:
    image: nginx:latest
    container_name: webmail-nginx
    restart: unless-stopped
    ports:
      - "9000:80"
    volumes:
      - webmail_data:/var/www/html:ro
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - webmail
    networks:
      - webmail_network

volumes:
  webmail_data:
  webmail_db_data:

networks:
  webmail_network:
    driver: bridge
EOL

    # Configuração NGINX para Roundcube
    cat > "$webmail_dir/nginx.conf" <<'NGINX_EOL'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;
    sendfile on;
    tcp_nopush on;
    keepalive_timeout 65;
    gzip on;

    upstream webmail_backend {
        server webmail:9000;
    }

    server {
        listen 80;
        server_name _;
        root /var/www/html;

        index index.php index.html;

        location ~ \.php$ {
            fastcgi_pass webmail_backend;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
        }

        location ~ /\. {
            deny all;
        }
    }
}
NGINX_EOL

    log_info "Iniciando containers de Webmail..."
    if docker compose up -d; then
        log_success "Roundcube instalado com sucesso"
        sleep 5
        echo "webmail" >> /tmp/deployed_services
    else
        log_error "Falha ao iniciar Roundcube"
        return 1
    fi
    
    log_info "Próximos passos para Roundcube:"
    log_info "  1. Configurar SMTP/IMAP no Nginx Proxy Manager"
    log_info "  2. Acessar: http://seu-dominio.com/webmail (via proxy)"
    log_info "  3. Editar /var/webmail/docker-compose.yml com credenciais SMTP/IMAP"
    log_info "  4. Reiniciar: cd /var/webmail && docker compose restart"
    
    return 0
}

# ==========================================================
# FILEBROWSER - GERENCIADOR DE ARQUIVOS
# ==========================================================
setup_filemanager() {
    local install_filemanager
    install_filemanager="${INSTALL_FILEMANAGER:-1}"
    
    if [ "$install_filemanager" != "1" ]; then
        log_info "Gerenciador de arquivos desabilitado (INSTALL_FILEMANAGER=0)"
        return 0
    fi
    
    log_info "Instalando Filebrowser..."
    
    local filemanager_dir="/var/filemanager"
    mkdir -p "$filemanager_dir/root" || { log_error "Falha ao criar diretório"; return 1; }
    
    cd "$filemanager_dir" || { log_error "Falha ao acessar diretório"; return 1; }
    
    cat > "$filemanager_dir/docker-compose.yml" <<'EOL'
services:
  filemanager:
    image: filebrowser/filebrowser:latest
    container_name: filemanager
    restart: unless-stopped
    ports:
      - "9001:80"
    volumes:
      - ./root:/srv
      - ./filebrowser.db:/database.db
      - ./settings.json:/etc/config/settings.json
      - /var/www:/var/www:rw
      - /var/azuracast:/var/azuracast:rw
    networks:
      - filemanager_network

volumes:
  filebrowser_data:

networks:
  filemanager_network:
    driver: bridge
EOL

    # Configuração do Filebrowser
    cat > "$filemanager_dir/settings.json" <<'JSON_EOL'
{
  "auth": {
    "method": "simple"
  },
  "branding": {
    "name": "Gerenciador de Arquivos"
  },
  "commands": {},
  "editors": {
    "editormd": {
      "extensions": ["md", "markdown", "mdown", "mkd", "mkdn"]
    }
  },
  "rules": [],
  "shell": [],
  "signup": false,
  "username": "admin",
  "password": "password"
}
JSON_EOL

    log_info "Iniciando containers de Gerenciador de Arquivos..."
    if docker compose up -d; then
        log_success "Filebrowser instalado com sucesso"
        sleep 3
        echo "filemanager" >> /tmp/deployed_services
    else
        log_error "Falha ao iniciar Filebrowser"
        return 1
    fi
    
    log_info "Próximos passos para Filebrowser:"
    log_info "  1. Configurar domínio no Nginx Proxy Manager"
    log_info "  2. Acessar: http://seu-dominio.com/files"
    log_info "  3. Login padrão: admin / password"
    log_info "  4. IMPORTANTE: Alterar senha em Settings"
    log_info "  5. Configurar permissões de pastas em Settings > Rules"
    
    return 0
}

# ==========================================================
# CONFIGURAR WORDPRESS
# ==========================================================
create_vhost() {
    print_section "CONFIGURAÇÃO DE WORDPRESS"
    
    local domain
    domain="$(prompt_domain)"
    local domain_slug="${domain//./-}"
    local wp_container_name="wp-app-${domain_slug}"
    local wp_db_container_name="wp-db-${domain_slug}"
    local wp_network_name="wp-${domain_slug}-network"
    
    local domain_path="$WEB_ROOT/$domain"
    log_info "Criando estrutura em $domain_path"
    mkdir -p "$domain_path/html" "$domain_path/db_data" || { log_error "Falha ao criar diretório"; return 1; }

    local creds_file
    creds_file="$domain_path/wordpress-credentials.txt"

    local wp_db_name="wordpress"
    local wp_db_user="wordpress"
    local wp_db_password
    local wp_db_root_password

    if [ -f "$creds_file" ]; then
        log_info "Credenciais existentes encontradas. Reutilizando para evitar conflito com banco persistente."

        local loaded_db_name
        local loaded_db_user
        local loaded_db_password
        local loaded_db_root_password

        loaded_db_name="$(grep '^WORDPRESS_DB_NAME=' "$creds_file" | tail -1 | cut -d= -f2-)"
        loaded_db_user="$(grep '^WORDPRESS_DB_USER=' "$creds_file" | tail -1 | cut -d= -f2-)"
        loaded_db_password="$(grep '^WORDPRESS_DB_PASSWORD=' "$creds_file" | tail -1 | cut -d= -f2-)"
        loaded_db_root_password="$(grep '^WORDPRESS_DB_ROOT_PASSWORD=' "$creds_file" | tail -1 | cut -d= -f2-)"

        [ -n "$loaded_db_name" ] && wp_db_name="$loaded_db_name"
        [ -n "$loaded_db_user" ] && wp_db_user="$loaded_db_user"
        [ -n "$loaded_db_password" ] && wp_db_password="$loaded_db_password"
        [ -n "$loaded_db_root_password" ] && wp_db_root_password="$loaded_db_root_password"
    fi

    if [ -z "${wp_db_password:-}" ]; then
        wp_db_password="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)"
    fi

    if [ -z "${wp_db_root_password:-}" ]; then
        wp_db_root_password="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)"
    fi

    local wp_compose_file="$domain_path/docker-compose.yml"
    cat > "$wp_compose_file" <<EOF || { log_error "Falha ao criar docker-compose do WordPress"; return 1; }
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
      - ./html:/var/www/html
      - ./php-custom.ini:/usr/local/etc/php/conf.d/custom.ini:ro
    networks:
      - wp_network

networks:
  wp_network:
    name: ${wp_network_name}
    driver: bridge
EOF

    # Criar configuração PHP otimizada
    log_info "Criando configurações PHP otimizadas..."
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

    # Criar .htaccess otimizado
    log_info "Criando .htaccess otimizado..."
    cat > "$domain_path/html/.htaccess" <<'HTACCESS_EOF'
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
RewriteRule ^index\\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
HTACCESS_EOF

    log_success "Configurações otimizadas criadas"

    log_info "Iniciando stack WordPress..."
    if ! (cd "$domain_path" && docker compose up -d); then
        log_error "Falha ao iniciar stack WordPress"
        return 1
    fi

    # Conectar NPM na rede do WordPress para proxy interno sem exposição de porta pública.
    if docker ps --format '{{.Names}}' | grep -qx "nginx-proxy-manager"; then
        if docker inspect -f '{{range $name, $_ := .NetworkSettings.Networks}}{{println $name}}{{end}}' nginx-proxy-manager 2>/dev/null | grep -qx "$wp_network_name"; then
            log_success "Nginx Proxy Manager já está conectado à rede do WordPress: $wp_network_name"
        else
            if docker network connect "$wp_network_name" nginx-proxy-manager 2>/dev/null; then
                log_success "Nginx Proxy Manager conectado à rede do WordPress: $wp_network_name"
            else
                log_warn "Falha ao conectar Nginx Proxy Manager na rede $wp_network_name"
            fi
        fi

        if docker exec nginx-proxy-manager sh -lc "curl -s -o /dev/null -w '%{http_code}' --max-time 8 http://${wp_container_name}:80" 2>/dev/null | grep -Eq '^(200|301|302)$'; then
            log_success "Conectividade interna NPM -> ${wp_container_name}:80 validada"
        else
            log_warn "Não foi possível validar conectividade NPM -> ${wp_container_name}:80"
        fi
    else
        log_warn "Container nginx-proxy-manager não encontrado; conexão de rede do WordPress não aplicada."
    fi

    cat > "$creds_file" <<EOF || { log_error "Falha ao salvar credenciais do WordPress"; return 1; }
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

    log_success "WordPress '$domain' configurado com sucesso."
    echo "$domain" > /tmp/deployed_domain
    return 0
}

# ==========================================================
# EXIBIR INFORMAÇÕES FINAIS
# ==========================================================
display_summary() {
    local domain=""
    [ -f /tmp/deployed_domain ] && domain=$(cat /tmp/deployed_domain)
    
    local public_ip
    public_ip="$(get_public_ip)"
    
    print_info_box "✓ INSTALAÇÃO CONCLUÍDA COM SUCESSO"
    
    if [ -n "$domain" ]; then
        echo "📝 WordPress: $domain"
        echo "   Diretório: $WEB_ROOT/$domain"
        echo "   Credenciais DB: $WEB_ROOT/$domain/wordpress-credentials.txt"
        echo "   Proxy interno: wp-app-${domain//./-}:80 (sem porta pública)"
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
    if [ "${BLOCK_DIRECT_AZURACAST_ACCESS:-1}" = "1" ]; then
        echo "   Segurança: acesso direto por IP bloqueado para AzuraCast (usar domínio/proxy)"
    fi
    echo
    
    echo "📧 Roundcube Webmail"
    echo "   Tipo: Gerenciador de emails via navegador"
    echo "   Diretório: /var/webmail"
    echo "   Status: Instalado (configure SMTP/IMAP)"
    echo "   Acessar via Nginx Proxy Manager: https://webmail.$domain"
    echo
    
    echo "📁 Filebrowser"
    echo "   Tipo: Gerenciador unificado de arquivos"
    echo "   Diretório: /var/filemanager"
    echo "   Acesso a: WordPress, AzuraCast, arquivos do sistema"
    echo "   Acessar via Nginx Proxy Manager: https://files.$domain"
    echo
    
    echo "----- PRÓXIMOS PASSOS -----"
    echo "1. Acessar painel do Nginx Proxy Manager"
    echo "2. Criar Proxy Hosts para:"
    if [ -n "$domain" ]; then
        echo "   - $domain → http://wp-app-${domain//./-}:80"
        echo "     (Use o nome do container, não localhost/IP)"
        echo ""
        echo "   - azura.$domain → http://azuracast:$AZURACAST_HTTP_PORT"
        echo "     (Use 'azuracast', não localhost/IP)"
        echo ""
        echo "   - webmail.$domain → http://webmail-nginx:80"
        echo "     (Para Roundcube)"
        echo ""
        echo "   - files.$domain → http://filemanager:80"
        echo "     (Para Filebrowser)"
    else
        echo "   - seudominio.com → http://azuracast:$AZURACAST_HTTP_PORT"
        echo "     (Use 'azuracast', não localhost/IP)"
        echo "   - webmail.seudominio.com → http://webmail-nginx:80"
        echo "   - files.seudominio.com → http://filemanager:80"
    fi
    echo "3. Gerar certificados SSL com Let's Encrypt"
    echo "4. Ativar 'Force SSL' nos Proxy Hosts"
    echo ""
    echo "5. IMPORTANTE - Configurar Roundcube:"
    echo "   - Editar: /var/webmail/docker-compose.yml"
    echo "   - Definir SMTP_SERVER e IMAP_HOST"
    echo "   - Reiniciar: cd /var/webmail && docker compose restart"
    echo "   - Ver: WEBMAIL_SETUP.md"
    echo ""
    echo "6. IMPORTANTE - Configurar Filebrowser:"
    echo "   - Acessar: https://files.$domain"
    echo "   - Login padrão: admin / password"
    echo "   - Alterar senha em Settings"
    echo "   - Ver: FILEMANAGER_SETUP.md"
    echo
    echo "� GERENCIAMENTO DE FIREWALL"
    echo "   As portas estão ABERTAS por padrão (acesso direto por IP permitido)"
    echo ""
    echo "   Para PRODUÇÃO, recomenda-se BLOQUEAR o acesso direto:"
    echo "   $ sudo bash manage_firewall.sh"
    echo ""
    echo "   Menu interativo:"
    echo "     1) Ver status das portas"
    echo "     2) Bloquear portas (acesso apenas via domínio/proxy)"
    echo "     3) Desbloquear portas (acesso direto por IP)"
    echo ""
    echo "   Ou modo comando:"
    echo "     $ sudo bash manage_firewall.sh status    # Verificar"
    echo "     $ sudo bash manage_firewall.sh block      # Bloquear"
    echo "     $ sudo bash manage_firewall.sh unblock    # Desbloquear"
    echo ""
    echo "   Comportamento:"
    echo "     • Localhost (127.0.0.1) sempre permitido para diagnóstico"
    echo "     • Quando bloqueado: acesso apenas via domínio (DNS) ou proxy"
    echo "     • Quando desbloqueado: acesso também via IP:porta"
    echo
    echo "�📋 Logs: $LOG_FILE"
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
    connect_npm_to_azuracast_network || log_warn "Não foi possível conectar NPM à rede do AzuraCast"
    apply_azuracast_network_hardening || log_warn "Hardening de rede não foi aplicado"
    setup_static_site || { log_error "Setup WordPress falhou"; exit 1; }
    setup_webmail || log_warn "Setup de Webmail falhou ou foi desabilitado"
    setup_filemanager || log_warn "Setup de Gerenciador de Arquivos falhou ou foi desabilitado"
    
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

