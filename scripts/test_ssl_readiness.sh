#!/bin/bash

# =========================================================
# TESTE AUTOMÁTICO - Criação de Certificados SSL
# =========================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[TEST]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
log_error() { echo -e "${RED}[ERRO]${NC} $1"; }

echo "════════════════════════════════════════════════════════"
echo "  🧪 TESTE AUTOMÁTICO - CERTIFICADOS SSL"
echo "════════════════════════════════════════════════════════"
echo ""

# Array para rastrear testes
declare -a TEST_RESULTS
declare -a TEST_NAMES

test_result() {
    local name="$1"
    local result="$2"
    
    TEST_NAMES+=("$name")
    TEST_RESULTS+=("$result")
    
    if [ "$result" = "OK" ]; then
        log_success "$name"
    elif [ "$result" = "WARN" ]; then
        log_warn "$name"
    else
        log_error "$name"
    fi
}

# ============================================================
# 1. Teste Docker
# ============================================================
log_info "1. Testando Docker..."
echo "─────────────────────────────────────────────────"

if docker ps > /dev/null 2>&1; then
    test_result "Docker Engine" "OK"
else
    test_result "Docker Engine" "ERRO"
    exit 1
fi

# ============================================================
# 2. Teste Nginx Proxy Manager
# ============================================================
log_info "2. Testando Nginx Proxy Manager..."
echo "─────────────────────────────────────────────────"

if docker ps | grep -q "nginx-proxy-manager"; then
    test_result "Nginx Proxy Manager (rodando)" "OK"
    
    # Testar acesso à API
    if curl -s http://localhost:81/api/ > /dev/null 2>&1; then
        test_result "NPM API (acessível)" "OK"
    else
        test_result "NPM API (acessível)" "WARN"
    fi
else
    test_result "Nginx Proxy Manager (rodando)" "ERRO"
    log_error "Inicie com: cd /var/proxy_manager && docker compose up -d"
fi

# ============================================================
# 3. Teste de DNS
# ============================================================
log_info "3. Testando Resolução DNS..."
echo "─────────────────────────────────────────────────"

# Obter IP público
PUBLIC_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "UNKNOWN")
log_info "IP Público detectado: $PUBLIC_IP"
echo ""

# Testar domínios
DOMAINS=("webmail.daniloramos.dev.br" "gospelibipitanga.com.br")

for domain in "${DOMAINS[@]}"; do
    echo "Testando: $domain"
    
    if dig "$domain" +short 2>/dev/null | grep -q .; then
        RESOLVED_IP=$(dig "$domain" +short | head -1)
        
        if [ "$RESOLVED_IP" = "$PUBLIC_IP" ]; then
            test_result "  DNS para $domain" "OK"
        else
            test_result "  DNS para $domain (aponta para $RESOLVED_IP, não $PUBLIC_IP)" "WARN"
        fi
    else
        test_result "  DNS para $domain (não resolvendo)" "ERRO"
    fi
done

# ============================================================
# 4. Teste de Conectividade HTTP
# ============================================================
log_info "4. Testando Conectividade HTTP..."
echo "─────────────────────────────────────────────────"

for domain in "${DOMAINS[@]}"; do
    echo "Testando: $domain"
    
    if timeout 10 curl -s -o /dev/null -w "%{http_code}" http://"$domain" 2>/dev/null | grep -q "^[123]"; then
        test_result "  HTTP port 80 para $domain" "OK"
    else
        test_result "  HTTP port 80 para $domain" "ERRO"
    fi
done

# ============================================================
# 5. Verificar Let's Encrypt Connectivity
# ============================================================
log_info "5. Testando Acesso ao Let's Encrypt..."
echo "─────────────────────────────────────────────────"

if timeout 10 curl -s -I https://letsencrypt.org/ > /dev/null 2>&1; then
    test_result "Conectividade com Let's Encrypt" "OK"
else
    test_result "Conectividade com Let's Encrypt" "WARN"
fi

# ============================================================
# 6. Teste de Containers de Destino
# ============================================================
log_info "6. Verificando Containers de Destino..."
echo "─────────────────────────────────────────────────"

if docker ps | grep -q "webmail-nginx"; then
    test_result "Container webmail-nginx" "OK"
else
    test_result "Container webmail-nginx" "WARN"
fi

if docker ps | grep -q "wp-app-gospelibipitanga"; then
    test_result "Container wordpress gospel" "OK"
else
    test_result "Container wordpress gospel" "WARN"
fi

# ============================================================
# 7. Teste de Espaço em Disco
# ============================================================
log_info "7. Verificando Espaço em Disco..."
echo "─────────────────────────────────────────────────"

DISK_USAGE=$(df /var/proxy_manager | awk 'NR==2 {print $5}' | sed 's/%//')

if [ "$DISK_USAGE" -lt 80 ]; then
    test_result "Espaço em disco" "OK"
else
    test_result "Espaço em disco (${DISK_USAGE}% usado)" "WARN"
fi

# ============================================================
# Resumo
# ============================================================
echo ""
echo "════════════════════════════════════════════════════════"
echo "  📊 RESUMO DOS TESTES"
echo "════════════════════════════════════════════════════════"
echo ""

OK_COUNT=0
WARN_COUNT=0
ERROR_COUNT=0

for i in "${!TEST_NAMES[@]}"; do
    result="${TEST_RESULTS[$i]}"
    name="${TEST_NAMES[$i]}"
    
    if [ "$result" = "OK" ]; then
        echo -e "${GREEN}✓${NC} $name"
        ((OK_COUNT++))
    elif [ "$result" = "WARN" ]; then
        echo -e "${YELLOW}⚠${NC} $name"
        ((WARN_COUNT++))
    else
        echo -e "${RED}✗${NC} $name"
        ((ERROR_COUNT++))
    fi
done

echo ""
echo "Resultado: ${GREEN}$OK_COUNT OK${NC} | ${YELLOW}$WARN_COUNT AVISOS${NC} | ${RED}$ERROR_COUNT ERROS${NC}"
echo ""

# ============================================================
# Recomendações
# ============================================================
if [ "$ERROR_COUNT" -gt 0 ]; then
    log_error "Há problemas que precisam ser resolvidos ANTES de criar SSL"
    echo ""
    echo "Execute:"
    echo "  sudo bash scripts/ssl_troubleshoot_interactive.sh"
    exit 1
elif [ "$WARN_COUNT" -gt 0 ]; then
    log_warn "Há alguns avisos. Revise acima."
    echo ""
    echo "Provavelmente é seguro tentar criar SSL, mas alguns problemas podem ocorrer."
    echo "Se falhar, execute:"
    echo "  sudo bash scripts/ssl_troubleshoot_interactive.sh"
else
    log_success "Todos os testes passaram!"
    echo ""
    echo "Você pode criar certificados SSL com segurança."
fi

echo ""
