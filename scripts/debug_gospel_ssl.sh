#!/bin/bash

# =========================================================
# DEBUG - gospelibipitanga.com.br SSL Issue
# =========================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}➜${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

clear
echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  🔍 DEBUG - gospelibipitanga.com.br                   ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# 1. DNS
echo "1️⃣ TESTE - Resolução DNS"
echo "─────────────────────────────────────────────────────────"
echo ""

RESOLVE=$(dig gospelibipitanga.com.br +short 2>/dev/null | head -1)
if [ -z "$RESOLVE" ]; then
    log_error "DNS não resolve gospelibipitanga.com.br"
else
    log_success "DNS resolve: $RESOLVE"
fi

echo ""

# 2. HTTP
echo "2️⃣ TESTE - Acesso HTTP (Porta 80)"
echo "─────────────────────────────────────────────────────────"
echo ""

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://gospelibipitanga.com.br 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "000" ]; then
    log_error "Impossível acessar HTTP"
elif [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
    log_success "HTTP respondendo com código $HTTP_CODE"
else
    log_warn "HTTP respondeu com código $HTTP_CODE (esperado 200, 301 ou 302)"
fi

echo ""

# 3. Container WordPress
echo "3️⃣ TESTE - Container WordPress"
echo "─────────────────────────────────────────────────────────"
echo ""

if docker ps | grep -q "wp-app-gospelibipitanga"; then
    log_success "Container wp-app-gospelibipitanga está RODANDO"
else
    log_error "Container wp-app-gospelibipitanga NÃO ESTÁ RODANDO!"
    echo ""
    echo "Iniciando..."
    cd /var/www/gospelibipitanga.com.br && docker compose up -d 2>/dev/null
    sleep 5
    log_info "Container iniciado. Aguarde 20 segundos..."
fi

echo ""

# 4. Nginx Proxy Manager
echo "4️⃣ TESTE - Nginx Proxy Manager"
echo "─────────────────────────────────────────────────────────"
echo ""

if docker ps | grep -q "nginx-proxy-manager"; then
    log_success "NPM está rodando"
    
    # Testar conectividade interna
    if docker exec nginx-proxy-manager curl -s http://wp-app-gospelibipitanga-com-br:80 > /dev/null 2>&1; then
        log_success "NPM consegue acessar container internamente"
    else
        log_warn "NPM NÃO consegue acessar container internamente"
        echo "  Solução: Conectar container à rede do NPM..."
        
        # Descobrir rede do NPM
        NPM_NETWORK=$(docker inspect npm | grep -o '"[a-z0-9]*"' | head -1 | tr -d '"' 2>/dev/null || echo "unknown")
        
        if [ "$NPM_NETWORK" != "unknown" ]; then
            log_info "Conectando container à rede $NPM_NETWORK..."
            docker network connect "$NPM_NETWORK" wp-app-gospelibipitanga-com-br 2>/dev/null || true
        fi
    fi
else
    log_error "NPM não está rodando!"
    echo ""
    echo "Iniciando NPM..."
    cd /var/proxy_manager && docker compose up -d
    sleep 10
fi

echo ""

# 5. Logs
echo "5️⃣ TESTE - Logs do NPM (últimas linhas)"
echo "─────────────────────────────────────────────────────────"
echo ""

docker logs nginx-proxy-manager 2>&1 | tail -20 | grep -i "error\|gospel\|ssl\|cert" || echo "(nenhum erro detectado nos logs)"

echo ""
echo "════════════════════════════════════════════════════════"
echo ""

# Recomendações
echo "📋 PRÓXIMOS PASSOS:"
echo ""
echo "1. Se DNS está OK e HTTP está respondendo:"
echo "   → Tentar criar SSL novamente no painel NPM"
echo ""
echo "2. Se problema persiste:"
echo "   → Reiniciar NPM: cd /var/proxy_manager && docker compose restart"
echo ""
echo "3. Se ainda não funcionar:"
echo "   → Executar teste completo: sudo bash scripts/test_ssl_readiness.sh"
echo ""
echo "4. Problema de IP/firewall?"
echo "   → curl -s https://api.ipify.org (ver IP público)"
echo ""
