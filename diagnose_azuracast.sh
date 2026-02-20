#!/bin/bash
# Script para diagnosticar status do AzuraCast após instalação

set -euo pipefail

AZURACAST_DIR="${AZURACAST_DIR:-/var/azuracast}"

echo "========================================="
echo "Diagnóstico do AzuraCast"
echo "========================================="
echo ""

echo "1️⃣ Verificando estrutura de diretórios..."
echo ""
if [ -d "$AZURACAST_DIR" ]; then
    echo "  ✓ Diretório existe: $AZURACAST_DIR"
    echo ""
    echo "  Conteúdo:"
    ls -lah "$AZURACAST_DIR" 2>/dev/null | head -20 || echo "    (sem permissão)"
else
    echo "  ✗ Diretório NÃO existe: $AZURACAST_DIR"
fi

echo ""
echo "2️⃣ Procurando docker-compose.yml..."
find / -name "docker-compose*.yml" -type f 2>/dev/null | grep -i azura || echo "  ✗ Nenhum encontrado com 'azura'"

echo ""
echo "3️⃣ Procurando containers do AzuraCast..."
docker ps -a --filter "name=azuracast" --format "table {{.Names}}\t{{.Status}}\t{{.State}}" || echo "  (Nenhum encontrado)"

echo ""
echo "4️⃣ Verificando arquivo .env..."
if [ -f "$AZURACAST_DIR/.env" ]; then
    echo "  ✓ Arquivo encontrado"
    echo "  Portas configuradas:"
    grep -E "^AZURACAST_(HTTP|HTTPS|SFTP|STATION)" "$AZURACAST_DIR/.env" 2>/dev/null || echo "    (não encontradas)"
else
    echo "  ✗ Arquivo .env NÃO encontrado"
fi

echo ""
echo "5️⃣ Verificando logs de instalação..."
if [ -f /var/log/azuracast-deploy.log ]; then
    echo "  ✓ Log de instalação encontrado"
    echo ""
    echo "  Últimas 30 linhas:"
    tail -30 /var/log/azuracast-deploy.log | sed 's/^/    /'
else
    echo "  ✗ Log NÃO encontrado"
fi

echo ""
echo "========================================="
echo "Próximos passos:"
echo "========================================="
echo ""
echo "Se o AzuraCast não estiver rodando:"
echo ""
echo "1. Verificar documentação do AzuraCast:"
echo "   https://docs.azuracast.com/developers/docker"
echo ""
echo "2. Tentar iniciar manualmente:"
echo "   cd $AZURACAST_DIR"
echo "   docker-compose up -d"
echo ""
echo "3. Verificar logs do Docker:"
echo "   docker logs azuracast-web-1"
echo "   docker logs azuracast"
echo ""
echo "4. Caso não encontre docker-compose.yml:"
echo "   Pode ser que o instalador do AzuraCast usou um"
echo "   diretório diferente. Procure em:"
echo "   - /opt/azuracast"
echo "   - /home/*/azuracast"
echo "   - Qualquer lugar rodando 'find / -name docker-compose.yml'"
echo ""
