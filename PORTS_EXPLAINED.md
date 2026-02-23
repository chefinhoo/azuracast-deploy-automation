# Por que Remover Portas Hardcoded do AzuraCast?

## 🎯 Problema

Quando você instala o AzuraCast pela primeira vez, o arquivo `docker-compose.yml` pode vir com portas **hardcoded** (fixas) como:

```yaml
ports:
  - '8000:8000'
  - '8010:8010'
  - '8020:8020'
  # ... até 8999
  - '9990:9990'
```

## ❌ Por que isso é um problema?

### 1. **Conflito com Proxy Reverso**
Se você usa Nginx Proxy Manager (ou qualquer proxy reverso):
- As portas 80/443 do host devem ser usadas pelo proxy
- O AzuraCast deve usar portas internas (8080, 8043)
- Portas fixas em 8000+ podem causar conflitos

### 2. **Impossibilita Gerenciamento Dinâmico**
O AzuraCast precisa **gerenciar portas dinamicamente**:
- Quando você cria uma nova estação, ele atribui portas automaticamente
- Quando você remove uma estação, ele libera as portas
- Com portas hardcoded, o AzuraCast **não consegue fazer isso**

### 3. **Desperdício de Recursos**
Com portas hardcoded 8000-9999 (2000 portas):
- Docker expõe **todas** essas portas no host
- Mesmo que você tenha apenas 2 estações
- Consome memória e sobrecarga de rede desnecessariamente

### 4. **Problemas de Firewall**
- Precisa abrir 2000 portas no firewall
- Aumenta superfície de ataque
- Dificulta gerenciamento de segurança

## ✅ Solução: Portas Gerenciadas pelo AzuraCast

### Como Funciona

1. **Arquivo `.env` define o range:**
```bash
AZURACAST_STATION_PORT_START=9000
AZURACAST_STATION_PORT_END=9999
```

2. **AzuraCast gerencia automaticamente:**
- Cria estação → atribui porta livre do range (ex: 9000, 9005, 9010)
- Remove estação → libera a porta
- Atualiza docker-compose.yml dinamicamente

3. **Somente portas necessárias são expostas:**
- Se você tem 3 estações: apenas 3 portas expostas
- Se você tem 50 estações: apenas 50 portas expostas

### Exemplo Prático

**Antes (hardcoded):**
```yaml
# docker-compose.yml - 2000 linhas de portas fixas
ports:
  - '8000:8000'
  - '8010:8010'
  - '8020:8020'
  # ... 1997 linhas...
  - '9990:9990'
```

**Depois (gerenciado):**
```yaml
# docker-compose.yml - apenas portas usadas
ports:
  - '8080:80'    # HTTP
  - '8043:443'   # HTTPS
  - '2022:2022'  # SFTP
  - '9000:9000'  # Estação 1
  - '9005:9005'  # Estação 2
  - '9010:9010'  # Estação 3
```

## 🔧 O que o Script Faz

### `scripts/install.sh`
```bash
# Remove APENAS portas de estações (8000-9999)
# Preserva portas do sistema (HTTP, HTTPS, SFTP)
if (port >= 8000 && port <= 9999 && port != http_port && port != https_port && port != sftp_port) {
    next  # Remove esta linha
}
```

### O que é PRESERVADO:
- ✅ `8080:80` (HTTP do AzuraCast)
- ✅ `8043:443` (HTTPS do AzuraCast)
- ✅ `2022:2022` (SFTP para upload)

### O que é REMOVIDO:
- ❌ `8000:8000` até `9999:9999` (portas de estações fixas)

## 📋 Logs de Saída

Você verá no log da instalação:

```
[ℹ] Corrigindo portas de estações no docker-compose.yml...
[✓] Portas hardcoded removidas do docker-compose.yml
[ℹ] As portas de estações 9000-9999 serão gerenciadas pelo AzuraCast automaticamente
```

Isso significa:
- ✅ Docker-compose.yml limpo de portas fixas
- ✅ AzuraCast vai gerenciar portas dinamicamente
- ✅ Você pode criar/remover estações livremente

## 🎛️ Como o AzuraCast Gerencia Portas

1. **Criar Estação:**
   - Você cria "Radio Gospel" no painel
   - AzuraCast atribui porta livre: 9000
   - Atualiza docker-compose.yml: adiciona `9000:9000`
   - Reinicia container (opcional)

2. **Criar Outra Estação:**
   - Você cria "Radio Rock" no painel
   - AzuraCast atribui próxima livre: 9005
   - Atualiza docker-compose.yml: adiciona `9005:9005`

3. **Remover Estação:**
   - Você remove "Radio Gospel"
   - AzuraCast libera porta 9000
   - Remove do docker-compose.yml

## 🛡️ Segurança e Firewall

### Com Proxy Reverso (Recomendado)

```bash
# Bloquear acesso direto às portas de streaming por IP
iptables -A INPUT -p tcp --dport 9000:9999 -j DROP
iptables -A INPUT -p tcp --dport 8080 -j DROP
iptables -A INPUT -p tcp --dport 8043 -j DROP

# Permitir apenas via localhost (para proxy)
iptables -I INPUT -i lo -j ACCEPT

# Permitir tráfego Docker interno
iptables -I INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
```

O script de instalação faz isso automaticamente quando `BLOCK_DIRECT_AZURACAST_ACCESS=1`.

### Portas que DEVEM estar abertas:
- ✅ 80 (HTTP do proxy)
- ✅ 443 (HTTPS do proxy)
- ✅ 81 (Admin do Nginx Proxy Manager)

### Portas que PODEM estar bloqueadas:
- ❌ 8080 (HTTP interno AzuraCast)
- ❌ 8043 (HTTPS interno AzuraCast)
- ❌ 9000-9999 (Streaming - acessar via proxy/domínio)

## 🔍 Verificar Portas Atuais

```bash
# Ver portas expostas do container AzuraCast
docker port azuracast

# Saída exemplo:
2022/tcp -> 0.0.0.0:2022
2022/tcp -> [::]:2022
8043/tcp -> 0.0.0.0:8043
8043/tcp -> [::]:8043
8080/tcp -> 0.0.0.0:8080
8080/tcp -> [::]:8080
9000/tcp -> 0.0.0.0:9000  # Estação 1
9005/tcp -> 0.0.0.0:9005  # Estação 2
```

## 🆘 Problemas Comuns

### "Minhas estações não aparecem nas portas"

**Causa:** Docker-compose.yml com portas hardcoded antigas

**Solução:**
```bash
cd /var/azuracast
sudo bash fix_azuracast_ports.sh
```

### "Erro ao criar nova estação"

**Causa:** Sem portas livres no range configurado

**Solução:**
1. Aumentar o range no `.env`:
```bash
AZURACAST_STATION_PORT_END=19999  # Era 9999
```

2. Reiniciar:
```bash
docker compose down
docker compose up -d
```

### "Quer usar portas personalizadas por estação"

Você pode fazer isso manualmente no painel do AzuraCast:
- Admin → Stations → Edit Station → Broadcasting
- Mudar porta de streaming
- AzuraCast atualiza automaticamente

## 📚 Referências

- [AzuraCast Docker Documentation](https://www.azuracast.com/docs/administration/docker/)
- [Docker Port Mapping](https://docs.docker.com/config/containers/container-networking/#published-ports)
- [Proxy Setup Guide](PROXY_SETUP.md)

## ✅ Resumo

**Por que remover portas hardcoded?**
1. ✅ Permite gerenciamento dinâmico pelo AzuraCast
2. ✅ Reduz uso de recursos (só expõe portas necessárias)
3. ✅ Facilita uso com proxy reverso
4. ✅ Melhora segurança (menos portas expostas)
5. ✅ Evita conflitos de portas
6. ✅ Simplifica gerenciamento de firewall

**É seguro remover?**
- ✅ Sim! O AzuraCast foi projetado para gerenciar portas dinamicamente
- ✅ Portas do sistema (8080, 8043, 2022) são preservadas
- ✅ Portas de estações são adicionadas conforme necessário

**Preciso fazer algo manual?**
- ❌ Não! O script faz tudo automaticamente
- ✅ Apenas crie/remova estações normalmente no painel
- ✅ AzuraCast cuida das portas
