# Automação de Deploy AzuraCast

[![Licença: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Automação completa para instalar e gerenciar **AzuraCast** + **Nginx Proxy Manager** + **Roundcube Webmail** + **Filebrowser** + **Servidor de E-mail** no **Ubuntu (ARM/x86)**.

---

## 📑 Índice

- [O Que Este Sistema Faz](#-o-que-este-sistema-faz)
- [Requisitos](#️-requisitos)
- [Instalação Rápida](#-instalação-rápida)
- [Primeiros Passos Após Instalação](#-primeiros-passos-após-instalação)
- [Configurar Nginx Proxy Manager](#-configurar-nginx-proxy-manager)
  - [Criar Proxy Hosts para Cada Serviço](#criar-proxy-host-passo-a-passo)
  - [Configurar SSL/Let's Encrypt](#criar-proxy-host-passo-a-passo)
- [Gerenciar Contas e Usuários](#-gerenciar-contas-e-usuários)
  - [Criar Contas de E-mail](#criar-contas-de-e-mail)
  - [Criar Usuários no Filebrowser](#criar-usuários-no-filebrowser)
- [Adicionar Novos Domínios](#-adicionar-novos-domínios)
- [Servidor de E-mail](#-servidor-de-e-mail-opcional)
- [Documentação Completa](#-documentação)
- [Solução de Problemas](#-solução-de-problemas)
- [Gerenciamento de Firewall](#️-gerenciamento-de-firewall)
- [Desinstalar](#️-desinstalar)

---

## 🎯 O Que Este Sistema Faz

### Instalação e Configuração Automatizada
- ✅ Docker Engine e Docker Compose
- ✅ Nginx Proxy Manager (proxy reverso com SSL/Let's Encrypt)
- ✅ AzuraCast (servidor de rádio online)
- ✅ Roundcube (cliente webmail)
- ✅ Filebrowser (gerenciador de arquivos)
- ✅ WordPress (multi-domínio com MariaDB)
- ✅ **Servidor de E-mail** (Postfix + Dovecot + PostfixAdmin) - opcional
- ✅ Proteção de firewall (portas internas)

### Serviços Instalados

| Serviço | Localização | Porta Interna | Acesso |
|---------|-------------|---------------|--------|
| **Nginx Proxy Manager** | `/var/proxy_manager` | 81 (admin) | http://ip:81 |
| **AzuraCast** | `/var/azuracast` | 8080/8043 | via proxy |
| **Roundcube** | `/var/webmail` | 80 | webmail.dominio.com.br |
| **Filebrowser** | `/var/filemanager` | 80 | files.dominio.com.br |
| **WordPress** | `/var/www/` | 80 | dominio.com.br |
| **PostfixAdmin** | `/var/mailserver` | 80 | mail.dominio.com.br |

## ⚙️ Requisitos

- **Ubuntu 20.04+** (x86 ou ARM)
- **Acesso sudo** (privilégios de root)
- **Portas disponíveis**: 80, 443, 81 (proxy) + 25, 587, 993 (email) + 8080, 8043, 2022, 9000-9999 (interno)
- **Conexão com internet** (para download de imagens Docker)
- **Domínio** apontando para o IP público do servidor (para SSL com Let's Encrypt)

## 🚀 Instalação Rápida

```bash
git clone https://github.com/chefinhoo/azuracast-deploy-automation.git
cd azuracast-deploy-automation
sudo bash scripts/install.sh
```

A instalação é **totalmente interativa** e solicita as informações necessárias.

### Instalação com Servidor de E-mail

Para incluir um servidor de e-mail completo durante a instalação:

```bash
export INSTALL_MAILSERVER=1
export MAIL_DOMAIN="seudominio.com.br"
sudo bash scripts/install.sh
```

**Requisitos:** Porta 25 aberta, DNS configurado (registros MX, A, SPF)

### ✅ Primeiros Passos Após Instalação

**1. Configurar Nginx Proxy Manager:**
```
http://seu-ip:81
Email: admin@example.com
Senha: changeme
```
→ [**Siga o guia completo de configuração do proxy**](#-configurar-nginx-proxy-manager) para criar proxy hosts com SSL

**2. Criar Conta de E-mail (se instalou Mail Server):**
```
https://mail.seudominio.com.br
```
→ Acesse PostfixAdmin e crie sua primeira conta de e-mail

**3. Criar Usuário no Filebrowser:**
```bash
docker exec filemanager filebrowser users add seu_usuario \
  --password="SuaSenha123!" \
  --scope="/var/www/seu-site.com.br" \
  --perm.download --perm.upload --perm.create --perm.modify
```

**4. Adicionar Site WordPress:**
```bash
sudo bash scripts/add_site.sh
```

---

## � Configurar Nginx Proxy Manager

### Acesso Inicial

1. **Acessar o painel:**
   ```
   http://SEU_IP_SERVIDOR:81
   ```

2. **Login padrão:**
   - **Email:** `admin@example.com`
   - **Senha:** `changeme`

3. **Primeira configuração:**
   - Alterar email e senha imediatamente
   - Manter as configurações no painel

---

### Criar Proxy Host (Passo a Passo)

Para cada serviço, você precisa criar um **Proxy Host** que redireciona o domínio para o container interno.

#### 1️⃣ Configurar AzuraCast

**Menu:** Hosts → Proxy Hosts → Add Proxy Host

**Aba "Details":**
- **Domain Names:** `radio.seudominio.com.br`
- **Scheme:** `http`
- **Forward Hostname / IP:** `azuracast`
- **Forward Port:** `8080`
- ✅ **Cache Assets**
- ✅ **Block Common Exploits**
- ✅ **Websockets Support**

**Aba "SSL":**
- **SSL Certificate:** Request a new SSL Certificate
- ✅ **Force SSL**
- ✅ **HTTP/2 Support**
- ✅ **HSTS Enabled**
- **Email:** seu@email.com
- ✅ **I Agree to the Let's Encrypt Terms of Service**

**Salvar** → Aguardar certificado SSL ser emitido

---

#### 2️⃣ Configurar WordPress

**Aba "Details":**
- **Domain Names:** `seusite.com.br www.seusite.com.br`
- **Scheme:** `http`
- **Forward Hostname / IP:** `wp-app-SEUSITE` (substitua SEUSITE pelo nome configurado)
- **Forward Port:** `80`
- ✅ **Cache Assets**
- ✅ **Block Common Exploits**

**Aba "SSL":** (mesmo processo do AzuraCast)

---

#### 3️⃣ Configurar Webmail (Roundcube)

**Aba "Details":**
- **Domain Names:** `webmail.seudominio.com.br`
- **Scheme:** `http`
- **Forward Hostname / IP:** `webmail-nginx`
- **Forward Port:** `80`
- ✅ **Cache Assets**
- ✅ **Block Common Exploits**

**Aba "SSL":** (mesmo processo)

---

#### 4️⃣ Configurar Filebrowser

**Aba "Details":**
- **Domain Names:** `files.seudominio.com.br`
- **Scheme:** `http`
- **Forward Hostname / IP:** `filemanager`
- **Forward Port:** `80`
- ✅ **Block Common Exploits**
- ✅ **Websockets Support**

**Aba "SSL":** (mesmo processo)

---

#### 5️⃣ Configurar PostfixAdmin (Mail Server)

**Aba "Details":**
- **Domain Names:** `mail.seudominio.com.br`
- **Scheme:** `http`
- **Forward Hostname / IP:** `postfixadmin`
- **Forward Port:** `80`
- ✅ **Block Common Exploits**

**Aba "SSL":** (mesmo processo)

---

### Verificar Conectividade

Após criar os proxy hosts, teste:

```bash
# Verificar se containers estão na rede correta
docker network inspect proxy_manager_npm_network

# Testar conectividade interna
docker exec nginx-proxy-manager curl http://azuracast:8080
docker exec nginx-proxy-manager curl http://filemanager:80
docker exec nginx-proxy-manager curl http://webmail-nginx:80
```

**Todos devem retornar HTML.** Se retornar erro, execute:
```bash
sudo bash scripts/fix_proxy_issues.sh
```

---

### Resumo de Configurações

| Serviço | Domínio | Forward To | Porta | Websockets |
|---------|---------|------------|-------|-----------|
| **AzuraCast** | radio.dominio.com.br | `azuracast` | 8080 | ✅ Sim |
| **WordPress** | seusite.com.br | `wp-app-SITE` | 80 | ❌ Não |
| **Roundcube** | webmail.dominio.com.br | `webmail-nginx` | 80 | ❌ Não |
| **Filebrowser** | files.dominio.com.br | `filemanager` | 80 | ✅ Sim |
| **PostfixAdmin** | mail.dominio.com.br | `postfixadmin` | 80 | ❌ Não |

---

## �📚 Documentação

Após a instalação, consulte estes guias:

| Guia | Descrição |
|------|-----------|
| [AUTOMATED_INSTALL.md](AUTOMATED_INSTALL.md) | **Automação** - Instalação completa não-interativa |
| [WEBMAIL_SETUP.md](WEBMAIL_SETUP.md) | Configurar SMTP/IMAP para Roundcube |
| [FILEMANAGER_SETUP.md](FILEMANAGER_SETUP.md) | Gerenciar usuários e pastas no Filebrowser |
| [MAILSERVER_QUICKSTART.md](MAILSERVER_QUICKSTART.md) | **Início Rápido** - Servidor de e-mail em 5 minutos |
| [MAILSERVER_SETUP.md](MAILSERVER_SETUP.md) | Guia completo do servidor de e-mail (Postfix + Dovecot + PostfixAdmin) |
| [TROUBLESHOOTING_PROXY.md](TROUBLESHOOTING_PROXY.md) | Corrigir problemas de proxy e conectividade |

## 📧 Servidor de E-mail (Opcional)

Instale um **servidor de e-mail completo** com painel de administração.

### Opção 1: Durante a Instalação Principal

```bash
export INSTALL_MAILSERVER=1
export MAIL_DOMAIN="seudominio.com.br"
sudo bash scripts/install.sh
```

### Opção 2: Instalação Independente

```bash
sudo bash scripts/install_mailserver.sh
```

**Recursos:**
- ✅ Postfix (SMTP - enviar/receber e-mails)
- ✅ Dovecot (IMAP/POP3 - armazenar e-mails)
- ✅ PostfixAdmin (Painel web para criar contas de e-mail)
- ✅ SpamAssassin (Anti-spam)
- ✅ Integração automática com Roundcube

**Requisitos:**
- Porta 25 aberta (alguns provedores bloqueiam)
- DNS configurado (registros MX, A, SPF)
- Domínio válido

Veja [MAILSERVER_SETUP.md](MAILSERVER_SETUP.md) para guia completo.

## � Gerenciar Contas e Usuários

### Criar Contas de E-mail

Após instalar o servidor de e-mail, use o **PostfixAdmin** para gerenciar contas:

**1. Acessar PostfixAdmin:**
```
https://mail.seudominio.com.br
```

**2. Login inicial:**
- Usuário: `admin@seudominio.com.br`
- Senha: (exibida no final da instalação)

**3. Criar nova conta de e-mail:**
- Menu: **Virtual List** → **Add Mailbox**
- Preencher:
  - **Username**: nome do usuário (ex: contato)
  - **Password**: senha forte
  - **Name**: Nome completo
  - **Quota**: espaço em disco (ex: 1024 MB)
- Clicar em **Add Mailbox**

**Via CLI (alternativa):**
```bash
# Criar conta de e-mail
docker exec -it postfix-db mysql -u mailuser -p mailserver -e \
  "INSERT INTO mailbox (username, password, name, maildir, quota, domain) 
   VALUES ('contato@seudominio.com.br', ENCRYPT('senha123'), 'Contato', 
   'seudominio.com.br/contato/', 1073741824, 'seudominio.com.br');"
```

**📖 Documentação completa:** [MAILSERVER_SETUP.md](MAILSERVER_SETUP.md)

---

### Criar Usuários no Filebrowser

Gerencie o acesso aos arquivos criando usuários específicos:

**Via Interface Web:**

1. **Acessar:** `https://files.seudominio.com.br`
2. **Login:** admin / (senha da instalação)
3. **Settings** (⚙️) → **Users** → **New User**
4. **Configurar:**
   - **Username**: nome_usuario
   - **Password**: senha forte
   - **Scope**: `/var/www/site-cliente.com.br` (pasta específica)
   - **Permissions**: marcar download, upload, create, rename, modify

**Via CLI (mais rápido):**
```bash
# Criar usuário restrito a um site específico
docker exec filemanager filebrowser users add usuario_cliente \
  --password="SenhaForte123!" \
  --scope="/var/www/site-cliente.com.br" \
  --perm.download \
  --perm.upload \
  --perm.create \
  --perm.rename \
  --perm.modify \
  --perm.delete

# Listar todos os usuários
docker exec filemanager filebrowser users ls

# Alterar senha
docker exec filemanager filebrowser users update usuario_cliente \
  --password="NovaSenha456!"
```

**Exemplos de Scope:**
- `/var/www/exemplo.com.br` - Acesso apenas a um site
- `/var/www` - Acesso a todos os sites WordPress
- `/var/azuracast` - Acesso aos arquivos do AzuraCast

**📖 Documentação completa:** [FILEMANAGER_SETUP.md](FILEMANAGER_SETUP.md)

---

## �🔧 Adicionar Novos Domínios

```bash
sudo bash scripts/add_site.sh
```

Escolha o modelo desejado:
1. **WordPress** (app + banco de dados MariaDB)
2. **Site estático** (Nginx)

## 🔍 Solução de Problemas

### Problemas Comuns do Proxy

#### ❌ Erro 502/503 ao acessar serviços

**Causa:** Containers não estão na mesma rede do Nginx Proxy Manager

**Solução:**
```bash
sudo bash scripts/fix_proxy_issues.sh
```

#### ❌ "This site can't be reached" ou DNS não resolve

**Causa:** DNS não está apontando corretamente para o servidor

**Verificar:**
```bash
# Testar resolução DNS
nslookup seudominio.com.br

# Deve retornar o IP do seu servidor
```

**Solução:** Configure o registro A no seu provedor DNS apontando para o IP público do servidor

#### ❌ Certificado SSL não é emitido

**Causas possíveis:**
1. Portas 80 e 443 não estão abertas no firewall
2. DNS não está propagado (aguarde 5-30 min)
3. Domínio já tem muitas tentativas (limite Let's Encrypt de 50/semana)
4. Containers de destino não estão rodando
5. Permissões incorretas em /var/proxy_manager

**Diagnóstico Automático (RECOMENDADO):**
```bash
# Menu interativo com todas as soluções
sudo bash scripts/ssl_resolver.sh

# Ou testes específicos:
sudo bash scripts/test_ssl_readiness.sh              # Teste de prontidão
sudo bash scripts/ssl_troubleshoot_interactive.sh    # Troubleshooter
sudo bash scripts/diagnose_ssl.sh                    # Diagnóstico completo
```

**Teste Manual:**
```bash
# 1. Verificar DNS
dig seudominio.com.br +short

# 2. Testar se portas estão acessíveis
curl -I http://seudominio.com.br
curl -I https://seudominio.com.br

# 3. Ver logs do NPM
docker logs nginx-proxy-manager | tail -50
```

**Correção Rápida:**
```bash
# Se problema é conexão:
cd /var/proxy_manager
docker compose down && docker compose up -d
sleep 30  # Aguarde 30 segundos

# Se problema é permissão:
sudo chown -R 1000:1000 /var/proxy_manager
sudo chmod -R 755 /var/proxy_manager

# Se problema é limite Let's Encrypt:
# Aguarde 7 dias ou use certificado staging
```

**📖 Guia Completo de SSL:**
Ver [SSL_TROUBLESHOOTING.md](SSL_TROUBLESHOOTING.md) para soluções detalhadas

#### ❌ Containers não se comunicam

**Diagnóstico completo:**
```bash
sudo bash scripts/diagnose_proxy.sh
```

**Correção rápida (sem reiniciar):**
```bash
sudo bash scripts/quick_fix_networks.sh
```

---

### Scripts de Diagnóstico

Se você estiver tendo problemas para acessar serviços através do proxy:

```bash
# ========== PROXY/CONEXÃO ==========
# Correção rápida (containers já em execução)
sudo bash scripts/quick_fix_networks.sh

# Correção completa (reinicia containers se necessário)
sudo bash scripts/fix_proxy_issues.sh

# Diagnóstico detalhado de proxy
sudo bash scripts/diagnose_proxy.sh

# ========== SSL/LET'S ENCRYPT ==========
# Menu principal de resolução de SSL (RECOMENDADO)
sudo bash scripts/ssl_resolver.sh

# Teste de prontidão para criar SSL
sudo bash scripts/test_ssl_readiness.sh

# Troubleshooter interativo
sudo bash scripts/ssl_troubleshoot_interactive.sh

# Diagnóstico completo de SSL
sudo bash scripts/diagnose_ssl.sh

# Correção automática de problemas
sudo bash scripts/fix_ssl_issues.sh
```

**Documentação Detalhada:**
- Proxy: Ver [TROUBLESHOOTING_PROXY.md](TROUBLESHOOTING_PROXY.md)
- SSL: Ver [SSL_TROUBLESHOOTING.md](SSL_TROUBLESHOOTING.md)

## 🛡️ Gerenciamento de Firewall

Após a instalação, use `manage_firewall.sh` para controlar acesso às portas internas:

```bash
# Menu interativo
sudo bash scripts/manage_firewall.sh

# Verificar status
sudo bash scripts/manage_firewall.sh status

# Bloquear portas (produção)
sudo bash scripts/manage_firewall.sh block

# Desbloquear portas (desenvolvimento)
sudo bash scripts/manage_firewall.sh unblock
```

## 🗑️ Desinstalar

```bash
# Simular sem remover nada (recomendado primeiro)
sudo bash scripts/uninstall.sh --dry-run

# Executar remoção completa com confirmação
sudo bash scripts/uninstall.sh

# Executar sem prompt interativo
sudo bash scripts/uninstall.sh --yes
```

Remove o stack completo provisionado por este projeto:
- AzuraCast + Nginx Proxy Manager
- Roundcube + Filebrowser
- Mailserver opcional (Postfix/Dovecot/PostfixAdmin)
- Stacks WordPress criadas por `scripts/add_site.sh`
- Regras de firewall aplicadas pelos scripts do projeto

Observações:
- A remoção Docker é focada nos recursos deste stack (não faz limpeza global de todos os containers/imagens do host).
- Use `--dry-run` para revisar os comandos antes de executar em produção.

## ⚙️ Configuração Opcional

Você pode personalizar o comportamento copiando a configuração de exemplo:

```bash
cp .deploy-config.example .deploy-config
```

Para ambientes de teste/laboratório, desabilite o endurecimento de rede:
```bash
export DISABLE_NETWORK_HARDENING=1
```

Para produção, habilite o bloqueio de segurança:
```bash
export BLOCK_DIRECT_AZURACAST_ACCESS=1
```

## 📄 Estrutura do Projeto

- `scripts/install.sh` — Script principal de instalação
- `scripts/add_site.sh` — Adicionar novo domínio/WordPress
- `scripts/uninstall.sh` — Remover todos os serviços
- `scripts/install_mailserver.sh` — Instalar servidor de e-mail standalone
- `scripts/lib/common.sh` — Funções compartilhadas
- `scripts/manage_firewall.sh` — Ferramenta de gerenciamento de firewall
- `scripts/diagnose_proxy.sh` — Diagnóstico de problemas de conectividade
- `scripts/fix_proxy_issues.sh` — Correção automática de problemas de rede
- `scripts/quick_fix_networks.sh` — Correção rápida sem reiniciar containers

## 🔐 Licença

Licença MIT - apenas para scripts de automação.

Software de terceiros instalado por estes scripts possui suas próprias licenças:
- **AzuraCast** — Apache 2.0
- **Nginx Proxy Manager** — MIT  
- **Docker** — Apache 2.0
- **Roundcube** — GPL 3.0
- **Filebrowser** — Apache 2.0
- **Postfix** — IBM Public License 1.0
- **Dovecot** — MIT/LGPL
- **PostfixAdmin** — GPL 2.0

Veja [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) para detalhes.

## 📞 Suporte

Para problemas, dúvidas ou contribuições, visite o [repositório GitHub](https://github.com/chefinhoo/azuracast-deploy-automation).
