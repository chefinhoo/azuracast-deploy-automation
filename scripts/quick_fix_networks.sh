#!/bin/bash

# Quick fix para conectar containers às redes do proxy
# Use quando os containers já estão rodando mas isolados

echo "═══════════════════════════════════════════════════════"
echo "  🔧 Correção Rápida - Conectar Containers ao Proxy"
echo "═══════════════════════════════════════════════════════"
echo ""

# Verificar se é root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Este script precisa ser executado como root"
    echo "Execute: sudo bash quick_fix_networks.sh"
    exit 1
fi

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "🔍 Descobrindo rede do proxy..."

# Encontrar o container do proxy
PROXY_CONTAINER=$(docker ps -qf 'name=nginx-proxy-manager' | head -1)

if [ -z "$PROXY_CONTAINER" ]; then
    echo -e "${RED}❌ nginx-proxy-manager não encontrado${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Container proxy encontrado: $PROXY_CONTAINER"

# Pegar a rede do proxy
PROXY_NETWORK=$(docker inspect "$PROXY_CONTAINER" -f '{{range $key := .NetworkSettings.Networks}}{{$key}} {{end}}' | awk '{print $1}')

if [ -z "$PROXY_NETWORK" ]; then
    echo -e "${RED}❌ Não foi possível identificar a rede${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Rede do proxy: $PROXY_NETWORK"
echo ""

# Arrays de containers para conectar
CONTAINERS=("filemanager" "webmail-nginx" "webmail-db")

# Adicionar containers do WordPress se existirem
WP_CONTAINERS=$(docker ps --all --format '{{.Names}}' | grep "^wp-app-" || true)
if [ ! -z "$WP_CONTAINERS" ]; then
    while IFS= read -r container; do
        CONTAINERS+=("$container")
    done <<< "$WP_CONTAINERS"
fi

echo "📡 Conectando containers à rede: $PROXY_NETWORK"
echo ""

# Conectar cada container
for container in "${CONTAINERS[@]}"; do
    echo -n "  $container... "
    
    # Verificar se container existe
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        echo -e "${YELLOW}não encontrado${NC}"
        continue
    fi
    
    # Verificar se já está conectado
    if docker inspect "$container" -f '{{range $key := .NetworkSettings.Networks}}{{$key}} {{end}}' | grep -q "$PROXY_NETWORK"; then
        echo -e "${GREEN}✓ já conectado${NC}"
        continue
    fi
    
    # Conectar à rede
    if docker network connect "$PROXY_NETWORK" "$container" 2>/dev/null; then
        echo -e "${GREEN}✓ conectado${NC}"
    else
        echo -e "${RED}✗ erro${NC}"
    fi
done

echo ""
echo "═══════════════════════════════════════════════════════"
echo -e "${GREEN}  ✅ CORRIG IDO${NC}"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "📋 Status dos containers:"
docker ps --format "table {{.Names}}\t{{.Networks}}" | grep -E "filemanager|webmail|wp-app" || echo "Nenhum container encontrado"
echo ""
echo "✅ Agora teste os domínios no navegador:"
echo "   - https://files.daniloramos.dev.br/"
echo "   - https://webmail.daniloramos.dev.br/"
echo "   - https://gospelibipitanga.com.br/"
echo ""
