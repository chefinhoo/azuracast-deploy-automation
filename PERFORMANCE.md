# Guia de Performance e Otimização

Se seus sites (WordPress, AzuraCast) estão lentos, este guia vai te ajudar a diagnosticar e resolver.

## 🔍 Diagnóstico Rápido

```bash
cd azuracast-deploy-automation
sudo bash diagnose_performance.sh
```

Este comando irá analisar:
- ✅ Recursos do sistema (CPU, RAM, disco)
- ✅ Uso por container Docker
- ✅ Configurações PHP e OPcache
- ✅ Tamanho de banco de dados
- ✅ Tempos de resposta
- ✅ Configurações do Nginx Proxy Manager
- ✅ Logs de erro

## 🎯 Cenários Comuns

### Cenário 1: Todos os sites estão lentos

**Causa provável:** Nginx Proxy Manager sem otimizações

**Solução:**
```bash
sudo bash optimize_npm.sh
```

**O que isso faz:**
- Worker processes otimizados (usa todos os CPUs)
- Aumenta conexões simultâneas (768 → 4096)
- Buffers maiores para uploads
- Timeouts adequados para streaming
- Keepalive habilitado
- DNS resolver rápido
- Gzip compression

**Impacto:** Afeta todos os sites que passam pelo proxy

---

### Cenário 2: Só o WordPress está lento

**Causa provável:** Configurações PHP não otimizadas

**Solução:**
```bash
sudo bash optimize_wordpress.sh
```

**O que isso faz:**
- Ativa OPcache (cache de código PHP)
- Aumenta memória PHP (256MB)
- Aumenta limite de upload (64MB)
- Configura cache de navegador
- Ativa compressão GZIP

**Impacto:** Afeta apenas o WordPress especificado

---

### Cenário 3: Sistema com poucos recursos

**Sintomas:**
- RAM < 2GB
- Disco > 80% cheio
- Swap usage alto

**Soluções:**

1. **Limpar cache do Docker:**
```bash
docker system prune -a -f
docker volume prune -f
```

2. **Limitar recursos dos containers:**
```bash
# Editar /var/proxy_manager/docker-compose.yml
# As configurações de deploy.resources já estão aplicadas
```

3. **Desativar containers não usados:**
```bash
# Se não usa WordPress:
cd /var/www/seudominio.com
docker compose down
```

4. **Upgrade do servidor:**
- Mínimo recomendado: 2GB RAM, 2 CPUs, 20GB disco

---

## 📊 Métricas de Performance

### Tempos de Resposta Aceitáveis

| Serviço | Bom | Aceitável | Lento |
|---------|-----|-----------|-------|
| WordPress | < 0.5s | 0.5-2s | > 2s |
| AzuraCast | < 1s | 1-3s | > 3s |
| NPM Admin | < 0.5s | 0.5-1s | > 1s |

### Uso de Recursos Normal

| Container | RAM | CPU |
|-----------|-----|-----|
| nginx-proxy-manager | 100-300MB | 5-15% |
| nginx-proxy-manager-db | 100-200MB | 2-10% |
| wp-app | 100-256MB | 5-20% |
| wp-db | 100-300MB | 5-15% |
| azuracast | 500MB-1GB | 10-30% |

---

## 🔧 Otimizações Manuais Avançadas

### 1. NPM - Configurações Customizadas por Proxy Host

No painel do NPM, ao configurar um Proxy Host, adicione em **Custom Nginx Configuration**:

```nginx
# Aumentar timeout para streaming
proxy_read_timeout 3600s;
proxy_connect_timeout 3600s;
proxy_send_timeout 3600s;

# Cache de arquivos estáticos
location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|svg)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    proxy_pass http://backend;
}

# Habilitar HTTP/2
http2 on;
```

### 2. WordPress - Plugins Recomendados

**Cache:**
- WP Super Cache (leve)
- W3 Total Cache (completo)
- LiteSpeed Cache (se usar LiteSpeed)

**Otimização de Imagens:**
- Imagify
- ShortPixel
- EWWW Image Optimizer

**CDN:**
- Cloudflare (gratuito)
- BunnyCDN
- KeyCDN

**Database:**
- WP-Optimize (limpar banco)

### 3. AzuraCast - Configurações

Em `/var/azuracast/.env`:

```bash
# Aumentar workers PHP-FPM
PHP_FPM_MAX_CHILDREN=20
PHP_FPM_START_SERVERS=5
PHP_FPM_MIN_SPARE_SERVERS=2
PHP_FPM_MAX_SPARE_SERVERS=10

# Memória PHP
PHP_MEMORY_LIMIT=256M

# Redis para cache (se disponível)
ENABLE_REDIS=true
```

Depois de editar:
```bash
cd /var/azuracast
docker compose down
docker compose up -d
```

---

## 🐛 Troubleshooting

### Problema: "502 Bad Gateway"

**Causas:**
1. Backend não está respondendo
2. Timeout muito curto
3. Container parou

**Diagnóstico:**
```bash
# Verificar se containers estão rodando
docker ps

# Ver logs do NPM
docker logs nginx-proxy-manager --tail 50

# Testar conectividade interna
docker exec nginx-proxy-manager curl -I http://azuracast:8080
```

**Soluções:**
- Reiniciar container backend
- Aumentar timeouts no NPM
- Verificar rede Docker

---

### Problema: "504 Gateway Timeout"

**Causa:** Request demorou muito para processar

**Solução:**
```bash
# Aumentar timeouts
sudo bash optimize_npm.sh
```

Ou manualmente no Custom Nginx Configuration:
```nginx
proxy_read_timeout 300s;
proxy_connect_timeout 300s;
```

---

### Problema: Alto uso de CPU

**Diagnóstico:**
```bash
# Ver uso por container
docker stats

# Ver processos no container
docker exec <container> top
```

**Soluções WordPress:**
- Desativar plugins pesados
- Implementar cache
- Otimizar queries do banco

**Soluções AzuraCast:**
- Reduzir número de estações
- Baixar bitrate de streaming
- Desativar recursos não usados

---

### Problema: Alto uso de RAM

**Soluções imediatas:**
```bash
# Limpar cache do sistema
sync && echo 3 > /proc/sys/vm/drop_caches

# Reiniciar containers
docker restart <container>
```

**Soluções permanentes:**
- Limitar recursos no docker-compose (já aplicado)
- Upgrade RAM do servidor
- Reduzir número de containers

---

## 📈 Monitoramento Contínuo

### Ferramentas Recomendadas

**Netdata** (monitoramento em tempo real):
```bash
bash <(curl -Ss https://my-netdata.io/kickstart.sh)
```

**Glances** (alternativa mais leve):
```bash
apt-get install glances
glances
```

**Docker Stats em loop:**
```bash
watch -n 5 docker stats --no-stream
```

---

## 🎯 Checklist de Otimização

- [ ] Executar `diagnose_performance.sh`
- [ ] Aplicar `optimize_npm.sh`
- [ ] Aplicar `optimize_wordpress.sh` (se usa WordPress)
- [ ] Verificar recursos do sistema (RAM, CPU, disco)
- [ ] Limpar cache Docker se disco > 80%
- [ ] Configurar cache no WordPress (plugin)
- [ ] Otimizar imagens antes de upload
- [ ] Configurar CDN (Cloudflare)
- [ ] Monitorar periodicamente com docker stats
- [ ] Revisar logs regularmente

---

## 📚 Referências

- [Docker Resource Constraints](https://docs.docker.com/config/containers/resource_constraints/)
- [Nginx Performance Tuning](https://www.nginx.com/blog/tuning-nginx/)
- [WordPress Performance Best Practices](https://wordpress.org/support/article/optimization/)
- [AzuraCast Performance Tips](https://www.azuracast.com/docs/administration/performance/)

---

## 🆘 Suporte

Se após seguir este guia os problemas persistirem:

1. Execute o diagnóstico completo:
```bash
sudo bash diagnose_performance.sh > diagnostico.txt
```

2. Colete logs:
```bash
docker logs nginx-proxy-manager > npm.log 2>&1
docker logs azuracast > azuracast.log 2>&1
docker logs wp-app-* > wordpress.log 2>&1
```

3. Abra uma issue no GitHub com os arquivos gerados
