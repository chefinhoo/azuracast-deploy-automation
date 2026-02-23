#!/bin/bash

# Script de diagnóstico para problemas de proxy
# Execute no servidor onde os containers estão instalados

echo "═══════════════════════════════════════════════════════"
echo "  Diagnóstico de Problemas de Proxy"
echo "═══════════════════════════════════════════════════════"
echo ""

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. ========== VERIFICAR CONTAINERS ==========
echo "1️⃣  Verificando status dos containers..."
echo "──────────────────────────────────────────────────────"

CONTAINERS=("azuracast" "filemanager" "webmail-nginx" "roundcube" "wp-app-exemplo-com-br")

for container in "${CONTAINERS[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        echo -e "${GREEN}✓${NC} ${container} - RODANDO"
    elif docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        echo -e "${RED}✗${NC} ${container} - PARADO (existe mas não está rodando)"
        echo "   └─ Status: $(docker ps -a --filter "name=^${container}$" --format '{{.Status}}')"
    else
        echo -e "${YELLOW}⚠${NC} ${container} - NÃO ENCONTRADO"
    fi
done

echo ""

# 2. ========== VERIFICAR REDES DOCKER ==========
echo "2️⃣  Verificando redes Docker..."
echo "──────────────────────────────────────────────────────"

# Listar todas as redes
docker network ls

echo ""
echo "Containers por rede:"
for network in $(docker network ls --format '{{.Name}}'); do
    containers=$(docker network inspect "$network" -f '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null)
    if [ ! -z "$containers" ]; then
        echo "  📡 $network: $containers"
    fi
done

echo ""

# 3. ========== TESTAR CONECTIVIDADE INTERNA ==========
echo "3️⃣  Testando conectividade interna..."
echo "──────────────────────────────────────────────────────"

# Verificar se consegue acessar os serviços internamente
test_endpoints() {
    local name=$1
    local url=$2
    
    if docker ps --format '{{.Names}}' | grep -q "proxy-manager"; then
        echo -n "   Testando $name ($url)... "
        if docker exec $(docker ps -qf "name=proxy-manager") wget -q --spider --timeout=5 "$url" 2>/dev/null; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}FALHOU${NC}"
        fi
    fi
}

test_endpoints "AzuraCast" "http://azuracast:8080"
test_endpoints "Filemanager" "http://filemanager:80"
test_endpoints "Webmail" "http://webmail-nginx:80"
test_endpoints "WordPress Gospel" "http://wp-app-exemplo-com-br:80"

echo ""

# 4. ========== VERIFICAR LOGS RECENTES ==========
echo "4️⃣  Verificando logs recentes dos containers (últimas 20 linhas)..."
echo "──────────────────────────────────────────────────────"

for container in "${CONTAINERS[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        echo ""
        echo "📄 Logs de $container:"
        docker logs --tail 20 "$container" 2>&1 | sed 's/^/   │ /'
    fi
done

echo ""

# 5. ========== VERIFICAR PORTAS ==========
echo "5️⃣  Verificando portas expostas..."
echo "──────────────────────────────────────────────────────"

echo "Portas em uso pelos containers:"
docker ps --format "table {{.Names}}\t{{.Ports}}" | sed 's/^/   /'

echo ""

# 6. ========== SOLUÇÕES SUGERIDAS ==========
echo "═══════════════════════════════════════════════════════"
echo "  🔧 SOLUÇÕES SUGERIDAS"
echo "═══════════════════════════════════════════════════════"
echo ""

# Verificar containers parados
stopped_containers=$(docker ps -a --filter "status=exited" --format '{{.Names}}' | grep -E "filemanager|webmail|roundcube|wp-app" | tr '\n' ' ')

if [ ! -z "$stopped_containers" ]; then
    echo "⚠️  PROBLEMA ENCONTRADO: Containers parados"
    echo ""
    echo "Containers parados: $stopped_containers"
    echo ""
    echo "🔨 SOLUÇÃO 1: Iniciar containers parados"
    echo "──────────────────────────────────────────────────────"
    
    if echo "$stopped_containers" | grep -q "filemanager"; then
        echo "# Filemanager:"
        echo "cd /var/filemanager && docker compose up -d"
        echo ""
    fi
    
    if echo "$stopped_containers" | grep -q "webmail\|roundcube"; then
        echo "# Webmail:"
        echo "cd /var/webmail && docker compose up -d"
        echo ""
    fi
    
    if echo "$stopped_containers" | grep -q "wp-app"; then
        echo "# WordPress (exemplo.com.br):"
        echo "cd /var/www/exemplo.com.br && docker compose up -d"
        echo ""
    fi
fi

echo "🔨 SOLUÇÃO 2: Verificar redes Docker"
echo "──────────────────────────────────────────────────────"
echo "Os containers devem estar na mesma rede que o Nginx Proxy Manager."
echo ""
echo "# Verificar qual rede o proxy usa:"
echo "docker network inspect \$(docker inspect -f '{{range \$key, \$value := .NetworkSettings.Networks}}{{\$key}}{{end}}' \$(docker ps -qf 'name=proxy-manager') | head -1)"
echo ""
echo "# Conectar containers à rede do proxy (exemplo):"
echo "PROXY_NETWORK=\$(docker inspect -f '{{range \$key, \$value := .NetworkSettings.Networks}}{{\$key}}{{end}}' \$(docker ps -qf 'name=proxy-manager') | head -1)"
echo "docker network connect \$PROXY_NETWORK filemanager"
echo "docker network connect \$PROXY_NETWORK webmail-nginx"
echo "docker network connect \$PROXY_NETWORK wp-app-exemplo-com-br"
echo ""

echo "🔨 SOLUÇÃO 3: Reiniciar todos os serviços"
echo "──────────────────────────────────────────────────────"
echo "cd /var/filemanager && docker compose restart"
echo "cd /var/webmail && docker compose restart"
echo "cd /var/www/exemplo.com.br && docker compose restart"
echo ""

echo "🔨 SOLUÇÃO 4: Verificar configuração do proxy no NPM"
echo "──────────────────────────────────────────────────────"
echo "1. Acesse o Nginx Proxy Manager: http://SEU_IP:81"
echo "2. Vá em Proxy Hosts"
echo "3. Para cada host que não funciona, verifique:"
echo "   - Forward Hostname/IP deve ser o nome do container (ex: filemanager)"
echo "   - Forward Port deve estar correto (filemanager=80, webmail-nginx=80, etc)"
echo "   - Em 'Custom Locations' não deve ter configurações incorretas"
echo "   - SSL deve estar configurado corretamente"
echo ""

echo "🔨 SOLUÇÃO 5: Recriar containers do zero"
echo "──────────────────────────────────────────────────────"
echo "# Filemanager:"
echo "cd /var/filemanager && docker compose down && docker compose up -d"
echo ""
echo "# Webmail:"
echo "cd /var/webmail && docker compose down && docker compose up -d"
echo ""
echo "# WordPress:"
echo "cd /var/www/exemplo.com.br && docker compose down && docker compose up -d"
echo ""

echo "═══════════════════════════════════════════════════════"
echo "  📌 PRÓXIMOS PASSOS"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "1. Execute as soluções sugeridas acima"
echo "2. Execute este script novamente para verificar se o problema foi resolvido"
echo "3. Teste o acesso via navegador aos domínios"
echo ""
echo "Se o problema persistir, compartilhe a saída completa deste script."
echo ""
