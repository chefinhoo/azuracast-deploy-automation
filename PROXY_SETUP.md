# Guia de Configuração do Proxy Reverso

Este guia ajuda a configurar o Nginx Proxy Manager para trabalhar com o AzuraCast.

## 🔍 Diagnóstico Antes de Configurar

Antes de adicionar o proxy, execute o script de diagnóstico:

```bash
cd /opt/azuracast-deploy-automation
sudo bash diagnose_proxy.sh azura.daniloramos.dev.br
```

Este script irá:
- ✅ Verificar se os containers estão rodando
- ✅ Testar conectividade HTTP/HTTPS interna
- ✅ Verificar resolução DNS
- ✅ Fornecer a configuração recomendada

## 📝 Configuração Passo a Passo

### 1. Acesse o Nginx Proxy Manager

Acesse: `http://SEU_IP_PUBLICO:81`

**Login padrão (primeira vez):**
- Email: `admin@example.com`
- Senha: `changeme`

**⚠️ IMPORTANTE:** Troque a senha após o primeiro login!

### 2. Adicione um Proxy Host

Vá em **Hosts** → **Proxy Hosts** → **Add Proxy Host**

#### Aba "Details"

| Campo | Valor Recomendado |
|-------|-------------------|
| **Domain Names** | `azura.daniloramos.dev.br` |
| **Scheme** | `http` ⚠️ (não https) |
| **Forward Hostname / IP** | `azuracast` |
| **Forward Port** | `8080` |
| **Cache Assets** | ✅ Marcado |
| **Block Common Exploits** | ✅ Marcado |
| **Websockets Support** | ✅ Marcado |

#### Aba "SSL"

| Campo | Valor |
|-------|-------|
| **SSL Certificate** | Request a new SSL Certificate |
| **Force SSL** | ✅ Marcado |
| **HTTP/2 Support** | ✅ Marcado |
| **HSTS Enabled** | ✅ Marcado |
| **HSTS Subdomains** | ⬜ Não marcado (a menos que use subdomínios) |
| **Email Address for Let's Encrypt** | seu-email@exemplo.com |
| **I Agree to the Terms of Service** | ✅ Marcado |

### 3. Salve e Teste

Clique em **Save** e aguarde o certificado SSL ser emitido.

Teste acessando: `https://azura.daniloramos.dev.br`

## ❌ Problemas Comuns

### Erro "502 Bad Gateway"

**Causa:** AzuraCast ainda está iniciando ou não está respondendo.

**Solução:**
```bash
# Verificar logs
docker logs -f azuracast

# Aguardar inicialização completa (5-10 minutos)
# Ou reiniciar
cd /var/azuracast
docker compose restart
```

### Erro "Internal Error" ao adicionar SSL

**Causas possíveis:**
1. Domínio não está apontando para o IP do servidor
2. Porta 80 bloqueada no firewall (Let's Encrypt precisa da 80)
3. Let's Encrypt rate limit atingido

**Diagnóstico:**
```bash
# Verificar DNS
nslookup azura.daniloramos.dev.br

# Verificar se porta 80 está acessível externamente
curl -I http://SEU_IP_PUBLICO

# Verificar firewall
sudo ufw status
```

**Solução temporária (sem SSL):**
Configure temporariamente sem SSL para testar:
- Desmarcar "Force SSL" na aba SSL
- Testar com `http://azura.daniloramos.dev.br`

### Erro "Invalid SSL Certificate"

**Causa:** Usando `https` no campo Scheme quando deveria ser `http`.

**Solução:**
- Edite o Proxy Host
- Mude **Scheme** para `http`
- Deixe o SSL apenas na aba SSL do NPM

### Websockets não funcionam (streaming interrompido)

**Solução:** Certifique-se de que **Websockets Support** está marcado.

## 🔧 Configuração Avançada

### Custom Nginx Configuration

Se precisar de configurações adicionais, adicione em **Advanced**:

```nginx
# Aumentar timeout para streaming
proxy_read_timeout 3600s;
proxy_connect_timeout 3600s;
proxy_send_timeout 3600s;

# Headers adicionais
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Real-IP $remote_addr;
```

### Quando o NPM não encontra o AzuraCast

Em instalação com Docker, o NPM também roda em container.
Nesse cenário, `localhost` aponta para o próprio NPM (não para o AzuraCast).

Use sempre `azuracast` no campo **Forward Hostname / IP**.

Se necessário, conecte o NPM na mesma rede do AzuraCast:

```bash
docker network connect azuracast_default nginx-proxy-manager
docker exec nginx-proxy-manager sh -lc 'curl -I --max-time 8 http://azuracast:8080'
```

Como fallback, você pode usar o IP do container AzuraCast:

```bash
# Obter IP do container AzuraCast
docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' azuracast
```

Use esse IP no campo **Forward Hostname / IP**.

## 📱 Verificação Final

Depois de configurado, teste:

- ✅ `https://azura.daniloramos.dev.br` - Deve redirecionar e carregar
- ✅ Certificado SSL válido (cadeado verde no navegador)
- ✅ Streaming de rádio funciona
- ✅ Upload de arquivos funciona

## 🆘 Ainda com Problemas?

Execute o diagnóstico completo:

```bash
cd /opt/azuracast-deploy-automation
sudo bash diagnose_proxy.sh azura.daniloramos.dev.br
```

E verifique os logs:

```bash
# Logs do AzuraCast
docker logs -f azuracast

# Logs do Nginx Proxy Manager
docker logs -f nginx-proxy-manager
```

## 📚 Recursos Adicionais

- [Documentação AzuraCast sobre Proxy Reverso](https://www.azuracast.com/docs/administration/docker/#using-a-reverse-proxy)
- [Nginx Proxy Manager Docs](https://nginxproxymanager.com/guide/)
- [Troubleshooting Let's Encrypt](https://letsencrypt.org/docs/challenge-types/)
