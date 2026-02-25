#!/bin/bash
# =========================================================
# Biblioteca de funções comuns
# Common functions library
# 
# Fornece funções reutilizáveis para scripts de deploy
# Provides reusable functions for deploy scripts
# =========================================================

set -euo pipefail

# ==========================================================
# VARIÁVEIS GLOBAIS
# ==========================================================

readonly SCRIPT_DIR="${SCRIPT_DIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
readonly PROJECT_ROOT="${PROJECT_ROOT:=$(dirname "$SCRIPT_DIR")}"
readonly CONFIG_FILE="${CONFIG_FILE:=${PROJECT_ROOT}/.deploy-config}"
readonly CONFIG_EXAMPLE="${PROJECT_ROOT}/.deploy-config.example"
readonly LOG_DIR="${LOG_DIR:=/var/log}"
readonly LOG_FILE="${LOG_FILE:=${LOG_DIR}/azuracast-deploy.log}"

# Cores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Timestamps
TIMESTAMP_INIT="$(date '+%Y-%m-%d %H:%M:%S')"

# ==========================================================
# FUNÇÕES DE LOGGING
# ==========================================================

# Inicializar arquivo de log
init_logging() {
    local log_dir="$(dirname "$LOG_FILE")"
    
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir" || {
            echo "Erro ao criar diretório de logs: $log_dir" >&2
            return 1
        }
    fi
    
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE" || {
            echo "Erro ao criar arquivo de log: $LOG_FILE" >&2
            return 1
        }
    fi
    
    return 0
}

# Log com timestamp
log_entry() {
    local level="$1"
    shift
    local message="$*"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
}

# Log de informação
log_info() {
    local message="$*"
    printf "${BLUE}[ℹ]${NC} %s\n" "$message"
    log_entry "INFO" "$message"
}

# Log de sucesso
log_success() {
    local message="$*"
    printf "${GREEN}[✓]${NC} %s\n" "$message"
    log_entry "SUCCESS" "$message"
}

# Log de aviso
log_warn() {
    local message="$*"
    printf "${YELLOW}[!]${NC} %s\n" "$message"
    log_entry "WARN" "$message"
}

# Log de erro
log_error() {
    local message="$*"
    printf "${RED}[✗]${NC} %s\n" "$message" >&2
    log_entry "ERROR" "$message"
}

# Log de debug (apenas se VERBOSE_LOGGING=1)
log_debug() {
    if [ "${VERBOSE_LOGGING:-0}" = "1" ]; then
        local message="$*"
        printf "${CYAN}[DEBUG]${NC} %s\n" "$message"
        log_entry "DEBUG" "$message"
    fi
}

# ==========================================================
# FUNÇÕES DE CONFIGURAÇÃO
# ==========================================================

# Carregar configurações
load_config() {
    # Usar valores padrão primeiro
    PROXY_MANAGER_DIR="${PROXY_MANAGER_DIR:=/var/proxy_manager}"
    AZURACAST_DIR="${AZURACAST_DIR:=/var/azuracast}"
    WEB_ROOT="${WEB_ROOT:=/var}"
    
    NPM_ADMIN_PORT="${NPM_ADMIN_PORT:=81}"
    NPM_HTTP_PORT="${NPM_HTTP_PORT:=80}"
    NPM_HTTPS_PORT="${NPM_HTTPS_PORT:=443}"
    
    AZURACAST_HTTP_PORT="${AZURACAST_HTTP_PORT:=8080}"
    AZURACAST_HTTPS_PORT="${AZURACAST_HTTPS_PORT:=8043}"
    AZURACAST_STATION_PORT_START="${AZURACAST_STATION_PORT_START:=9000}"
    AZURACAST_STATION_PORT_END="${AZURACAST_STATION_PORT_END:=9999}"
    
    STATIC_SITE_PORT="${STATIC_SITE_PORT:=8085}"
    
    NPM_DB_PASSWORD="${NPM_DB_PASSWORD:=npm}"
    NPM_DB_USER="${NPM_DB_USER:=npm}"
    NPM_DB_NAME="${NPM_DB_NAME:=npm}"
    
    VERBOSE_LOGGING="${VERBOSE_LOGGING:=0}"
    PROMPT_FOR_DOMAIN="${PROMPT_FOR_DOMAIN:=1}"
    FORCE_FRESH_INSTALL="${FORCE_FRESH_INSTALL:=0}"
    
    NPM_VERSION="${NPM_VERSION:=latest}"
    MARIADB_VERSION="${MARIADB_VERSION:=10.11}"
    
    CONTAINER_HEALTH_CHECK_TIMEOUT="${CONTAINER_HEALTH_CHECK_TIMEOUT:=120}"
    NETWORK_TIMEOUT="${NETWORK_TIMEOUT:=30}"
    
    USE_IPV6="${USE_IPV6:=0}"
    PUBLIC_IP="${PUBLIC_IP:-}"
    BLOCK_DIRECT_AZURACAST_ACCESS="${BLOCK_DIRECT_AZURACAST_ACCESS:=1}"
    DISABLE_NETWORK_HARDENING="${DISABLE_NETWORK_HARDENING:=0}"
    FIREWALL_INTERFACE="${FIREWALL_INTERFACE:-}"
    
    # Carregar arquivo de configuração se existir
    if [ -f "$CONFIG_FILE" ]; then
        log_debug "Carregando configurações de: $CONFIG_FILE"
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    fi
    
    return 0
}

# Mostrar configurações atuais
show_config() {
    load_config
    
    echo
    echo "╔════════════════════════════════════════════╗"
    echo "║     CONFIGURAÇÃO ATUAL                      ║"
    echo "╚════════════════════════════════════════════╝"
    echo
    echo "📁 Diretórios:"
    echo "   Nginx Proxy Manager: $PROXY_MANAGER_DIR"
    echo "   AzuraCast:           $AZURACAST_DIR"
    echo "   Web Root:            $WEB_ROOT"
    echo
    echo "🔌 Portas:"
    echo "   NPM Admin:      $NPM_ADMIN_PORT"
    echo "   HTTP:           $NPM_HTTP_PORT"
    echo "   HTTPS:          $NPM_HTTPS_PORT"
    echo "   AzuraCast HTTP: $AZURACAST_HTTP_PORT"
    echo "   AzuraCast HTTPS:$AZURACAST_HTTPS_PORT"
    echo "   Estações:       $AZURACAST_STATION_PORT_START-$AZURACAST_STATION_PORT_END"
    echo "   WordPress:      $STATIC_SITE_PORT"
    echo
    echo "⚙️  Comportamento:"
    echo "   Modo Verbose:        $VERBOSE_LOGGING"
    echo "   Solicitar Domínio:   $PROMPT_FOR_DOMAIN"
    echo "   Instalação Limpa:    $FORCE_FRESH_INSTALL"
    echo "   Bloquear acesso IP:  $BLOCK_DIRECT_AZURACAST_ACCESS"
    echo "   Desativar hardening: $DISABLE_NETWORK_HARDENING"
    echo
}

# ==========================================================
# FUNÇÕES DE VALIDAÇÃO
# ==========================================================

# Verificar privilégios root
check_root() {
    if [ "${EUID:-$(id -u)}" -ne 0 ]; then
        log_error "Execute como root (sudo)."
        return 1
    fi
    return 0
}

# Verificar distribuição suportada
check_distribution() {
    if ! grep -q "ubuntu\|debian" /etc/os-release 2>/dev/null; then
        log_error "Este script só é suportado em Ubuntu/Debian."
        return 1
    fi
    
    local os=$(grep "^NAME=" /etc/os-release | cut -d'"' -f2)
    local version=$(grep "^VERSION_ID=" /etc/os-release | cut -d'"' -f2)
    
    log_success "Distribuição compatível: $os $version"
    return 0
}

# Verificar conectividade de rede
check_connectivity() {
    log_info "Verificando conectividade de rede..."
    
    if ! timeout "${NETWORK_TIMEOUT}" ping -c 1 8.8.8.8 &>/dev/null; then
        log_error "Sem conectividade de rede."
        return 1
    fi
    
    log_success "Conectividade de rede OK."
    return 0
}

# Validar porta disponível
check_port_available() {
    local port="$1"
    
    if ss -tuln 2>/dev/null | grep -q ":${port} " || \
       netstat -tuln 2>/dev/null | grep -q ":${port} "; then
        return 1
    fi
    return 0
}

# Gerar portas de estação no formato CSV esperado pelo AzuraCast
# Exemplo: 9000,9005,9006,9010,9015,9016...
generate_station_ports_csv() {
    local start_port="$1"
    local end_port="$2"

    if ! [[ "$start_port" =~ ^[0-9]+$ ]] || ! [[ "$end_port" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    if [ "$start_port" -gt "$end_port" ]; then
        return 1
    fi

    local ports=()
    local base
    local candidate

    for ((base=start_port; base<=end_port; base+=10)); do
        for offset in 0 5 6; do
            candidate=$((base + offset))
            if [ "$candidate" -ge "$start_port" ] && [ "$candidate" -le "$end_port" ]; then
                ports+=("$candidate")
            fi
        done
    done

    local joined=""
    local item
    for item in "${ports[@]}"; do
        if [ -z "$joined" ]; then
            joined="$item"
        else
            joined="$joined,$item"
        fi
    done

    printf '%s\n' "$joined"
    return 0
}

# Forçar liberação de porta matando containers que a usam
force_free_port() {
    local port="$1"
    
    log_info "Verificando porta $port..."
    
    # Procurar containers Docker usando a porta
    local containers=$(docker ps -q --filter "publish=${port}" 2>/dev/null)
    
    if [ -n "$containers" ]; then
        log_warn "Encontrados containers usando porta $port. Removendo..."
        echo "$containers" | xargs -r docker rm -f 2>/dev/null || true
        sleep 2
    fi
    
    # Verificar se ainda está em uso
    if ! check_port_available "$port"; then
        log_warn "Porta $port ainda em uso. Tentando identificar processo..."
        
        # Tentar identificar processo no host
        local pid=$(ss -tlnp 2>/dev/null | grep ":${port} " | grep -oP 'pid=\K[0-9]+' | head -1)
        
        if [ -n "$pid" ]; then
            log_warn "Processo $pid está usando porta $port"
            ps -p "$pid" -o comm= 2>/dev/null || true
        fi
        
        return 1
    fi
    
    log_success "Porta $port está livre."
    return 0
}

# Validar formato de domínio
validate_domain() {
    local domain="$1"
    
    # Padrão básico para validação de domínio
    if [[ ! "$domain" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

# Validar comando disponível
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ==========================================================
# FUNÇÕES DE EXECUÇÃO
# ==========================================================

# Executar comando com logging
run_cmd() {
    local cmd="$@"
    
    log_debug "Executando: $cmd"
    
    if ! eval "$cmd"; then
        log_error "Falha ao executar: $cmd"
        return 1
    fi
    
    return 0
}

# Executar comando com saída silenciosa
run_cmd_silent() {
    local cmd="$@"
    
    log_debug "Executando (silenciosamente): $cmd"
    
    if ! eval "$cmd" >/dev/null 2>&1; then
        log_error "Falha ao executar: $cmd"
        return 1
    fi
    
    return 0
}

# ==========================================================
# FUNÇÕES DOCKER
# ==========================================================

# Verificar se Docker está instalado
docker_installed() {
    command_exists docker && command_exists docker-compose
}

# Obter versão do Docker
docker_version() {
    docker --version 2>/dev/null || echo "Docker não instalado"
}

# Aguardar container estar saudável
wait_container_healthy() {
    local container="$1"
    local timeout="${2:-$CONTAINER_HEALTH_CHECK_TIMEOUT}"
    local elapsed=0
    
    log_info "Aguardando container '$container' ficar saudável (timeout: ${timeout}s)..."
    
    while [ "$elapsed" -lt "$timeout" ]; do
        if docker ps --filter "name=$container" --filter "status=running" | grep -q "$container" 2>/dev/null; then
            log_success "Container '$container' está pronto."
            return 0
        fi
        
        sleep 1
        ((elapsed++))
    done
    
    log_error "Timeout aguardando container '$container'."
    log_info "Logs do container:"
    docker logs "$container" 2>/dev/null | tail -20 || true
    
    return 1
}

# Parar e remover container
remove_container() {
    local container="$1"
    
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        log_info "Removendo container: $container"
        docker stop "$container" 2>/dev/null || true
        docker rm "$container" 2>/dev/null || true
    fi
}

# ==========================================================
# FUNÇÕES DE SISTEMA
# ==========================================================

# Obter IP público
get_public_ip() {
    if [ -n "$PUBLIC_IP" ]; then
        echo "$PUBLIC_IP"
        return 0
    fi
    
    # Tentar obter IP público
    if curl -s --max-time "$NETWORK_TIMEOUT" https://ifconfig.me 2>/dev/null; then
        return 0
    fi
    
    # Fallback para IP local
    hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1"
}

# Limpar cache
cleanup_cache() {
    log_info "Limpando cache do sistema..."
    
    apt-get clean 2>/dev/null || true
    apt-get autoclean 2>/dev/null || true
}

# Verificar portas de um container
check_container_ports() {
    local container_name="$1"
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_warn "Container $container_name não está rodando"
        return 1
    fi
    
    log_info "Portas do container $container_name:"
    docker port "$container_name" 2>/dev/null || log_warn "Nenhuma porta exposta"
    return 0
}

# Mostrar status de todos os containers
show_containers_status() {
    log_info "Status dos containers Docker:"
    echo ""
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null
    echo ""
}

# ==========================================================
# FUNÇÕES DE ENTRADA
# ==========================================================

# Solicitar confirmação
prompt_confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local response
    
    if [ "$default" = "y" ]; then
        read -rp "$prompt (Y/n): " response
        response="${response:-y}"
    else
        read -rp "$prompt (y/N): " response
        response="${response:-n}"
    fi
    
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Solicitar domínio
prompt_domain() {
    local domain=""
    
    while [ -z "$domain" ]; do
        read -rp "👉 Informe o domínio (ex: seudominio.com): " domain
        
        if [ -z "$domain" ]; then
            log_error "Domínio não pode estar vazio." >&2
            continue
        fi
        
        if ! validate_domain "$domain"; then
            log_error "Domínio inválido: $domain" >&2
            domain=""
            continue
        fi
        
        log_success "Domínio validado: $domain" >&2
    done
    
    # Retornar APENAS o domínio (sem newline) para evitar contaminar variáveis
    printf "%s" "$domain"
}

# Gerenciar usuário do Filebrowser para um cliente (criar ou mostrar existente)
manage_filebrowser_user() {
    local client_name="$1"
    local is_new_client="${2:-false}"
    local fb_db_path=""
    local fb_config_path="/etc/config/settings.json"
    local web_root="${WEB_ROOT:-/var}"
    web_root="${web_root%/}"
    local client_root="$web_root/$client_name"
    local filebrowser_scope="/srv/var/$client_name"
    
    if [ -z "$client_name" ]; then
        log_error "Nome do cliente não fornecido" >&2
        return 1
    fi
    
    # Verificar se o container filemanager está rodando
    if ! docker ps --format '{{.Names}}' | grep -q "^filemanager$" 2>/dev/null; then
        log_warn "Container filemanager não está rodando. Pulando gestão de usuário." >&2
        return 0
    fi

    detect_filebrowser_db_path() {
        local candidate=""
        local resolved=""

        for candidate in /database.db /filebrowser.db; do
            resolved="$candidate"

            if docker exec -u 0 filemanager test -d "$candidate" 2>/dev/null; then
                resolved="$candidate/filebrowser.db"
            fi

            docker exec -u 0 filemanager sh -lc "mkdir -p \"$(dirname "$resolved")\" && touch \"$resolved\"" >/dev/null 2>&1 || true

            if docker exec -u 0 filemanager filebrowser -d "$resolved" -c "$fb_config_path" config init >/dev/null 2>&1 || \
               docker exec -u 0 filemanager test -f "$resolved" 2>/dev/null; then
                if docker exec -u 0 filemanager test -f "$resolved" 2>/dev/null; then
                    printf '%s\n' "$resolved"
                    return 0
                fi
            fi
        done

        return 1
    }
    
    # Aguardar container estar pronto (até 10 segundos)
    local wait_count=0
    while [ $wait_count -lt 10 ]; do
        if docker exec -u 0 filemanager sh -lc "filebrowser version >/dev/null 2>&1"; then
            break
        fi
        sleep 1
        wait_count=$((wait_count + 1))
    done
    
    # Verificar se conseguiu se conectar
    if [ $wait_count -eq 10 ]; then
        log_warn "Container filemanager não está respondendo. Pulando gestão de usuário." >&2
        return 0
    fi

    fb_db_path="$(detect_filebrowser_db_path 2>/dev/null || true)"
    if [ -z "$fb_db_path" ]; then
        log_warn "Não foi possível inicializar banco do Filebrowser. Pulando gestão de usuário." >&2
        return 0
    fi

    filebrowser_cmd() {
        docker exec -u 0 filemanager filebrowser -d "$fb_db_path" -c "$fb_config_path" "$@"
    }

    # Garantir diretório do cliente no host e no container antes de criar usuário
    if ! mkdir -p "$client_root" 2>/dev/null; then
        log_warn "Não foi possível garantir diretório no host: $client_root" >&2
    fi

    if ! docker exec -u 0 filemanager sh -lc "mkdir -p \"$client_root\"" >/dev/null 2>&1; then
        log_warn "Não foi possível garantir diretório no container: $client_root" >&2
    fi

    if ! docker exec -u 0 filemanager sh -lc "mkdir -p \"$filebrowser_scope\"" >/dev/null 2>&1; then
        log_warn "Não foi possível garantir diretório de scope no container: $filebrowser_scope" >&2
    fi
    
    # Verificar se o diretório do cliente existe
    if [ ! -d "$client_root" ]; then
        log_warn "Diretório $client_root não existe. Pulando gestão de usuário." >&2
        return 0
    fi

    if ! docker exec -u 0 filemanager test -d "$client_root" 2>/dev/null; then
        log_warn "Diretório $client_root não existe no container filemanager. Pulando gestão de usuário." >&2
        return 0
    fi

    if ! docker exec -u 0 filemanager test -d "$filebrowser_scope" 2>/dev/null; then
        log_warn "Diretório de scope $filebrowser_scope não existe no container filemanager. Pulando gestão de usuário." >&2
        return 0
    fi
    
    local creds_file="$client_root/.filebrowser-credentials.txt"
    
    # Se o arquivo de credenciais existe, mostrar informações
    if [ -f "$creds_file" ]; then
        echo "" >&2
        log_info "📁 Credenciais Filebrowser existentes para '$client_name':" >&2
        echo "" >&2
        grep -E "^Usuário:|^Senha:" "$creds_file" | sed 's/^/   /' >&2
        echo "" >&2
        log_info "Arquivo completo: $creds_file" >&2
        echo "" >&2
        return 0
    fi
    
    # Se não existe, perguntar se deseja criar (apenas se não for novo cliente)
    if [ "$is_new_client" = "false" ]; then
        echo "" >&2
        log_warn "Nenhum usuário Filebrowser encontrado para '$client_name'" >&2
        local create_user=""
        read -rp "Deseja criar um usuário Filebrowser agora? (s/N): " create_user
        
        if [[ ! "$create_user" =~ ^[sS]$ ]]; then
            log_info "Pulando criação de usuário Filebrowser" >&2
            return 0
        fi
    fi
    
    # Criar novo usuário
    log_info "Criando usuário Filebrowser para cliente '$client_name'..." >&2
    
    # Gerar senha aleatória (16 caracteres)
    local fb_password
    fb_password=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-16)
    
    # Capturar saída de erro para debug
    local fb_error
    local add_user_cmd=(users add "$client_name" "$fb_password" \
        --scope="$filebrowser_scope" \
        --perm.admin=false \
        --perm.execute=false \
        --perm.create=true \
        --perm.rename=true \
        --perm.modify=true \
        --perm.delete=true \
        --perm.share=false \
        --perm.download=true)

    if fb_error=$(filebrowser_cmd "${add_user_cmd[@]}" 2>&1); then
        
        # Salvar credenciais
        cat > "$creds_file" <<EOF
========================================
CREDENCIAIS FILEBROWSER - Cliente: $client_name
========================================
Data: $(date '+%Y-%m-%d %H:%M:%S')

Usuário: $client_name
Senha: $fb_password

Diretório: $client_root
URL de acesso: Configure via Nginx Proxy Manager

IMPORTANTE:
- Altere a senha após o primeiro acesso
- Este usuário tem acesso APENAS ao diretório $client_root
- Não compartilhe estas credenciais

========================================
EOF
        
        chmod 600 "$creds_file"
        
        echo "" >&2
        log_success "✅ Usuário Filebrowser criado com sucesso!" >&2
        echo "" >&2
        log_info "📋 Credenciais:" >&2
        log_info "   Usuário: $client_name" >&2
        log_info "   Senha: $fb_password" >&2
        log_info "   Diretório: $client_root" >&2
        echo "" >&2
        log_info "💾 Credenciais salvas em: $creds_file" >&2
        echo "" >&2
        
        return 0
    fi

    # Tentativa de auto-correção para erro de diretório home ausente
    if echo "$fb_error" | grep -qi "failed to create user home dir\|file does not exist"; then
        log_warn "Falha ao criar home do usuário no Filebrowser. Tentando fallback sem scope e update posterior..." >&2

        docker exec -u 0 filemanager sh -lc "mkdir -p \"$client_root\" && chmod 755 \"$client_root\"" >/dev/null 2>&1 || true

        local add_user_no_scope_cmd=(users add "$client_name" "$fb_password" \
            --perm.admin=false \
            --perm.execute=false \
            --perm.create=true \
            --perm.rename=true \
            --perm.modify=true \
            --perm.delete=true \
            --perm.share=false \
            --perm.download=true)

        local scope_update_cmd=(users update "$client_name" --scope="$filebrowser_scope")

        if fb_error=$(filebrowser_cmd "${add_user_no_scope_cmd[@]}" 2>&1); then
            if fb_error=$(filebrowser_cmd "${scope_update_cmd[@]}" 2>&1); then
                cat > "$creds_file" <<EOF
========================================
CREDENCIAIS FILEBROWSER - Cliente: $client_name
========================================
Data: $(date '+%Y-%m-%d %H:%M:%S')

Usuário: $client_name
Senha: $fb_password

Diretório: $client_root
URL de acesso: Configure via Nginx Proxy Manager

IMPORTANTE:
- Altere a senha após o primeiro acesso
- Este usuário tem acesso APENAS ao diretório $client_root
- Não compartilhe estas credenciais

========================================
EOF

                chmod 600 "$creds_file"

                echo "" >&2
                log_success "✅ Usuário Filebrowser criado com sucesso via fallback (add + update scope)!" >&2
                echo "" >&2
                log_info "📋 Credenciais:" >&2
                log_info "   Usuário: $client_name" >&2
                log_info "   Senha: $fb_password" >&2
                log_info "   Diretório: $client_root" >&2
                echo "" >&2
                log_info "💾 Credenciais salvas em: $creds_file" >&2
                echo "" >&2

                return 0
            fi
        fi

        # Caso o usuário já exista na tentativa fallback, aplicar apenas o scope
        if echo "$fb_error" | grep -qi "already exists\|já existe"; then
            if fb_error=$(filebrowser_cmd "${scope_update_cmd[@]}" 2>&1); then
                log_success "Scope do usuário '$client_name' atualizado para $client_root" >&2
                return 0
            fi
        fi

        # Última tentativa: repetir comando original com scope
        if fb_error=$(filebrowser_cmd "${add_user_cmd[@]}" 2>&1); then
            cat > "$creds_file" <<EOF
========================================
CREDENCIAIS FILEBROWSER - Cliente: $client_name
========================================
Data: $(date '+%Y-%m-%d %H:%M:%S')

Usuário: $client_name
Senha: $fb_password

Diretório: $client_root
URL de acesso: Configure via Nginx Proxy Manager

IMPORTANTE:
- Altere a senha após o primeiro acesso
- Este usuário tem acesso APENAS ao diretório $client_root
- Não compartilhe estas credenciais

========================================
EOF

            chmod 600 "$creds_file"

            echo "" >&2
            log_success "✅ Usuário Filebrowser criado com sucesso após correção de diretório!" >&2
            echo "" >&2
            log_info "📋 Credenciais:" >&2
            log_info "   Usuário: $client_name" >&2
            log_info "   Senha: $fb_password" >&2
            log_info "   Diretório: $client_root" >&2
            echo "" >&2
            log_info "💾 Credenciais salvas em: $creds_file" >&2
            echo "" >&2

            return 0
        fi
    fi

    # Verificar se o erro é porque o usuário já existe
    if echo "$fb_error" | grep -qi "already exists\|já existe"; then
        log_warn "Usuário '$client_name' já existe no Filebrowser" >&2
        log_info "Use o painel web do Filebrowser para gerenciar este usuário" >&2
        return 0
    fi

    log_error "Falha ao criar usuário no Filebrowser" >&2
    log_error "Erro: $fb_error" >&2
    return 0
}

# Listar clientes existentes em WEB_ROOT
list_existing_clients() {
    local clients=()
    local web_root="${WEB_ROOT:-/var}"
    web_root="${web_root%/}"
    local excluded_dirs="filemanager|webmail|azuracast|proxy_manager|mailserver|log|tmp|lib|cache|run|opt|snap|spool|mail|backups|lock|local|vmail"
    
    # Buscar diretórios em WEB_ROOT que não sejam de sistema
    for dir in "$web_root"/*/; do
        [ -d "$dir" ] 2>/dev/null || continue
        local dirname
        dirname=$(basename "$dir" 2>/dev/null)
        
        # Pular diretórios de sistema
        if [[ "$dirname" =~ ^($excluded_dirs)$ ]]; then
            continue
        fi
        
        # Adicionar apenas se não estiver vazio
        if [ -n "$dirname" ]; then
            clients+=("$dirname")
        fi
    done
    
    # Retornar apenas se houver clientes
    if [ ${#clients[@]} -gt 0 ]; then
        printf '%s\n' "${clients[@]}"
    fi
}

# Solicitar nome do cliente (novo ou existente)
# Define variável global CLIENT_IS_NEW (true/false)
prompt_client_name() {
    local client_name=""
    local web_root="${WEB_ROOT:-/var}"
    web_root="${web_root%/}"
    local existing_clients=()
    
    # Listar clientes existentes (filtrar vazios)
    while IFS= read -r line; do
        [ -n "$line" ] && existing_clients+=("$line")
    done < <(list_existing_clients 2>/dev/null)
    
    echo "" >&2
    if [ ${#existing_clients[@]} -gt 0 ]; then
        echo "Clientes existentes encontrados:" >&2
        for i in "${!existing_clients[@]}"; do
            echo "  $((i+1))) ${existing_clients[i]}" >&2
        done
        echo "" >&2
        echo "Deseja:" >&2
        echo "  n) Criar um NOVO cliente" >&2
        echo "  1-${#existing_clients[@]}) Usar cliente existente" >&2
        echo "" >&2
        
        local choice=""
        read -rp "Escolha [n/1-${#existing_clients[@]}]: " choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#existing_clients[@]}" ]; then
            client_name="${existing_clients[$((choice-1))]}"
            CLIENT_IS_NEW="false"
            log_success "Cliente selecionado: $client_name" >&2
            printf "%s" "$client_name"
            return 0
        fi
    fi
    
    # Criar novo cliente
    echo "" >&2
    echo "Criando novo cliente..." >&2
    CLIENT_IS_NEW="true"
    while [ -z "$client_name" ]; do
        read -rp "👉 Informe o nome do cliente (ex: empresa-xyz): " client_name
        
        if [ -z "$client_name" ]; then
            log_error "Nome do cliente não pode estar vazio." >&2
            continue
        fi
        
        # Validar caracteres permitidos (alfanumérico, hífen, underscore)
        if [[ ! "$client_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            log_error "Nome inválido. Use apenas letras, números, hífen e underscore." >&2
            client_name=""
            continue
        fi
        
        # Verificar se já existe
        if [ -d "$web_root/$client_name" ]; then
            log_error "Cliente '$client_name' já existe. Use a opção de selecionar existente." >&2
            client_name=""
            continue
        fi
        
        log_success "Nome do cliente validado: $client_name" >&2
    done
    
    printf "%s" "$client_name"
}

# Solicitar nome do subdiretório (html para principal, ou nome personalizado)
prompt_subdirectory_name() {
    local client_name="$1"
    local web_root="${WEB_ROOT:-/var}"
    web_root="${web_root%/}"
    local client_root="$web_root/$client_name"
    local subdirectory_name=""
    
    echo "" >&2
    echo "Subdiretórios existentes para cliente '$client_name':" >&2
    
    # Listar subdiretórios existentes
    if [ -d "$client_root" ]; then
        local count=0
        for subdir in "$client_root"/*/; do
            if [ -d "$subdir" ]; then
                local dirname=$(basename "$subdir")
                echo "  - $dirname" >&2
                count=$((count + 1))
            fi
        done
        
        if [ $count -eq 0 ]; then
            echo "  (nenhum)" >&2
        fi
    else
        echo "  (cliente novo - nenhum subdiretório)" >&2
    fi
    
    echo "" >&2
    echo "ℹ️  Use 'html' para o site principal" >&2
    echo "ℹ️  Ou informe um nome para subdomínio (ex: blog, loja, app, painel)" >&2
    echo "" >&2
    
    while [ -z "$subdirectory_name" ]; do
        read -rp "👉 Nome do subdiretório: " subdirectory_name
        
        if [ -z "$subdirectory_name" ]; then
            log_error "Nome do subdiretório não pode estar vazio." >&2
            continue
        fi
        
        # Validar caracteres permitidos
        if [[ ! "$subdirectory_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            log_error "Nome inválido. Use apenas letras, números, hífen e underscore." >&2
            subdirectory_name=""
            continue
        fi
        
        # Verificar se já existe
        if [ -d "$client_root/$subdirectory_name" ]; then
            log_error "Subdiretório '$subdirectory_name' já existe para este cliente." >&2
            subdirectory_name=""
            continue
        fi
        
        log_success "Subdiretório validado: $subdirectory_name" >&2
    done
    
    printf "%s" "$subdirectory_name"
}

# Solicitar entrada com validação
prompt_input() {
    local prompt="$1"
    local pattern="${2:-.*}"
    local value=""
    
    while [ -z "$value" ]; do
        read -rp "$prompt: " value
        
        if [[ ! "$value" =~ $pattern ]]; then
            log_error "Entrada inválida."
            value=""
        fi
    done
    
    echo "$value"
}

# ==========================================================
# FUNÇÕES DE SAÍDA
# ==========================================================

# Mostrar separador
print_separator() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Mostrar seção
print_section() {
    local title="$1"
    echo
    printf "${CYAN}%s${NC}\n" "╔═══════════════════════════════════════════════════╗"
    printf "${CYAN}%s${NC}\n" "║ $title"
    printf "${CYAN}%s${NC}\n" "╚═══════════════════════════════════════════════════╝"
    echo
}

# Mostrar caixa de informação
print_info_box() {
    local title="$1"
    echo
    print_separator
    printf "${BLUE}%s${NC}\n" "$title"
    print_separator
    echo
}

# ==========================================================
