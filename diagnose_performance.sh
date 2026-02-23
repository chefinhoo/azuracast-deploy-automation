#!/usr/bin/env bash
#
# Diagnóstico de Performance - WordPress e AzuraCast
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ DIAGNÓSTICO DE PERFORMANCE                       ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# 1. Recursos do Sistema
echo -e "${CYAN}[1] RECURSOS DO SISTEMA${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# CPU
echo -e "\n${BLUE}CPU:${NC}"
nproc
lscpu | grep "Model name" || true
echo ""

# Memória RAM
echo -e "${BLUE}Memória RAM:${NC}"
free -h
echo ""

# Disco
echo -e "${BLUE}Espaço em Disco:${NC}"
df -h / /var
echo ""

# 2. Uso de Recursos Docker
echo -e "${CYAN}[2] USO DE RECURSOS DOCKER${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if ! command -v docker &>/dev/null; then
    echo -e "${RED}✗ Docker não está instalado${NC}"
else
    echo -e "\n${BLUE}Containers em execução:${NC}"
    docker ps --format "table {{.Names}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.Status}}" 2>/dev/null || echo "Erro ao obter stats"
    echo ""
    
    # Stats em tempo real (5 segundos)
    echo -e "${BLUE}Coletando stats em tempo real (5s)...${NC}"
    timeout 5s docker stats --no-stream 2>/dev/null || echo "Erro ao coletar stats"
fi
echo ""

# 3. Verificar WordPress
echo -e "${CYAN}[3] WORDPRESS${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

WP_DIRS=(/var/www/*)
wp_found=false

for wp_dir in "${WP_DIRS[@]}"; do
    if [ -d "$wp_dir" ] && [ -f "$wp_dir/docker-compose.yml" ]; then
        wp_found=true
        domain=$(basename "$wp_dir")
        container_name="wp-app-${domain//./-}"
        
        echo -e "\n${BLUE}WordPress: $domain${NC}"
        
        if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
            echo -e "${GREEN}✓ Container rodando${NC}"
            
            # Verificar configuração PHP
            echo -e "\n${YELLOW}Configuração PHP:${NC}"
            docker exec "$container_name" php -i 2>/dev/null | grep -E "memory_limit|max_execution_time|upload_max_filesize|post_max_size" || echo "Erro ao obter configuração PHP"
            
            # Verificar OPcache
            echo -e "\n${YELLOW}OPcache:${NC}"
            if docker exec "$container_name" php -m 2>/dev/null | grep -q "Zend OPcache"; then
                echo -e "${GREEN}✓ OPcache habilitado${NC}"
                docker exec "$container_name" php -i 2>/dev/null | grep -E "opcache.memory_consumption|opcache.max_accelerated_files" || true
            else
                echo -e "${RED}✗ OPcache NÃO está habilitado${NC}"
                echo -e "${YELLOW}  Recomendação: Ative o OPcache para melhor performance${NC}"
            fi
            
            # Verificar tamanho do banco de dados
            echo -e "\n${YELLOW}Banco de Dados:${NC}"
            db_container="wp-db-${domain//./-}"
            if docker ps --format '{{.Names}}' | grep -q "^${db_container}$"; then
                creds_file="$wp_dir/wordpress-credentials.txt"
                if [ -f "$creds_file" ]; then
                    db_name=$(grep '^WORDPRESS_DB_NAME=' "$creds_file" | cut -d= -f2)
                    db_user=$(grep '^WORDPRESS_DB_USER=' "$creds_file" | cut -d= -f2)
                    db_password=$(grep '^WORDPRESS_DB_PASSWORD=' "$creds_file" | cut -d= -f2)
                    
                    db_size=$(docker exec "$db_container" mysql -u"$db_user" -p"$db_password" "$db_name" -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.TABLES WHERE table_schema = '$db_name';" 2>/dev/null | tail -1 || echo "N/A")
                    echo "  Tamanho do banco: ${db_size} MB"
                fi
            fi
            
            # Teste de resposta
            echo -e "\n${YELLOW}Teste de Resposta HTTP:${NC}"
            response_time=$(docker exec nginx-proxy-manager sh -lc "time curl -o /dev/null -s -w '%{time_total}s\n' http://${container_name}:80" 2>&1 | grep "real" | awk '{print $2}' || echo "N/A")
            echo "  Tempo de resposta: $response_time"
            
        else
            echo -e "${RED}✗ Container não está rodando${NC}"
        fi
    fi
done

if [ "$wp_found" = false ]; then
    echo -e "${YELLOW}Nenhum WordPress encontrado${NC}"
fi
echo ""

# 4. Verificar AzuraCast
echo -e "${CYAN}[4] AZURACAST${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if docker ps --format '{{.Names}}' | grep -q "^azuracast$"; then
    echo -e "${GREEN}✓ Container rodando${NC}"
    
    # Teste de resposta
    echo -e "\n${YELLOW}Teste de Resposta HTTP:${NC}"
    http_code=$(docker exec nginx-proxy-manager sh -lc "curl -o /dev/null -s -w '%{http_code}' --max-time 5 http://azuracast:8080" 2>/dev/null || echo "000")
    response_time=$(docker exec nginx-proxy-manager sh -lc "curl -o /dev/null -s -w '%{time_total}s\n' --max-time 5 http://azuracast:8080" 2>/dev/null || echo "timeout")
    
    echo "  HTTP Status: $http_code"
    echo "  Tempo de resposta: $response_time"
    
    # Verificar logs de erro
    echo -e "\n${YELLOW}Últimos erros nos logs (se houver):${NC}"
    docker logs azuracast 2>&1 | grep -i "error\|warning\|fatal" | tail -5 || echo "  Nenhum erro recente"
    
else
    echo -e "${RED}✗ AzuraCast não está rodando${NC}"
fi
echo ""

# 5. Nginx Proxy Manager
echo -e "${CYAN}[5] NGINX PROXY MANAGER${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if docker ps --format '{{.Names}}' | grep -q "^nginx-proxy-manager$"; then
    echo -e "${GREEN}✓ Container rodando${NC}"
    
    # Verificar configuração Nginx
    echo -e "\n${YELLOW}Configuração Nginx:${NC}"
    if docker exec nginx-proxy-manager nginx -T 2>/dev/null | grep -q "worker_processes"; then
        workers=$(docker exec nginx-proxy-manager nginx -T 2>/dev/null | grep "worker_processes" | head -1 | awk '{print $2}' | tr -d ';')
        echo "  Worker processes: $workers"
    else
        echo "  Worker processes: padrão (1)"
    fi
    
    if docker exec nginx-proxy-manager nginx -T 2>/dev/null | grep -q "worker_connections"; then
        connections=$(docker exec nginx-proxy-manager nginx -T 2>/dev/null | grep "worker_connections" | head -1 | awk '{print $2}' | tr -d ';')
        echo "  Worker connections: $connections"
    else
        echo "  Worker connections: padrão (768)"
    fi
    
    # Verificar otimizações
    echo -e "\n${YELLOW}Otimizações:${NC}"
    if docker exec nginx-proxy-manager nginx -T 2>/dev/null | grep -q "gzip on"; then
        echo -e "  ${GREEN}✓${NC} Gzip habilitado"
    else
        echo -e "  ${RED}✗${NC} Gzip desabilitado"
    fi
    
    if docker exec nginx-proxy-manager nginx -T 2>/dev/null | grep -q "keepalive"; then
        echo -e "  ${GREEN}✓${NC} Keepalive habilitado"
    else
        echo -e "  ${YELLOW}!${NC} Keepalive padrão"
    fi
    
    # Verificar timeouts
    if docker exec nginx-proxy-manager nginx -T 2>/dev/null | grep -q "proxy_read_timeout"; then
        timeout=$(docker exec nginx-proxy-manager nginx -T 2>/dev/null | grep "proxy_read_timeout" | head -1 | awk '{print $2}' | tr -d ';')
        echo "  Proxy read timeout: $timeout"
    else
        echo "  Proxy read timeout: padrão (60s)"
    fi
    
    # Verificar erros nos logs
    echo -e "\n${YELLOW}Últimos erros nos logs (se houver):${NC}"
    docker logs nginx-proxy-manager 2>&1 | grep -i "error\|warning" | tail -5 || echo "  Nenhum erro recente"
else
    echo -e "${RED}✗ Nginx Proxy Manager não está rodando${NC}"
fi
echo ""

# 6. Rede e Conectividade
echo -e "${CYAN}[6] REDE E CONECTIVIDADE${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "\n${YELLOW}Teste de DNS externo:${NC}"
dig_time=$(dig @8.8.8.8 google.com +stats 2>/dev/null | grep "Query time" | awk '{print $4 " ms"}' || echo "N/A")
echo "  Query time: $dig_time"

echo -e "\n${YELLOW}Teste de conectividade externa:${NC}"
ping_time=$(ping -c 3 8.8.8.8 2>/dev/null | tail -1 | awk -F'/' '{print $5 " ms"}' || echo "N/A")
echo "  Ping médio: $ping_time"
echo ""

# 7. Recomendações
echo -e "${CYAN}[7] RECOMENDAÇÕES DE OTIMIZAÇÃO${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verificar memória disponível
total_mem=$(free -m | awk '/^Mem:/{print $2}')
if [ "$total_mem" -lt 2048 ]; then
    echo -e "${YELLOW}⚠ Memória RAM baixa (<2GB)${NC}"
    echo "  • Considere aumentar a RAM do servidor"
    echo "  • Limite o número de containers simultâneos"
fi

# Verificar espaço em disco
disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$disk_usage" -gt 80 ]; then
    echo -e "${YELLOW}⚠ Disco quase cheio (>80%)${NC}"
    echo "  • Limpe logs antigos: docker system prune -a"
    echo "  • Verifique backups desnecessários"
fi

echo ""
echo -e "${GREEN}Para otimizar Nginx Proxy Manager:${NC}"
echo "  sudo bash optimize_npm.sh"
echo ""
echo -e "${GREEN}Para otimizar WordPress:${NC}"
echo "  sudo bash optimize_wordpress.sh"
echo ""
echo -e "${GREEN}Para ver logs detalhados:${NC}"
echo "  docker logs -f wp-app-<dominio>"
echo "  docker logs -f azuracast"
echo "  docker logs -f nginx-proxy-manager"
echo ""

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ DIAGNÓSTICO CONCLUÍDO                            ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
