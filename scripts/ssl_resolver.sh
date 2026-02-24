#!/bin/bash

# =========================================================
# SSL RESOLVER - Menu Principal Integrado
# Menu de resolução de problemas com SSL/Let's Encrypt
# =========================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}➜${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# Verificar se está rodando como root para algumas operações
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Esta operação requer root"
        echo "Execute com: sudo bash $0"
        exit 1
    fi
}

show_menu() {
    clear
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                                                        ║"
    echo "║       🔐 SSL RESOLVER - NGINX PROXY MANAGER           ║"
    echo "║                                                        ║"
    echo "║  Resolução de problemas com Let's Encrypt             ║"
    echo "║                                                        ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    echo "PROBLEMAS DETECTADOS:"
    echo "  • webmail.daniloramos.dev.br (webmail-nginx)"
    echo "  • gospelibipitanga.com.br (wp-app-gospelibipitanga)"
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo -e "${CYAN}🚀 SOLUÇÕES RÁPIDAS${NC}"
    echo "  1) Teste rápido de prontidão"
    echo "  2) Troubleshooter interativo"
    echo "  3) Correção automática"
    echo ""
    echo -e "${CYAN}🔍 DIAGNÓSTICO${NC}"
    echo "  4) Diagnóstico completo"
    echo "  5) Verificar logs do NPM"
    echo "  6) Teste de conectividade"
    echo ""
    echo -e "${CYAN}🔧 MANUTENÇÃO${NC}"
    echo "  7) Reiniciar Nginx Proxy Manager"
    echo "  8) Limpar certificados inválidos"
    echo "  9) Corrigir permissões"
    echo ""
    echo -e "${CYAN}📚 INFORMAÇÃO${NC}"
    echo " 10) Abrir guia completo"
    echo " 11) Ver status de containers"
    echo ""
    echo "  0) Sair"
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo ""
}

# ============================================================
# OPÇÃO 1: Teste rápido
# ============================================================
option_quick_test() {
    log_info "Executando teste de prontidão..."
    echo ""
    
    if [ ! -f "$SCRIPT_DIR/test_ssl_readiness.sh" ]; then
        log_error "Script não encontrado: test_ssl_readiness.sh"
        return
    fi
    
    bash "$SCRIPT_DIR/test_ssl_readiness.sh"
}

# ============================================================
# OPÇÃO 2: Troubleshooter interativo
# ============================================================
option_troubleshoot() {
    log_info "Iniciando troubleshooter interativo..."
    echo ""
    
    if [ ! -f "$SCRIPT_DIR/ssl_troubleshoot_interactive.sh" ]; then
        log_error "Script não encontrado: ssl_troubleshoot_interactive.sh"
        return
    fi
    
    bash "$SCRIPT_DIR/ssl_troubleshoot_interactive.sh"
}

# ============================================================
# OPÇÃO 3: Correção automática
# ============================================================
option_auto_fix() {
    log_info "Menu de correção automática..."
    echo ""
    
    if [ ! -f "$SCRIPT_DIR/fix_ssl_issues.sh" ]; then
        log_error "Script não encontrado: fix_ssl_issues.sh"
        return
    fi
    
    check_root
    bash "$SCRIPT_DIR/fix_ssl_issues.sh"
}

# ============================================================
# OPÇÃO 4: Diagnóstico completo
# ============================================================
option_full_diagnosis() {
    log_info "Gerando diagnóstico completo..."
    echo ""
    
    if [ ! -f "$SCRIPT_DIR/diagnose_ssl.sh" ]; then
        log_error "Script não encontrado: diagnose_ssl.sh"
        return
    fi
    
    bash "$SCRIPT_DIR/diagnose_ssl.sh"
}

# ============================================================
# OPÇÃO 5: Ver logs
# ============================================================
option_view_logs() {
    log_info "Últimos 100 linhas de log do NPM..."
    echo ""
    
    if docker ps | grep -q "nginx-proxy-manager"; then
        docker logs --tail 100 nginx-proxy-manager
    else
        log_error "Container nginx-proxy-manager não encontrado"
    fi
    
    echo ""
    read -p "Pressione ENTER para voltar..."
}

# ============================================================
# OPÇÃO 6: Teste de conectividade
# ============================================================
option_connectivity_test() {
    log_info "Testando conectividade..."
    echo ""
    
    DOMAINS=("webmail.daniloramos.dev.br" "gospelibipitanga.com.br")
    
    for domain in "${DOMAINS[@]}"; do
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Domínio: $domain"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # DNS
        echo -n "DNS: "
        if dig "$domain" +short 2>/dev/null | head -1; then
            log_success "Resolvendo"
        else
            log_error "Não resolvendo"
        fi
        
        # HTTP
        echo -n "HTTP (porta 80): "
        if timeout 5 curl -s -o /dev/null -w "%{http_code}" "http://$domain" 2>/dev/null | grep -q "^[123]"; then
            log_success "Respondendo"
        else
            log_error "Não respondendo"
        fi
        
        # HTTPS
        echo -n "HTTPS (porta 443): "
        if timeout 5 curl -s -o /dev/null -w "%{http_code}" "https://$domain" 2>/dev/null | grep -q "^[123]"; then
            log_success "Respondendo"
        else
            log_warn "Bloqueado/Cert inválido (normal se SSL não criado)"
        fi
        
        echo ""
    done
    
    read -p "Pressione ENTER para voltar..."
}

# ============================================================
# OPÇÃO 7: Reiniciar NPM
# ============================================================
option_restart_npm() {
    log_info "Reiniciando Nginx Proxy Manager..."
    
    check_root
    
    if [ -d "/var/proxy_manager" ]; then
        cd /var/proxy_manager
        log_info "Parando containers..."
        docker compose down
        sleep 3
        
        log_info "Iniciando containers..."
        docker compose up -d
        sleep 5
        
        log_success "NPM reiniciado"
    else
        log_error "Diretório /var/proxy_manager não encontrado"
    fi
    
    echo ""
    read -p "Pressione ENTER para voltar..."
}

# ============================================================
# OPÇÃO 8: Limpar certificados
# ============================================================
option_clean_certs() {
    log_warn "Esta operação vai deletar certificados inválidos"
    read -p "Tem certeza? (s/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        log_info "Operação cancelada"
        return
    fi
    
    check_root
    
    if [ -d "/var/proxy_manager/letsencrypt" ]; then
        log_info "Fazendo backup..."
        tar -czf "/tmp/letsencrypt-backup-$(date +%s).tar.gz" /var/proxy_manager/letsencrypt/
        log_success "Backup criado em /tmp/"
        
        log_info "Limpando logs..."
        rm -rf /var/proxy_manager/letsencrypt/logs/*
        
        log_info "Reiniciando NPM..."
        cd /var/proxy_manager && docker compose restart nginx-proxy-manager
        sleep 5
        
        log_success "Certificados limpos. Tente criar novamente."
    else
        log_error "Diretório de certificados não encontrado"
    fi
    
    echo ""
    read -p "Pressione ENTER para voltar..."
}

# ============================================================
# OPÇÃO 9: Corrigir permissões
# ============================================================
option_fix_permissions() {
    log_info "Corrigindo permissões..."
    
    check_root
    
    if [ -d "/var/proxy_manager" ]; then
        log_info "Ajustando /var/proxy_manager..."
        sudo chown -R 1000:1000 /var/proxy_manager
        sudo chmod -R 755 /var/proxy_manager
        
        if [ -d "/var/proxy_manager/letsencrypt" ]; then
            log_info "Protegendo letsencrypt..."
            sudo chmod -R 700 /var/proxy_manager/letsencrypt
        fi
        
        log_success "Permissões corrigidas"
    else
        log_error "Diretório /var/proxy_manager não encontrado"
    fi
    
    echo ""
    read -p "Pressione ENTER para voltar..."
}

# ============================================================
# OPÇÃO 10: Abrir guia
# ============================================================
option_open_guide() {
    if [ -f "$SCRIPT_DIR/../SSL_TROUBLESHOOTING.md" ]; then
        log_info "Abrindo guia completo..."
        cat "$SCRIPT_DIR/../SSL_TROUBLESHOOTING.md" | less
    else
        log_error "Arquivo SSL_TROUBLESHOOTING.md não encontrado"
    fi
}

# ============================================================
# OPÇÃO 11: Status de containers
# ============================================================
option_container_status() {
    echo ""
    log_info "Status dos containers:"
    echo ""
    echo "docker ps -a | grep -E 'nginx-proxy-manager|webmail|gospelibipitanga'"
    echo ""
    docker ps -a | grep -E 'nginx-proxy-manager|webmail|gospelibipitanga' || log_warn "Nenhum container encontrado"
    echo ""
    read -p "Pressione ENTER para voltar..."
}

# ============================================================
# LOOP PRINCIPAL
# ============================================================
while true; do
    show_menu
    
    read -p "Escolha uma opção (0-11): " choice
    
    case $choice in
        1) option_quick_test ;;
        2) option_troubleshoot ;;
        3) option_auto_fix ;;
        4) option_full_diagnosis ;;
        5) option_view_logs ;;
        6) option_connectivity_test ;;
        7) option_restart_npm ;;
        8) option_clean_certs ;;
        9) option_fix_permissions ;;
        10) option_open_guide ;;
        11) option_container_status ;;
        0) log_success "Saindo..."; exit 0 ;;
        *) log_error "Opção inválida" ;;
    esac
    
    echo ""
done
