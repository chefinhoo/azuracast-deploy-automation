#!/bin/bash

# =========================================================
# Script de Correção - Problemas com SSL/Let's Encrypt
# =========================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
log_error() { echo -e "${RED}[ERRO]${NC} $1"; }

# Verificar root
if [ "$EUID" -ne 0 ]; then 
    log_error "Este script precisa ser executado como root"
    echo "Execute: sudo bash $0"
    exit 1
fi

echo "════════════════════════════════════════════════════════"
echo "  🔧 CORREÇÃO AUTOMÁTICA - SSL/LET'S ENCRYPT"
echo "════════════════════════════════════════════════════════"
echo ""

# Menu
echo "Escolha a ação:"
echo "1) Reiniciar Nginx Proxy Manager"
echo "2) Limpar cache e logs do Let's Encrypt"
echo "3) Verificar e corrigir permissões"
echo "4) Resetar certificados expirados"
echo "5) Executar diagnóstico completo"
echo "6) Sair"
echo ""

read -p "Digite o número (1-6): " choice

case $choice in
    1)
        echo ""
        log_info "Reiniciando Nginx Proxy Manager..."
        cd /var/proxy_manager
        docker compose down
        sleep 3
        docker compose up -d
        sleep 5
        log_success "NPM reiniciado com sucesso!"
        echo "Aguarde 30 segundos e tente criar o SSL novamente."
        ;;
    
    2)
        echo ""
        log_info "Limpando cache e logs do Let's Encrypt..."
        
        # Backup
        if [ -d "/var/proxy_manager/letsencrypt" ]; then
            log_info "Fazendo backup de certificados..."
            tar -czf /tmp/letsencrypt-backup-$(date +%s).tar.gz /var/proxy_manager/letsencrypt/
            log_success "Backup criado em /tmp/"
        fi
        
        # Limpar logs
        if [ -d "/var/proxy_manager/letsencrypt/logs" ]; then
            log_info "Limpando logs..."
            rm -rf /var/proxy_manager/letsencrypt/logs/*
            log_success "Logs limpos"
        fi
        
        # Reiniciar
        log_info "Reiniciando NPM..."
        cd /var/proxy_manager && docker compose restart nginx-proxy-manager
        sleep 5
        log_success "Cache limpo! Tente criar SSL novamente."
        ;;
    
    3)
        echo ""
        log_info "Corrigindo permissões..."
        
        if [ -d "/var/proxy_manager" ]; then
            log_info "Ajustando /var/proxy_manager..."
            sudo chown -R 1000:1000 /var/proxy_manager
            sudo chmod -R 755 /var/proxy_manager
            log_success "Permissões corrigidas!"
        fi
        
        if [ -d "/var/proxy_manager/letsencrypt" ]; then
            log_info "Ajustando letsencrypt..."
            sudo chmod -R 700 /var/proxy_manager/letsencrypt
            log_success "Certificados protegidos!"
        fi
        ;;
    
    4)
        echo ""
        log_info "Resetando certificados..."
        
        read -p "Tem certeza que deseja deletar os certificados? (s/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            if [ -d "/var/proxy_manager/letsencrypt" ]; then
                log_warn "Deletando certificados existentes..."
                rm -rf /var/proxy_manager/letsencrypt/{accounts,live,renewal,archive}
                mkdir -p /var/proxy_manager/letsencrypt/{accounts,live,renewal,archive}
                log_success "Certificados resetados"
            fi
            
            # Reiniciar
            cd /var/proxy_manager && docker compose restart nginx-proxy-manager
            sleep 5
            log_info "NPM reiniciado. Crie novos certificados no painel."
        else
            log_info "Operação cancelada"
        fi
        ;;
    
    5)
        echo ""
        log_info "Executando diagnóstico completo..."
        if [ -f "$(dirname "$0")/diagnose_ssl.sh" ]; then
            bash "$(dirname "$0")/diagnose_ssl.sh"
        else
            log_error "Script de diagnóstico não encontrado"
        fi
        ;;
    
    6)
        log_info "Saindo..."
        exit 0
        ;;
    
    *)
        log_error "Opção inválida"
        exit 1
        ;;
esac

echo ""
echo "════════════════════════════════════════════════════════"
