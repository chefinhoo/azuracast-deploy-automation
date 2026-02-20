#!/bin/bash
# Script para diagnosticar problemas de proxy reverso com AzuraCast

set -euo pipefail

# Cores
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

AZURACAST_DIR="${AZURACAST_DIR:-/var/azuracast}"

echo "========================================="
echo "Diagnóstico de Proxy Reverso - AzuraCast"
echo "========================================="
echo ""

# 1. Verificar se containers estão rodando
echo -e "${BLUE}1. Verificando containers Docker...${NC}"
echo ""
if docker ps --filter "name=azuracast" --format "table {{.Names}}\t{{.Status}}" | grep -q "azuracast"; then
    docker ps --filter "name=azuracast" --format "table {{.Names}}\t{{.Status}}"
    echo ""
    echo -e "${GREEN}✓ Containers estão rodando${NC}"
else
    echo -e "${RED}✗ Containers do AzuraCast não estão rodando${NC}"
    echo "Execute: cd /var/azuracast && docker compose up -d"
    exit 1
fi
echo ""

# 2. Verificar saúde do container web
echo -e "${BLUE}2. Verificando saúde do container web...${NC}"
echo ""
WEB_CONTAINER=$(docker ps --filter "name=azuracast" --format "{{.Names}}" | grep -E "web|^azuracast$" | head -1)
if [ -n "$WEB_CONTAINER" ]; then
    HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$WEB_CONTAINER" 2>/dev/null || echo "unknown")
    if [ "$HEALTH" = "healthy" ]; then
        echo -e "${GREEN}✓ Container está saudável: $WEB_CONTAINER${NC}"
    elif [ "$HEALTH" = "starting" ]; then
        echo -e "${YELLOW}⚠ Container ainda está iniciando: $WEB_CONTAINER${NC}"
        echo "  Aguarde alguns minutos antes de configurar o proxy"
    else
        echo -e "${YELLOW}⚠ Container status: $HEALTH${NC}"
    fi
else
    echo -e "${RED}✗ Container web não encontrado${NC}"
    exit 1
fi
echo ""

# 3. Verificar portas HTTP/HTTPS internas
echo -e "${BLUE}3. Testando conectividade HTTP/HTTPS interna...${NC}"
echo ""

# Obter portas do .env
if [ -f "$AZURACAST_DIR/.env" ]; then
    HTTP_PORT=$(grep "^AZURACAST_HTTP_PORT=" "$AZURACAST_DIR/.env" | cut -d= -f2)
    HTTPS_PORT=$(grep "^AZURACAST_HTTPS_PORT=" "$AZURACAST_DIR/.env" | cut -d= -f2)
    
    echo "Portas configuradas:"
    echo "  HTTP:  $HTTP_PORT"
    echo "  HTTPS: $HTTPS_PORT"
    echo ""
    
    # Testar HTTP
    echo -n "Testando HTTP (localhost:$HTTP_PORT)... "
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$HTTP_PORT" --max-time 5 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
        echo -e "${GREEN}✓ OK (HTTP $HTTP_CODE)${NC}"
        HTTP_OK=true
    else
        echo -e "${RED}✗ Falhou (HTTP $HTTP_CODE)${NC}"
        HTTP_OK=false
    fi
    
    # Testar HTTPS
    echo -n "Testando HTTPS (localhost:$HTTPS_PORT)... "
    HTTPS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://localhost:$HTTPS_PORT" --insecure --max-time 5 2>/dev/null || echo "000")
    if [ "$HTTPS_CODE" = "200" ] || [ "$HTTPS_CODE" = "301" ] || [ "$HTTPS_CODE" = "302" ]; then
        echo -e "${GREEN}✓ OK (HTTP $HTTPS_CODE)${NC}"
        HTTPS_OK=true
    else
        echo -e "${RED}✗ Falhou (HTTP $HTTPS_CODE)${NC}"
        HTTPS_OK=false
    fi
else
    echo -e "${RED}✗ Arquivo .env não encontrado${NC}"
    exit 1
fi
echo ""

# 4. Verificar logs recentes do AzuraCast
echo -e "${BLUE}4. Últimas 10 linhas do log do AzuraCast...${NC}"
echo ""
docker logs --tail 10 "$WEB_CONTAINER" 2>&1 | sed 's/^/  /'
echo ""

# 5. Verificar DNS
echo -e "${BLUE}5. Verificando resolução DNS...${NC}"
echo ""
if [ -n "${1:-}" ]; then
    DOMAIN="$1"
    echo "Resolvendo: $DOMAIN"
    if host "$DOMAIN" > /dev/null 2>&1; then
        host "$DOMAIN" | sed 's/^/  /'
        echo -e "${GREEN}✓ DNS está resolvendo${NC}"
    else
        echo -e "${YELLOW}⚠ DNS não está resolvendo${NC}"
        echo "  Verifique se o domínio está apontando para o IP do servidor"
    fi
else
    echo -e "${YELLOW}⚠ Domínio não especificado${NC}"
    echo "  Use: sudo bash diagnose_proxy.sh seu-dominio.com"
fi
echo ""

# 6. Recomendações
echo "========================================="
echo -e "${BLUE}📋 RECOMENDAÇÕES${NC}"
echo "========================================="
echo ""

if [ "$HTTP_OK" = true ]; then
    echo -e "${GREEN}✓ Use HTTP no Nginx Proxy Manager:${NC}"
    echo ""
    echo "  🔹 Domain Names: ${1:-seu-dominio.com}"
    echo "  🔹 Scheme: http"
    echo "  🔹 Forward Hostname/IP: localhost (ou azuracast)"
    echo "  🔹 Forward Port: $HTTP_PORT"
    echo "  🔹 Cache Assets: ✓"
    echo "  🔹 Block Common Exploits: ✓"
    echo "  🔹 Websockets Support: ✓"
    echo ""
    echo "  Aba SSL:"
    echo "  🔹 Request a new SSL Certificate"
    echo "  🔹 Force SSL: ✓"
    echo "  🔹 HTTP/2 Support: ✓"
    echo "  🔹 HSTS Enabled: ✓"
    echo ""
elif [ "$HTTPS_OK" = true ]; then
    echo -e "${YELLOW}⚠ Use HTTPS no Nginx Proxy Manager:${NC}"
    echo ""
    echo "  🔹 Domain Names: ${1:-seu-dominio.com}"
    echo "  🔹 Scheme: https"
    echo "  🔹 Forward Hostname/IP: localhost (ou azuracast)"
    echo "  🔹 Forward Port: $HTTPS_PORT"
    echo "  🔹 Cache Assets: ✓"
    echo "  🔹 Block Common Exploits: ✓"
    echo "  🔹 Websockets Support: ✓"
    echo ""
    echo "  Aba SSL:"
    echo "  🔹 Request a new SSL Certificate"
    echo "  🔹 Force SSL: ✓"
    echo "  🔹 HTTP/2 Support: ✓"
    echo ""
else
    echo -e "${RED}✗ AzuraCast não está respondendo${NC}"
    echo ""
    echo "Possíveis soluções:"
    echo "  1. Aguarde a inicialização completa (pode levar 5-10 minutos)"
    echo "  2. Verifique os logs: docker logs -f $WEB_CONTAINER"
    echo "  3. Reinicie os containers: cd /var/azuracast && docker compose restart"
    echo ""
fi

echo "========================================="
echo ""
