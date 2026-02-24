#!/bin/bash

# =========================================================
# DIAGNÓSTICO E SOLUÇÃO RÁPIDA - SSL/LETSENCRYPT
# =========================================================

# Este script cria um tutorial interativo para resolver
# problemas com criação de certificados SSL

set -e

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

clear
echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  🔐 SOLUÇÃO DE PROBLEMAS - SSL/LET'S ENCRYPT          ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "Você está tendo problemas ao criar certificados SSL para:"
echo ""
echo "  • webmail.daniloramos.dev.br"
echo "  • gospelibipitanga.com.br"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""

# PASSO 0: Verificar base
echo "📋 PASSO 0: Verificação de Pré-requisitos"
echo "─────────────────────────────────────────────────────────"
echo ""

# Tentar descobrir o IP da máquina
IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "UNKNO WN")
log_info "IP do Servidor: $IP"

# Verificar Docker
if docker ps > /dev/null 2>&1; then
    log_success "Docker está rodando"
else
    log_error "Docker não está respondendo"
    echo "Execute: sudo service docker start"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "📝 PASSO 1: Verificar DNS"
echo "─────────────────────────────────────────────────────────"
echo ""
echo "Para Let's Encrypt gerar certificados, os domínios DEVEM:"
echo "  1. Estar registrados no DNS"
echo "  2. Apontar para o IP público do seu servidor ($IP)"
echo ""
echo "Teste agora (execute cada um):"
echo ""
echo "  ${CYAN}dig webmail.daniloramos.dev.br +short${NC}"
echo "  ${CYAN}dig gospelibipitanga.com.br +short${NC}"
echo ""
log_warn "Se não devolver o IP $IP, o DNS não está configurado!"
echo ""

read -p "DNS está configurado corretamente? (s/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    log_error "Configure o DNS ANTES de criar SSL"
    echo ""
    echo "Para cada domínio, configure um Registro A:"
    echo "  • Nome: webmail  -  Tipo: A  -  Valor: $IP"
    echo "  • Nome: @        -  Tipo: A  -  Valor: $IP  (para gospelibipitanga.com.br)"
    echo ""
    echo "Aguarde 5-30 minutos pela propagação do DNS"
    exit 0
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "🔌 PASSO 2: Verificar Conectividade"
echo "─────────────────────────────────────────────────────────"
echo ""

# Verificar portas abertas
log_info "Verificando se portas 80 e 443 estão acessíveis..."

if curl -s -I http://webmail.daniloramos.dev.br/ > /dev/null 2>&1; then
    log_success "Porta 80 (HTTP) respondendo para webmail"
else
    log_warn "Porta 80 (HTTP) não está acessível"
fi

if curl -s -I https://webmail.daniloramos.dev.br/ > /dev/null 2>&1; then
    log_success "Porta 443 (HTTPS) respondendo para webmail"
else
    log_warn "Porta 443 pode estar bloqueada no firewall"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "🚀 PASSO 3: Diagnosticar Erro Específico"
echo "─────────────────────────────────────────────────────────"
echo ""
echo "Qual erro você está recebendo no Nginx Proxy Manager?"
echo ""
echo "1) 'Domain validation failed'"
echo "2) 'Connection refused'"
echo "3) 'Rate limit exceeded'"
echo "4) 'Permission denied'"
echo "5) Timeout / sem resposta"
echo "6) Outro erro"
echo ""

read -p "Digite o número (1-6): " error_choice

case $error_choice in
    1)
        echo ""
        log_error "'Domain validation failed' - DNS ou rede"
        echo ""
        echo "Possíveis causas:"
        echo "  1️⃣ DNS não está propagado (aguarde 5-30 min)"
        echo "  2️⃣ Firewall bloqueando porta 80"
        echo "  3️⃣ Domínio não aponta para o IP correto"
        echo ""
        echo "Teste com:"
        echo "  ${CYAN}curl -I http://webmail.daniloramos.dev.br${NC}"
        echo ""
        echo "Se retornar erro, o problema é o firewall ou DNS."
        ;;
    
    2)
        echo ""
        log_error "'Connection refused' - NPM não está respondendo"
        echo ""
        echo "Execute:"
        echo "  ${CYAN}cd /var/proxy_manager${NC}"
        echo "  ${CYAN}docker compose down${NC}"
        echo "  ${CYAN}docker compose up -d${NC}"
        echo ""
        log_info "Aguarde 30 segundos e tente novamente..."
        ;;
    
    3)
        echo ""
        log_error "'Rate limit exceeded' - Let's Encrypt bloqueou"
        echo ""
        echo "Você tentou criar muitos certificados para o mesmo domínio."
        echo ""
        echo "Soluções:"
        echo "  • Aguarde 7 dias para tentar novamente"
        echo "  • Use certificado self-signed temporariamente"
        echo "  • Use staging Let's Encrypt para testes"
        echo ""
        log_warn "Para evitar isso: teste bem ANTES de criar SSL"
        ;;
    
    4)
        echo ""
        log_error "'Permission denied' - Problema de permissões"
        echo ""
        echo "Execute:"
        echo "  ${CYAN}sudo chown -R 1000:1000 /var/proxy_manager${NC}"
        echo "  ${CYAN}sudo chmod -R 755 /var/proxy_manager${NC}"
        echo ""
        echo "Depois reinicie NPM:"
        echo "  ${CYAN}cd /var/proxy_manager && docker compose restart${NC}"
        ;;
    
    5)
        echo ""
        log_error "Timeout / Sem Resposta"
        echo ""
        echo "Possíveis causas:"
        echo "  1️⃣ Let's Encrypt muito lento (aguarde)"
        echo "  2️⃣ Container muito lento (precisa mais recurso)"
        echo "  3️⃣ Rede instável"
        echo ""
        echo "Tente reiniciar e aguardar 2 minutos:"
        echo "  ${CYAN}cd /var/proxy_manager && docker compose restart${NC}"
        ;;
    
    6)
        echo ""
        log_warn "Erro desconhecido"
        echo ""
        echo "Verifique os logs do NPM:"
        echo "  ${CYAN}docker logs nginx-proxy-manager | tail -50${NC}"
        echo ""
        echo "Ou acesse o painel:"
        echo "  ${CYAN}http://$IP:81${NC}"
        ;;
esac

echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
log_info "Passos Recomendados:"
echo ""
echo "  1. Aguarde se erro for DNS (até 30 minutos)"
echo "  2. Reinicie NPM se erro for conexão"
echo "  3. Verifique logs se erro persistir"
echo "  4. Tente criar SSL novamente"
echo ""
echo "  Se AINDA não funcionar, execute:"
echo "  ${CYAN}sudo bash scripts/diagnose_ssl.sh${NC}"
echo ""
