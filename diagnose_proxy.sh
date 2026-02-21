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

is_ok_http_code() {
    case "$1" in
        200|301|302) return 0 ;;
        *) return 1 ;;
    esac
}

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
    elif [ "$HEALTH" = "unknown" ]; then
        echo -e "${BLUE}ℹ Container sem healthcheck explícito: $WEB_CONTAINER${NC}"
        echo "  Isso é comum em algumas versões do AzuraCast"
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
    HTTP_PORT="${HTTP_PORT:-8080}"
    HTTPS_PORT="${HTTPS_PORT:-8043}"
    HTTP_OK=false
    HTTPS_OK=false
    INTERNAL_HTTP_OK=false
    TEST_SOURCE_HTTP=""
    TEST_SOURCE_HTTPS=""
    CONTAINER_IP=$(docker inspect --format='{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$WEB_CONTAINER" 2>/dev/null || true)
    
    echo "Portas configuradas:"
    echo "  HTTP:  $HTTP_PORT"
    echo "  HTTPS: $HTTPS_PORT"
    echo ""
    
    # Testar HTTP no host (localhost)
    echo -n "Testando HTTP no host (localhost:$HTTP_PORT)... "
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$HTTP_PORT" --max-time 5 2>/dev/null || echo "000")
    if is_ok_http_code "$HTTP_CODE"; then
        echo -e "${GREEN}✓ OK (HTTP $HTTP_CODE)${NC}"
        HTTP_OK=true
        TEST_SOURCE_HTTP="localhost"
    else
        echo -e "${YELLOW}⚠ Falhou (HTTP $HTTP_CODE)${NC}"
    fi
    
    # Testar HTTPS no host (localhost)
    echo -n "Testando HTTPS no host (localhost:$HTTPS_PORT)... "
    HTTPS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://localhost:$HTTPS_PORT" --insecure --max-time 5 2>/dev/null || echo "000")
    if is_ok_http_code "$HTTPS_CODE"; then
        echo -e "${GREEN}✓ OK (HTTP $HTTPS_CODE)${NC}"
        HTTPS_OK=true
        TEST_SOURCE_HTTPS="localhost"
    else
        echo -e "${YELLOW}⚠ Falhou (HTTP $HTTPS_CODE)${NC}"
    fi

    if [ -n "$CONTAINER_IP" ]; then
        echo ""
        echo "Teste complementar via IP do container ($CONTAINER_IP):"

        if [ "$HTTP_OK" = false ]; then
            echo -n "Testando HTTP (http://$CONTAINER_IP:$HTTP_PORT)... "
            HTTP_CODE_CONTAINER=$(curl -s -o /dev/null -w "%{http_code}" "http://$CONTAINER_IP:$HTTP_PORT" --max-time 5 2>/dev/null || echo "000")
            if is_ok_http_code "$HTTP_CODE_CONTAINER"; then
                echo -e "${GREEN}✓ OK (HTTP $HTTP_CODE_CONTAINER)${NC}"
                HTTP_OK=true
                TEST_SOURCE_HTTP="container_ip"
            else
                echo -e "${RED}✗ Falhou (HTTP $HTTP_CODE_CONTAINER)${NC}"
            fi
        fi

        if [ "$HTTPS_OK" = false ]; then
            echo -n "Testando HTTPS (https://$CONTAINER_IP:$HTTPS_PORT)... "
            HTTPS_CODE_CONTAINER=$(curl -s -o /dev/null -w "%{http_code}" "https://$CONTAINER_IP:$HTTPS_PORT" --insecure --max-time 5 2>/dev/null || echo "000")
            if is_ok_http_code "$HTTPS_CODE_CONTAINER"; then
                echo -e "${GREEN}✓ OK (HTTP $HTTPS_CODE_CONTAINER)${NC}"
                HTTPS_OK=true
                TEST_SOURCE_HTTPS="container_ip"
            else
                echo -e "${RED}✗ Falhou (HTTP $HTTPS_CODE_CONTAINER)${NC}"
            fi
        fi
    fi

    if [ "$HTTP_OK" = false ]; then
        INTERNAL_HTTP_CODE=$(docker exec "$WEB_CONTAINER" sh -lc "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$HTTP_PORT --max-time 5" 2>/dev/null || echo "000")
        if is_ok_http_code "$INTERNAL_HTTP_CODE"; then
            INTERNAL_HTTP_OK=true
            echo ""
            echo -e "${YELLOW}⚠ Serviço HTTP responde dentro do container (HTTP $INTERNAL_HTTP_CODE), mas não no host${NC}"
        fi
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
    echo "  🔹 Forward Hostname/IP: azuracast"
    echo "  🔹 Forward Port: $HTTP_PORT"
    echo "  🔹 Cache Assets: ✓"
    echo "  🔹 Block Common Exploits: ✓"
    echo "  🔹 Websockets Support: ✓"
    echo ""
    if [ "$TEST_SOURCE_HTTP" = "container_ip" ]; then
        echo -e "${YELLOW}⚠ localhost no host falhou, mas IP do container funcionou${NC}"
        echo "  No NPM em Docker, prefira sempre usar hostname do serviço: azuracast"
        echo "  Se necessário, conecte o NPM na rede do AzuraCast:"
        echo "    docker network connect azuracast_default nginx-proxy-manager"
        echo ""
    fi
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
    echo "  🔹 Forward Hostname/IP: azuracast"
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
    if [ "$INTERNAL_HTTP_OK" = true ]; then
        echo -e "${YELLOW}⚠ AzuraCast responde no container, mas não no host${NC}"
        echo ""
        echo "Possíveis soluções:"
        echo "  1. Recriar stack: cd /var/azuracast && docker compose up -d --force-recreate"
        echo "  2. No NPM, use Forward Hostname/IP: azuracast (não localhost)"
        echo "  3. Garanta que o NPM esteja na rede azuracast_default"
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
fi

echo "========================================="
echo ""
