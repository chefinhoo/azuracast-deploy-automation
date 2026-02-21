#!/bin/bash
# Script para corrigir portas do AzuraCast manualmente
# Use este script se as portas estiverem incorretas após instalação

set -euo pipefail

# Cores
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

AZURACAST_DIR="${AZURACAST_DIR:-/var/azuracast}"
AZURACAST_HTTP_PORT="${AZURACAST_HTTP_PORT:-8080}"
AZURACAST_HTTPS_PORT="${AZURACAST_HTTPS_PORT:-8043}"
AZURACAST_STATION_PORT_START="${AZURACAST_STATION_PORT_START:-9000}"
AZURACAST_STATION_PORT_END="${AZURACAST_STATION_PORT_END:-9999}"

generate_station_ports_csv() {
    local start_port="$1"
    local end_port="$2"
    local ports=()
    local base
    local candidate

    for ((base=start_port; base<=end_port; base+=10)); do
        for offset in 0 5 6; do
            candidate=$((base + offset))
            if [ "$candidate" -ge "$start_port" ] && [ "$candidate" -le "$end_port" ]; then
                ports+=("$candidate")
            fi
        done
    done

    local joined=""
    local item
    for item in "${ports[@]}"; do
        if [ -z "$joined" ]; then
            joined="$item"
        else
            joined="$joined,$item"
        fi
    done

    printf '%s\n' "$joined"
}

STATION_PORTS_CSV="$(generate_station_ports_csv "$AZURACAST_STATION_PORT_START" "$AZURACAST_STATION_PORT_END")"

echo "========================================="
echo "Corrigir Portas do AzuraCast"
echo "========================================="
echo ""

# Verificar se diretório existe
if [ ! -d "$AZURACAST_DIR" ]; then
    echo -e "${RED}❌ Diretório do AzuraCast não encontrado: $AZURACAST_DIR${NC}"
    exit 1
fi

if [ ! -f "$AZURACAST_DIR/.env" ]; then
    echo -e "${RED}❌ Arquivo .env não encontrado em $AZURACAST_DIR${NC}"
    exit 1
fi

cd "$AZURACAST_DIR" || exit 1

echo -e "${BLUE}📂 Diretório:${NC} $AZURACAST_DIR"
echo ""

# Mostrar configuração atual
echo -e "${BLUE}⚙️  Configuração atual:${NC}"
echo ""
grep -E "^AZURACAST_(HTTP|HTTPS|SFTP)_PORT=" .env 2>/dev/null || echo "  (portas não definidas)"
grep -E "^AZURACAST_STATION_PORTS=" .env 2>/dev/null || echo "  (portas de estação não definidas)"
echo ""

# Mostrar nova configuração
echo -e "${YELLOW}🔧 Nova configuração a ser aplicada:${NC}"
echo "  AZURACAST_HTTP_PORT=$AZURACAST_HTTP_PORT"
echo "  AZURACAST_HTTPS_PORT=$AZURACAST_HTTPS_PORT"
echo "  AZURACAST_SFTP_PORT=2022"
echo "  AZURACAST_STATION_PORTS=${STATION_PORTS_CSV}"
echo ""

# Confirmar
read -p "Deseja aplicar essas portas? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Operação cancelada."
    exit 0
fi

# Fazer backup
echo -e "${BLUE}📦 Criando backup...${NC}"
cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
echo -e "${GREEN}✓ Backup criado${NC}"
echo ""

# Aplicar correções
echo -e "${BLUE}🔧 Aplicando correções...${NC}"

sed -i "s/^AZURACAST_HTTP_PORT=.*/AZURACAST_HTTP_PORT=${AZURACAST_HTTP_PORT}/" .env
sed -i "s/^AZURACAST_HTTPS_PORT=.*/AZURACAST_HTTPS_PORT=${AZURACAST_HTTPS_PORT}/" .env

if ! grep -q "^AZURACAST_STATION_PORTS=" .env; then
    echo "AZURACAST_STATION_PORTS=${STATION_PORTS_CSV}" >> .env
else
    sed -i "s/^AZURACAST_STATION_PORTS=.*/AZURACAST_STATION_PORTS=${STATION_PORTS_CSV}/" .env
fi

echo -e "${GREEN}✓ Arquivo .env atualizado${NC}"
echo ""

# Corrigir docker-compose.yml
if [ -f "docker-compose.yml" ]; then
    echo -e "${BLUE}🔧 Corrigindo docker-compose.yml...${NC}"
    
    # Fazer backup do docker-compose.yml
    cp docker-compose.yml "docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Remover apenas portas hardcoded de estações (9000-9999)
    # Não remover portas principais (HTTP/HTTPS/SFTP)
    sed -i '/^      - '\''9[0-9]\{3\}:9[0-9]\{3\}'\''/d' docker-compose.yml
    
    echo -e "${GREEN}✓ Portas hardcoded removidas do docker-compose.yml${NC}"
    echo -e "${BLUE}ℹ As portas de estações ${AZURACAST_STATION_PORT_START}-${AZURACAST_STATION_PORT_END} serão gerenciadas pelo AzuraCast${NC}"
    echo ""
else
    echo -e "${YELLOW}⚠ docker-compose.yml não encontrado, pulando correção${NC}"
    echo ""
fi

# Mostrar nova configuração
echo -e "${BLUE}⚙️  Nova configuração:${NC}"
echo ""
grep -E "^AZURACAST_(HTTP|HTTPS|SFTP)_PORT=" .env
grep -E "^AZURACAST_STATION_PORTS=" .env
echo ""

# Reiniciar containers
echo -e "${YELLOW}🔄 Reiniciando containers para aplicar mudanças...${NC}"
echo ""

docker compose down
sleep 3
docker compose up -d

echo ""
echo -e "${GREEN}✓ Containers reiniciados${NC}"
echo ""

# Aguardar inicialização
echo -e "${YELLOW}⏳ Aguardando serviços iniciarem (10 segundos)...${NC}"
sleep 10

# Verificar portas
echo ""
echo -e "${BLUE}🔍 Verificando portas dos containers:${NC}"
echo ""

WEB_CONTAINER=$(docker ps --filter "name=azuracast" --format "{{.Names}}" | grep -E "web|^azuracast$" | head -1)
if [ -n "$WEB_CONTAINER" ]; then
    docker port "$WEB_CONTAINER" 2>/dev/null || echo "  Nenhuma porta exposta"
else
    echo -e "${RED}  ❌ Container web não encontrado${NC}"
fi

echo ""
echo "========================================="
echo -e "${GREEN}✓ Portas corrigidas com sucesso!${NC}"
echo "========================================="
echo ""
echo "Acesse o AzuraCast em:"
echo "  http://SEU_IP:${AZURACAST_HTTP_PORT}"
echo ""
