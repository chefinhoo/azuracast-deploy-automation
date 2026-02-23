# 🔧 Guia de Solução de Problemas - Nginx Proxy Manager

## Problema Comum: Sites não acessíveis via proxy

Se você configurou os Proxy Hosts no Nginx Proxy Manager mas os sites não estão acessíveis, siga este guia.

### ✅ Site Funcionando
- ✓ https://daniloramos.dev.br/ → http://azuracast:8080

### ❌ Sites NÃO Funcionando
- ✗ https://files.daniloramos.dev.br/ → http://filemanager:80
- ✗ https://webmail.daniloramos.dev.br/ → http://webmail-nginx:80
- ✗ https://gospelibipitanga.com.br/ → http://wp-app-gospelibipitanga-com-br:80

---

## 🔍 Diagnóstico Rápido

### 1. Execute o script de diagnóstico

```bash
sudo bash scripts/diagnose_proxy.sh
```

Este script vai verificar:
- ✓ Status dos containers (rodando ou parados)
- ✓ Redes Docker
- ✓ Conectividade interna
- ✓ Logs de erros
- ✓ Portas em uso

### 2. Identifique o problema

Os problemas mais comuns são:

#### A) Containers Parados 🛑
**Sintoma**: Container existe mas não está rodando
```
✗ filemanager - PARADO (existe mas não está rodando)
```

**Solução**: Iniciar os containers
```bash
cd /var/filemanager && docker compose up -d
cd /var/webmail && docker compose up -d
cd /var/www/gospelibipitanga.com.br && docker compose up -d
```

#### B) Containers não estão na mesma rede 🌐
**Sintoma**: Container roda mas o proxy não consegue se comunicar

**Solução**: Conectar containers à rede do proxy
```bash
# Descobrir a rede do proxy
PROXY_NETWORK=$(docker inspect -f '{{range $key, $value := .NetworkSettings.Networks}}{{$key}}{{end}}' $(docker ps -qf 'name=proxy') | head -1)

# Conectar containers à rede
docker network connect $PROXY_NETWORK filemanager
docker network connect $PROXY_NETWORK webmail-nginx
docker network connect $PROXY_NETWORK wp-app-gospelibipitanga-com-br
```

#### C) Configuração incorreta no NPM ⚙️
**Sintoma**: Containers rodando, mesma rede, mas ainda não funciona

**Solução**: Verificar configuração no Nginx Proxy Manager

1. Acesse `http://SEU_IP:81`
2. Login: `admin@example.com` / `changeme` (primeira vez)
3. Vá em **Hosts → Proxy Hosts**
4. Para cada host que não funciona, clique em **⋮** → **Edit**
5. Verifique na aba **Details**:
   - **Domain Names**: correto (ex: `files.daniloramos.dev.br`)
   - **Scheme**: `http`
   - **Forward Hostname / IP**: **nome do container** (ex: `filemanager`)
   - **Forward Port**: porta correta (normalmente `80`)
   - **Cache Assets**: ✓ pode estar marcado
   - **Block Common Exploits**: ✓ pode estar marcado
   - **Websockets Support**: ✓ marque se for SPA/aplicação dinâmica

6. Verifique na aba **SSL**:
   - **SSL Certificate**: Let's Encrypt válido
   - **Force SSL**: ✓ marcado
   - **HTTP/2 Support**: ✓ marcado
   - **HSTS Enabled**: ✓ opcional

7. Clique em **Save**

---

## 🚀 Correção Automática

### Opção 1: Correção Rápida (Containers já rodando)

Se os containers já estão rodando mas apenas isolados em redes diferentes:

```bash
sudo bash scripts/quick_fix_networks.sh
```

Este script vai:
1. ✓ Identificar a rede do proxy
2. ✓ Conectar containers à rede do proxy
3. ✓ Exibir status final

**Tempo esperado**: ~30 segundos

### Opção 2: Correção Completa

Para reiniciar containers e corrigir redes:

```bash
sudo bash scripts/fix_proxy_issues.sh
```

Este script vai:
1. ✓ Reiniciar todos os containers necessários
2. ✓ Conectar containers à rede do proxy
3. ✓ Testar conectividade interna
4. ✓ Exibir o status final

**Tempo esperado**: ~5 minutos

---

## � Problema: Containers em Redes Isoladas

### Sintomas
- Containers estão **rodando** mas não acessíveis via proxy
- Erro 502/503 ao tentar acessar os domínios
- Teste de conectividade interna mostra `FALHOU`

### Causa
Os containers foram criados em redes Docker **separadas** e não conseguem se comunicar com o Nginx Proxy Manager.

### Solução Manual

Se preferir fazer manualmente, descubra qual é a rede do proxy:

```bash
# 1. Verificar container do proxy
docker ps -qf 'name=nginx-proxy-manager'

# 2. Ver redes do proxy
docker inspect <ID_DO_PROXY> -f '{{range $key := .NetworkSettings.Networks}}{{$key}} {{end}}'

# 3. Conectar containers à rede
docker network connect <NOME_DA_REDE> filemanager
docker network connect <NOME_DA_REDE> webmail-nginx
docker network connect <NOME_DA_REDE> webmail-db
docker network connect <NOME_DA_REDE> wp-app-gospelibipitanga-com-br

# 4. Verificar se funcionou
docker ps --format "table {{.Names}}\t{{.Networks}}"
```

**Exemplo real:**
```bash
# Se a rede for "proxy_manager_npm_network":
docker network connect proxy_manager_npm_network filemanager
docker network connect proxy_manager_npm_network webmail-nginx
docker network connect proxy_manager_npm_network wp-app-gospelibipitanga-com-br
```

---

Se os scripts não resolverem, siga este checklist:

### 1. Verificar se containers estão rodando
```bash
docker ps | grep -E "filemanager|webmail|roundcube|wp-app"
```
**Esperado**: Cada container deve aparecer com status "Up"

### 2. Verificar logs de erros
```bash
# Filemanager
docker logs filemanager --tail 50

# Webmail
docker logs webmail-nginx --tail 50
docker logs roundcube --tail 50

# WordPress
docker logs wp-app-gospelibipitanga-com-br --tail 50
```

### 3. Testar conectividade interna
```bash
# Do container do proxy, tentar acessar os backends
PROXY_ID=$(docker ps -qf "name=proxy" | head -1)

docker exec $PROXY_ID wget -O- http://filemanager:80
docker exec $PROXY_ID wget -O- http://webmail-nginx:80
docker exec $PROXY_ID wget -O- http://wp-app-gospelibipitanga-com-br:80
```

### 4. Verificar DNS (se usar domínio personalizado)
```bash
# Verificar se o domínio aponta para o IP do servidor
dig +short files.daniloramos.dev.br
dig +short webmail.daniloramos.dev.br
dig +short gospelibipitanga.com.br
```
**Esperado**: Deve retornar o IP público do servidor

### 5. Verificar firewall
```bash
# Verificar se as portas 80 e 443 estão abertas
sudo ufw status

# Se necessário, abrir portas
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

---

## 🎯 Tabela de Referência

| Serviço | Container | Porta Interna | Hostname para NPM | URL Externa |
|---------|-----------|---------------|-------------------|-------------|
| AzuraCast | `azuracast` | 8080 | `azuracast:8080` | daniloramos.dev.br |
| Filemanager | `filemanager` | 80 | `filemanager:80` | files.daniloramos.dev.br |
| Webmail | `webmail-nginx` | 80 | `webmail-nginx:80` | webmail.daniloramos.dev.br |
| WordPress | `wp-app-gospelibipitanga-com-br` | 80 | `wp-app-gospelibipitanga-com-br:80` | gospelibipitanga.com.br |

---

## 🔄 Reiniciar Tudo do Zero

Se nada funcionar, recrie os containers:

```bash
# Filemanager
cd /var/filemanager
docker compose down -v
docker compose up -d

# Webmail
cd /var/webmail
docker compose down -v
docker compose up -d

# WordPress
cd /var/www/gospelibipitanga.com.br
docker compose down -v
docker compose up -d

# Aguardar 2 minutos
sleep 120

# Reconectar à rede do proxy
PROXY_NETWORK=$(docker inspect -f '{{range $key, $value := .NetworkSettings.Networks}}{{$key}}{{end}}' $(docker ps -qf 'name=proxy') | head -1)
docker network connect $PROXY_NETWORK filemanager
docker network connect $PROXY_NETWORK webmail-nginx
docker network connect $PROXY_NETWORK wp-app-gospelibipitanga-com-br
```

---

## 📞 Ainda com problemas?

1. Execute o diagnóstico completo:
   ```bash
   sudo bash scripts/diagnose_proxy.sh > diagnostic_report.txt
   ```

2. Compartilhe o arquivo `diagnostic_report.txt` para análise

3. Verifique os logs do Nginx Proxy Manager:
   ```bash
   docker logs $(docker ps -qf "name=proxy") --tail 100
   ```

---

## 💡 Dicas

- **Sempre aguarde 1-2 minutos** após reiniciar containers antes de testar
- **Limpe o cache do navegador** (Ctrl+F5) ao testar
- **Teste em modo anônimo** para evitar problemas de cache
- **Verifique os logs** sempre que algo não funcionar
- **Containers devem estar na mesma rede** que o Nginx Proxy Manager

---

## 📚 Documentações Relacionadas

- [FILEMANAGER_SETUP.md](FILEMANAGER_SETUP.md) - Configuração do Filebrowser
- [WEBMAIL_SETUP.md](WEBMAIL_SETUP.md) - Configuração do Roundcube
- [README.md](README.md) - Documentação geral do projeto
