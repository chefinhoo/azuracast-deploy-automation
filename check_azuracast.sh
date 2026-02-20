#!/bin/bash
# Script para verificar configuração e status do AzuraCast

set -euo pipefail

# Cores
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

AZURACAST_DIR="${AZURACAST_DIR:-/var/azuracast}"

echo "========================================="
echo "Verificação do AzuraCast"
echo "========================================="
echo ""

# Verificar se diretório existe
if [ ! -d "$AZURACAST_DIR" ]; then
    echo -e "${RED}❌ Diretório do AzuraCast não encontrado: $AZURACAST_DIR${NC}"
    exit 1
fi

cd "$AZURACAST_DIR" || exit 1

echo -e "${BLUE}📂 Diretório:${NC} $AZURACAST_DIR"
echo ""

# Verificar arquivo .env
echo -e "${BLUE}⚙️  Configuração de Portas (.env):${NC}"
if [ -f ".env" ]; then
    echo ""
    
    # HTTP Port
    if grep -q "^AZURACAST_HTTP_PORT=" .env 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} AZURACAST_HTTP_PORT = $(grep "^AZURACAST_HTTP_PORT=" .env | cut -d= -f2)"
    else
        echo -e "  ${RED}✗${NC} AZURACAST_HTTP_PORT = não encontrado"
    fi
    
    # HTTPS Port
    if grep -q "^AZURACAST_HTTPS_PORT=" .env 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} AZURACAST_HTTPS_PORT = $(grep "^AZURACAST_HTTPS_PORT=" .env | cut -d= -f2)"
    else
        echo -e "  ${RED}✗${NC} AZURACAST_HTTPS_PORT = não encontrado"
    fi
    
    # SFTP Port
    if grep -q "^AZURACAST_SFTP_PORT=" .env 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} AZURACAST_SFTP_PORT = $(grep "^AZURACAST_SFTP_PORT=" .env | cut -d= -f2)"
    else
        echo -e "  ${YELLOW}⚠${NC} AZURACAST_SFTP_PORT = não encontrado"
    fi
    
    # Station Ports
    if grep -q "^AZURACAST_STATION_PORTS=" .env 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} AZURACAST_STATION_PORTS = $(grep "^AZURACAST_STATION_PORTS=" .env | cut -d= -f2)"
    else
        echo -e "  ${RED}✗${NC} AZURACAST_STATION_PORTS = não encontrado"
    fi
    
    echo ""
else
    echo -e "${RED}  ❌ Arquivo .env não encontrado${NC}"
    echo ""
fi

# Status dos containers
echo -e "${BLUE}🐳 Containers Docker:${NC}"
echo ""
if docker ps -a --filter "name=azuracast" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | grep -q "azuracast"; then
    docker ps -a --filter "name=azuracast" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null
else
    echo -e "${RED}  ❌ Nenhum container do AzuraCast encontrado${NC}"
fi
echo ""

# Verificar container web principal
echo -e "${BLUE}🌐 Container Web (Portas Mapeadas):${NC}"
echo ""
WEB_CONTAINER=$(docker ps --filter "name=azuracast" --filter "status=running" --format "{{.Names}}" | grep -E "azuracast.*web|^azuracast$" | head -1)

if [ -n "$WEB_CONTAINER" ]; then
    echo -e "${GREEN}  ✓ Container ativo: $WEB_CONTAINER${NC}"
    echo ""
    echo "  Portas mapeadas:"
    docker port "$WEB_CONTAINER" 2>/dev/null | sed 's/^/    /' || echo "    Nenhuma porta exposta"
    echo ""
    
    # Verificar se está respondendo
    HTTP_PORT=$(docker port "$WEB_CONTAINER" 80/tcp 2>/dev/null | cut -d: -f2)
    if [ -n "$HTTP_PORT" ]; then
        echo "  Testando conectividade HTTP na porta $HTTP_PORT..."
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$HTTP_PORT" | grep -q "200\|301\|302"; then
            echo -e "${GREEN}    ✓ AzuraCast está respondendo!${NC}"
        else
            echo -e "${YELLOW}    ⚠ AzuraCast pode ainda estar iniciando${NC}"
        fi
    fi
else
    echo -e "${RED}  ❌ Container web não está rodando${NC}"
fi

echo ""
echo "========================================="
echo -e "${BLUE}📋 Comandos Úteis:${NC}"
echo "========================================="
echo ""
echo "  Ver logs do AzuraCast:"
echo "    docker logs $WEB_CONTAINER"
echo ""
echo "  Reiniciar AzuraCast:"
echo "    cd $AZURACAST_DIR && docker compose restart"
echo ""
echo "  Parar AzuraCast:"
echo "    cd $AZURACAST_DIR && docker compose down"
echo ""
echo "  Iniciar AzuraCast:"
echo "    cd $AZURACAST_DIR && docker compose up -d"
echo ""
echo "  Atualizar AzuraCast:"
echo "    cd $AZURACAST_DIR && ./docker.sh update-self && ./docker.sh update"
echo ""
