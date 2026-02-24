#!/bin/bash

# Script de correção automática para problemas de proxy
# Execute no servidor onde os containers estão instalados

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  🔧 Correção Automática de Problemas de Proxy${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Verificar se está sendo executado como root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Este script precisa ser executado como root${NC}"
    echo "Execute: sudo bash fix_proxy_issues.sh"
    exit 1
fi

# Função para verificar se um diretório existe
check_dir() {
    if [ ! -d "$1" ]; then
        echo -e "${YELLOW}⚠️  Diretório $1 não encontrado, pulando...${NC}"
        return 1
    fi
    return 0
}

# Função para iniciar containers
start_service() {
    local dir=$1
    local name=$2
    
    if check_dir "$dir"; then
        echo -e "${BLUE}📦 Iniciando $name...${NC}"
        cd "$dir"
        
        # Parar containers existentes
        docker compose down 2>/dev/null || true
        
        # Iniciar containers
        if docker compose up -d; then
            echo -e "${GREEN}✓${NC} $name iniciado com sucesso"
        else
            echo -e "${RED}✗${NC} Falha ao iniciar $name"
            echo "   Verificando logs..."
            docker compose logs --tail 50
        fi
        echo ""
    fi
}

# Função para conectar container à rede do proxy
connect_to_proxy_network() {
    local container=$1
    local proxy_network=$2
    
    # Verificar se o container existe
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        echo -e "${YELLOW}  ⚠️  Container $container não encontrado, pulando...${NC}"
        return 1
    fi
    
    # Verificar se já está conectado à rede
    if docker inspect "$container" -f '{{range $key := .NetworkSettings.Networks}}{{$key}} {{end}}' | grep -q "$proxy_network"; then
        echo -e "${GREEN}  ✓${NC} $container já está em $proxy_network"
        return 0
    fi
    
    # Conectar à rede
    if docker network connect "$proxy_network" "$container" 2>/dev/null; then
        echo -e "${GREEN}  ✓${NC} $container conectado a $proxy_network"
        return 0
    else
        echo -e "${RED}  ✗${NC} Falha ao conectar $container a $proxy_network"
        return 1
    fi
}

echo -e "${YELLOW}ATENÇÃO: Este script vai reiniciar os containers. Serviços ficarão indisponíveis por alguns segundos.${NC}"
echo ""
read -p "Deseja continuar? (s/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
    echo "Operação cancelada."
    exit 0
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PASSO 1: Iniciando Containers${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Iniciar cada serviço
start_service "/var/filemanager" "Filemanager"
start_service "/var/webmail" "Webmail (Roundcube)"

# Iniciar WordPress sites (nova estrutura: /var/cliente/html ou /var/cliente/subdominio)
if [ -d "/var" ]; then
    # Primeiro nível: clientes
    for client_dir in /var/*/; do
        client_name=$(basename "$client_dir")
        
        # Pular diretórios de sistema
        if [[ "$client_name" =~ ^(filemanager|webmail|azuracast|proxy_manager|mailserver|log|tmp|lib|cache|run|opt|snap)$ ]]; then
            continue
        fi
        
        # Verificar se é um site principal (html/)
        if [ -f "${client_dir}html/docker-compose.yml" ]; then
            start_service "${client_dir}html" "WordPress - $client_name (Principal)"
        fi
        
        # Verificar subdomínios
        for subdir in "${client_dir}"*/; do
            if [ -d "$subdir" ] && [ -f "${subdir}docker-compose.yml" ]; then
                subdir_name=$(basename "$subdir")
                if [ "$subdir_name" != "html" ]; then
                    start_service "$subdir" "WordPress - $client_name/$subdir_name"
                fi
            fi
        done
    done
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PASSO 2: Configurando Redes Docker${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Aguardar containers iniciarem
echo "Aguardando containers iniciarem..."
sleep 5

# Descobrir a rede do proxy
echo "Identificando rede do Nginx Proxy Manager..."
PROXY_NETWORK=""

# Tentar encontrar a rede através do container do proxy
PROXY_CONTAINER=$(docker ps -qf 'name=nginx-proxy-manager' | head -1)
if [ ! -z "$PROXY_CONTAINER" ]; then
    # Pega a primeira rede do proxy (geralmente é a correta)
    PROXY_NETWORK=$(docker inspect "$PROXY_CONTAINER" -f '{{range $key := .NetworkSettings.Networks}}{{$key}}{{end}}' | cut -d' ' -f1)
fi

# Se não conseguir, tenta usar a rede padrão
if [ -z "$PROXY_NETWORK" ]; then
    echo -e "${YELLOW}⚠️  Rede do proxy não identificada, tentando rede padrão...${NC}"
    PROXY_NETWORK="proxy_manager_npm_network"
fi

echo -e "${GREEN}✓${NC} Rede identifi cada: $PROXY_NETWORK"
echo ""

# Conectar containers à rede do proxy
echo "Conectando containers:"
connect_to_proxy_network "filemanager" "$PROXY_NETWORK"
connect_to_proxy_network "webmail-nginx" "$PROXY_NETWORK"
connect_to_proxy_network "webmail-db" "$PROXY_NETWORK"

# Conectar WordPress sites
for wp_container in $(docker ps --format '{{.Names}}' | grep "^wp-app-"); do
    connect_to_proxy_network "$wp_container" "$PROXY_NETWORK"
done

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PASSO 3: Verificando Status${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Listar containers rodando
echo "Containers em execução:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "filemanager|webmail|roundcube|wp-app|azuracast" || echo "Nenhum container encontrado"

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PASSO 4: Testando Conectividade${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Função para testar conectividade
test_connectivity() {
    local name=$1
    local url=$2
    
    echo -n "Testando $name... "
    
    # Encontrar container do proxy
    local proxy_container=$(docker ps -qf "name=nginx-proxy-manager" | head -1)
    
    if [ -z "$proxy_container" ]; then
        echo -e "${YELLOW}não foi possível testar (proxy não encontrado)${NC}"
        return
    fi
    
    # Tentar testar com curl (mais comum)
    if docker exec "$proxy_container" curl -s --connect-timeout 5 "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
    else
        echo -e "${RED}✗ FALHOU${NC}"
        echo "  └─ Verifique se o container está rodando e acessível"
    fi
}

test_connectivity "AzuraCast" "http://azuracast:8080"
test_connectivity "Filemanager" "http://filemanager:80"
test_connectivity "Webmail" "http://webmail-nginx:80"

# Testar WordPress sites
for wp_container in $(docker ps --format '{{.Names}}' | grep "^wp-app-"); do
    site_name=$(echo "$wp_container" | sed 's/^wp-app-//' | sed 's/-com-br$/.com.br/')
    test_connectivity "WordPress ($site_name)" "http://$wp_container:80"
done

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ CORREÇÃO CONCLUÍDA${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo ""
echo "📌 Próximos passos:"
echo ""
echo "1. Aguarde 1-2 minutos para os containers finalizarem a inicialização"
echo "2. Teste o acesso aos sites no navegador:"
echo "   - https://files.exemplo.com.br/"
echo "   - https://webmail.exemplo.com.br/"
echo "   - https://exemplo.com.br/"
echo ""
echo "3. Se ainda não funcionar, verifique a configuração no Nginx Proxy Manager:"
echo "   - Acesse http://SEU_IP:81"
echo "   - Vá em 'Proxy Hosts'"
echo "   - Edite cada host e verifique:"
echo "     • Forward Hostname/IP = nome do container (ex: filemanager)"
echo "     • Forward Port = porta correta (80 para a maioria)"
echo "     • SSL ativo com certificado Let's Encrypt"
echo ""
echo "4. Execute o diagnóstico para mais detalhes:"
echo "   sudo bash diagnose_proxy.sh"
echo ""
