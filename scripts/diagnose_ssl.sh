#!/bin/bash

# =========================================================
# Script de Diagnóstico - Problemas com SSL/Let's Encrypt
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

echo "════════════════════════════════════════════════════════"
echo "  🔍 DIAGNÓSTICO DE PROBLEMAS COM SSL/LET'S ENCRYPT"
echo "════════════════════════════════════════════════════════"
echo ""

# 1. Verificar se NPM está rodando
echo "1️⃣  Verificando status do Nginx Proxy Manager..."
echo "─────────────────────────────────────────────────"

if docker ps | grep -q "nginx-proxy-manager"; then
    log_success "Container nginx-proxy-manager está RODANDO"
else
    log_error "Container nginx-proxy-manager NÃO ESTÁ RODANDO!"
    echo "Iniciando container..."
    cd /var/proxy_manager && docker compose up -d
    sleep 5
fi

echo ""
echo "2️⃣  Verificando Logs de Erro do NPM..."
echo "─────────────────────────────────────────────────"

echo "Últimos 50 linhas de log (buscando erros):"
docker logs nginx-proxy-manager 2>&1 | tail -50 | grep -i "error\|failed\|ssl\|cert\|letsencrypt" || {
    log_warn "Nenhum erro específico encontrado nos logs. Mostrando últimas linhas:"
    docker logs nginx-proxy-manager 2>&1 | tail -15
}

echo ""
echo "3️⃣  Verificando Resolução DNS..."
echo "─────────────────────────────────────────────────"

# Usar dig em vez de nslookup (mais confiável)
if command -v dig > /dev/null; then
    log_info "Testando webmail.daniloramos.dev.br..."
    dig webmail.daniloramos.dev.br +short || log_warn "Falha ao resolver webmail.daniloramos.dev.br"
    
    log_info "Testando gospelibipitanga.com.br..."
    dig gospelibipitanga.com.br +short || log_warn "Falha ao resolver gospelibipitanga.com.br"
else
    log_warn "dig não disponível. Use: curl -s 'https://dns.google/resolve?name=seu_dominio.com.br&type=A' | grep -o '\"address\":\"[^\"]*\"'"
fi

echo ""
echo "4️⃣  Verificando Conectividade HTTP/HTTPS..."
echo "─────────────────────────────────────────────────"

log_info "Testando acesso HTTP ao NPM (porta 81)..."
curl -s -I http://localhost:81/ | head -3 || log_error "Falha ao acessar NPM na porta 81"

echo ""
log_info "Testando conectividade para Let's Encrypt..."
curl -s -I https://letsencrypt.org/ > /dev/null && log_success "Consegue acessar Let's Encrypt" || log_error "Sem acesso a Let's Encrypt (firewall/proxy bloqueando?)"

echo ""
echo "5️⃣  Verificando Diretórios do Let's Encrypt..."
echo "─────────────────────────────────────────────────"

if [ -d "/var/proxy_manager/letsencrypt" ]; then
    log_success "Diretório /var/proxy_manager/letsencrypt existe"
    echo "Conteúdo:"
    ls -la /var/proxy_manager/letsencrypt/ | head -20
else
    log_warn "Diretório /var/proxy_manager/letsencrypt NÃO EXISTE"
fi

echo ""
echo "6️⃣  Verificando Espaço em Disco..."
echo "─────────────────────────────────────────────────"

df -h /var/proxy_manager/ 2>/dev/null || {
    log_warn "Não foi possível verificar espaço em /var/proxy_manager"
    df -h | grep -E "^/dev|Filesystem"
}

echo ""
echo "7️⃣  Verificando Permissões de Escrita..."
echo "─────────────────────────────────────────────────"

TEST_FILE="/var/proxy_manager/.test_write_$$"
if touch "$TEST_FILE" 2>/dev/null; then
    log_success "Permissões de escrita OK"
    rm -f "$TEST_FILE"
else
    log_error "Sem permissão de escrita em /var/proxy_manager"
    log_info "Execute: sudo chown -R 1000:1000 /var/proxy_manager"
fi

echo ""
echo "8️⃣  Verificando Firewall..."
echo "─────────────────────────────────────────────────"

if command -v ufw > /dev/null; then
    echo "Status do UFW:"
    ufw status numbered 2>/dev/null | grep -E "^Index|80|443|81" || echo "Filtrando portas 80, 443, 81..."
else
    log_warn "UFW não disponível"
fi

echo ""
echo "9️⃣  Verifindo Containers de Destino..."
echo "─────────────────────────────────────────────────"

log_info "Procurando webmail-nginx..."
docker ps -a | grep -i webmail || log_warn "Container webmail-nginx não encontrado"

log_info "Procurando wp-app-gospelibipitanga-com-br..."
docker ps -a | grep -i "gospelibipitanga" || log_warn "Container wordpress gospel não encontrado"

echo ""
echo "════════════════════════════════════════════════════════"
echo "📋 SOLUÇÕES COMUNS"
echo "════════════════════════════════════════════════════════"
echo ""
echo "❌ 'Domain validation failed':"
echo "   → DNS não está resolvendo publicado"
echo "   → Firewall bloqueando porta 80/443"
echo "   → Aguarde propagação do DNS (até 24h)"
echo ""
echo "❌ 'Rate limit exceeded':"
echo "   → Let's Encrypt bloqueou domínio por excesso de tentativas"
echo "   → Aguarde 1 semana ou use staging"
echo ""
echo "❌ 'Connection refused':"
echo "   → Container do proxy não está rodando"
echo "   → Execute: cd /var/proxy_manager && docker compose up -d"
echo ""
echo "❌ 'Permission denied':"
echo "   → Problema de permissões"
echo "   → Execute: sudo chown -R 1000:1000 /var/proxy_manager"
echo ""
