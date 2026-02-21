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
    WEB_ROOT="${WEB_ROOT:=/var/www}"
    
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
    echo "   Site Estático:  $STATIC_SITE_PORT"
    echo
    echo "⚙️  Comportamento:"
    echo "   Modo Verbose:        $VERBOSE_LOGGING"
    echo "   Solicitar Domínio:   $PROMPT_FOR_DOMAIN"
    echo "   Instalação Limpa:    $FORCE_FRESH_INSTALL"
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
