# 📧 Configuração do Servidor de E-mail Completo

## Visão Geral

Este sistema inclui um servidor de e-mail **completo e profissional** com:

- ✅ **Postfix** - SMTP para enviar/receber e-mails
- ✅ **Dovecot** - IMAP/POP3 para armazenar e-mails
- ✅ **PostfixAdmin** - Painel web para gerenciar contas
- ✅ **MySQL** - Database para contas virtuais
- ✅ **SpamAssassin** - Proteção anti-spam
- ✅ **Roundcube** - Webmail integrado

---

## 🚀 Instalação

### Requisitos

1. **Porta 25** liberada pelo provedor (VPS/Cloud)
2. **DNS configurado** antes da instalação
3. **Domínio válido**

### Instalar

```bash
cd /path/to/azuracast-deploy-automation
sudo bash scripts/install_mailserver.sh
```

O script vai solicitar:
- Seu domínio principal (ex: `exemplo.com.br`)
- Confirmação de  que o DNS está configurado

---

## 🌐 Configuração de DNS

**Configure ANTES de instalar:**

```dns
# Registro A - Aponta mail.seudominio.com para seu IP
mail.exemplo.com.br    A      SEU_IP_PUBLICO

# Registro MX - Define servidor de e-mail
exemplo.com.br         MX 10  mail.exemplo.com.br

# Registro TXT (SPF) - Verifica remetente
exemplo.com.br         TXT    "v=spf1 mx ~all"

# PTR (Reverse DNS) - Configurar no painel do provedor
SEU_IP_PUBLICO  →  mail.exemplo.com.br
```

### Verificar DNS

```bash
# Verificar registro A
dig mail.exemplo.com.br +short

# Verificar registro MX
dig exemplo.com.br MX +short

# Verificar SPF
dig exemplo.com.br TXT +short
```

---

## ⚙️ Configuração Inicial

### 1. Configurar Nginx Proxy Manager

Acesse `http://SEU_IP:81` e crie Proxy Host:

**PostfixAdmin:**
- Domain Names: `mailadmin.exemplo.com.br`
- Scheme: `http`
- Forward Hostname/IP: `postfixadmin`
- Forward Port: `80`
- SSL: Let's Encrypt ✓
- Force SSL: ✓

### 2. Setup do PostfixAdmin

**Primeira vez:**

1. Acesse: `https://mailadmin.exemplo.com.br/setup.php`
2. Cole a **Setup Password** (no arquivo`/var/mailserver/credentials.txt`)
3. Clique em **Generate password hash**
4. Abra `/var/mailserver/postfixadmin/config.local.php` e adicione:
   ```php
   $CONF['setup_password'] = 'HASH_GERADO_AQUI';
   ```
5. Volte ao setup e crie o **primeiro admin**:
   - Setup password: (a mesma)
   - Admin: `admin@exemplo.com.br`
   - Password: (escolha uma senha forte)
   - Repeat Password: (repita)

6. Clique em **Add Admin**

### 3. Configurar Domínio

1. Login em `https://mailadmin.exemplo.com.br`
2. Vá em **Domain List** → **New Domain**
3. Preencha:
   - Domain: `exemplo.com.br`
   - Description: `Domínio principal`
   - Aliases: `50`
   - Mailboxes: `50`
   - Max Quota: `10240` (10GB)
4. Clique em **Add Domain**

### 4. Criar Contas de E-mail

1. Vá em **Virtual List** → **Add Mailbox**
2. Preencha:
   - Username: `contato@exemplo.com.br`
   - Password: (senha forte)
   - Name: `Contato`
   - Quota: `1024` MB (1GB)
   - Active: ✓
3. Clique em **Add Mailbox**

---

## 📬 Usar o E-mail

### Roundcube (Webmail)

**URL:** `https://webmail.exemplo.com.br`

**Login:**
- Usuário: `contato@exemplo.com.br`
- Senha: (senha definida no PostfixAdmin)

### Clientes de E-mail (Outlook, Thunderbird, etc)

**Configurações:**

**IMAP (Receber):**
- Servidor: `mail.exemplo.com.br`
- Porta: `993`
- Segurança: `SSL/TLS`
- Usuário: `contato@exemplo.com.br`
- Senha: (sua senha)

**SMTP (Enviar):**
- Servidor: `mail.exemplo.com.br`
- Porta: `587`
- Segurança: `STARTTLS`
- Autenticação: ✓ Sim
- Usuário: `contato@exemplo.com.br`
- Senha: (sua senha)

---

## 🔐 Configurações Avançadas

### DKIM (Assinatura Digital)

```bash
# Gerar chave DKIM
cd /var/mailserver
docker compose exec mailserver setup config dkim

# Ver chave pública
cat /var/mailserver/config/opendkim/keys/exemplo.com.br/mail.txt
```

Adicione no DNS:
```dns
mail._domainkey.exemplo.com.br  TXT  "v=DKIM1; k=rsa; p=CHAVE_PUBLICA_AQUI"
```

### DMARC (Política de E-mail)

```dns
_dmarc.exemplo.com.br  TXT  "v=DMARC1; p=quarantine; rua=mailto:postmaster@exemplo.com.br"
```

### SSL/TLS (Certificados)

```bash
# Gerar certificado com Let's Encrypt
sudo certbot certonly --standalone -d mail.exemplo.com.br

# Copiar para o container
sudo cp /etc/letsencrypt/live/mail.exemplo.com.br/fullchain.pem /var/mailserver/config/ssl/cert.pem
sudo cp /etc/letsencrypt/live/mail.exemplo.com.br/privkey.pem /var/mailserver/config/ssl/key.pem

# Reiniciar mailserver
cd /var/mailserver && docker compose restart mailserver
```

---

## 🛠️ Gerenciamento

### Ver Logs

```bash
# Logs do Postfix
docker logs mailserver -f | grep postfix

# Logs do Dovecot
docker logs mailserver -f | grep dovecot

# Logs do SpamAssassin
docker logs mailserver -f | grep spamd
```

### Status dos Serviços

```bash
cd /var/mailserver
docker compose ps
docker compose logs --tail 50
```

### Testar Envio de E-mail

```bash
# De dentro do container
docker exec -it mailserver sendmail -v destino@exemplo.com
Subject: Teste
Teste de envio
.
(Ctrl+D para enviar)
```

### Listar Contas de E-mail

```bash
# Via MySQL
docker exec -it mail-mysql mysql -u root -p
USE postfix;
SELECT username, name, active FROM mailbox;
```

---

## 📊 PostfixAdmin - Funções

### Dashboard
- Visualizar domínios e contas
- Estatísticas de uso

### Gerenciar Domínios
- **Domain List**: Ver todos os domínios
- **New Domain**: Adicionar  novo domínio
- **Edit**: Modificar limites e configurações

### Gerenciar Contas
- **Virtual List**: Ver todas as caixas de e-mail
- **Add Mailbox**: Criar nova conta
- **Edit**: Alterar senha, quota, status

### Criar Aliases (Redirecionamentos)
- **Virtual List** → **Add Alias**
- Exemplo: `vendas@dominio.com` → `contato@dominio.com`

---

## 🔍 Troubleshooting

### E-mail não chega

**Verificar:**
1. DNS configurado corretamente (MX, A, SPF)
2. Porta 25 não bloqueada pelo provedor
3. Logs do Postfix: `docker logs mailserver | grep postfix`

```bash
# Testar conectividade SMTP
telnet mail.exemplo.com.br 25
```

### E-mail cai no spam

**Soluções:**
1. Configurar DKIM
2. Configurar DMARC
3. Configurar PTR (Reverse DNS)
4. Evitar IPs blacklistados

**Verificar reputação do IP:**
- https://mxtoolbox.com/blacklists.aspx
- https://multirbl.valli.org/

### Não consigo fazer login no Roundcube

**Verificar:**
1. Conta criada no PostfixAdmin
2. Roundcube conectado à rede do mailserver:
   ```bash
   docker network connect mailserver_network webmail
   docker network connect mailserver_network webmail-nginx
   ```
3. Logs do Roundcube: `docker logs webmail -f`

### Quota cheia

```bash
# Ver uso de quota
docker exec -it mail-mysql mysql -u root -p
USE postfix;
SELECT username, quota, ROUND((quota_used/quota)*100,2) as percent_used FROM mailbox;

# Aumentar quota
UPDATE mailbox SET quota = 2048 WHERE username = 'usuario@dominio.com';
```

---

## 🗑️ Remover Conta

**Via PostfixAdmin:**
1. Virtual List → Selecionar conta → Delete

**Via MySQL:**
```bash
docker exec -it mail-mysql mysql -u root -p
USE postfix;
DELETE FROM mailbox WHERE username = 'usuario@dominio.com';
```

---

## 📦 Backup

```bash
# Backup do banco de dados
docker exec mail-mysql mysqldump -u root -p postfix > /backup/mailserver-$(date +%Y%m%d).sql

# Backup das mensagens
tar -czf /backup/vmail-$(date +%Y%m%d).tar.gz /var/vmail/

# Backup das configurações
tar -czf /backup/mailserver-config-$(date +%Y%m%d).tar.gz /var/mailserver/
```

---

## 🔄 Atualizar

```bash
cd /var/mailserver
docker compose pull
docker compose up -d
```

---

## 📚 Referências

- [docker-mailserver](https://docker-mailserver.github.io/docker-mailserver/latest/)
- [PostfixAdmin](https://github.com/postfixadmin/postfixadmin)
- [Roundcube](https://roundcube.net/)
- [SPF Record](https://www.spf-record.com/)
- [DKIM Generator](https://dkimcore.org/tools/)

---

## ⚠️ Notas Importantes

1. **Porta 25**: Alguns provedores bloqueiam. Verifique com suporte.
2. **Reverse DNS (PTR)**: Configurar no painel do provedor de VPS.
3. **Blacklist**: Monitore regularmente a reputação do IP.
4. **Backup**: Faça backups regulares das mensagens e banco de dados.
5. **SSL**: Renovar certificados a cada 90 dias (Let's Encrypt).
6. **Segurança**: Use senhas fortes e 2FA quando disponível.
