#!/bin/bash
# Script de debug para identificar o que está usando as portas do AzuraCast

echo "========================================="
echo "Debug de Portas - AzuraCast"
echo "========================================="
echo ""

PORTS=(8080 8043 9000)

for port in "${PORTS[@]}"; do
    echo "--- Porta $port ---"
    
    # Verificar se está em uso
    if ss -tuln 2>/dev/null | grep -q ":${port} "; then
        echo "❌ PORTA $port ESTÁ EM USO"
        
        # Tentar identificar processo
        echo "Processos:"
        ss -tlnp 2>/dev/null | grep ":${port} " || netstat -tlnp 2>/dev/null | grep ":${port} "
        
        # Verificar containers Docker
        echo ""
        echo "Containers Docker usando a porta:"
        docker ps -a --filter "publish=${port}" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Nenhum encontrado"
        
    else
        echo "✅ Porta $port está LIVRE"
    fi
    echo ""
done

echo "========================================="
echo "Todos os containers Docker:"
echo "========================================="
docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null

echo ""
echo "========================================="
echo "Containers com 'azuracast' no nome:"
echo "========================================="
docker ps -a --filter "name=azuracast" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Nenhum encontrado"

echo ""
echo "========================================="
echo "Soluções:"
echo "========================================="
echo "1. Parar todos os containers do AzuraCast:"
echo "   docker ps -a --filter 'name=azuracast' -q | xargs -r docker rm -f"
echo ""
echo "2. Parar containers usando porta 8043:"
echo "   docker ps -q --filter 'publish=8043' | xargs -r docker stop"
echo "   docker ps -aq --filter 'publish=8043' | xargs -r docker rm -f"
echo ""
echo "3. Limpar tudo do Docker (CUIDADO!):"
echo "   docker system prune -af"
echo ""
