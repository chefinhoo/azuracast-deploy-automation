# 🚀 Guia Rápido - Servidor de E-mail

## Instalação em 5 Minutos

### 1. Configure DNS (ANTES de instalar)

No painel do seu registrador de domínio (GoDaddy, Namecheap, etc):

```dns
Tipo    Nome                            Valor                   TTL
────────────────────────────────────────────────────────────────
A       mail.daniloramos.dev.br         SEU_IP_PUBLICO         3600
MX      daniloramos.dev.br              mail.daniloramos.dev.br  10
TXT     daniloramos.dev.br              v=spf1 mx ~all         3600
```

**Aguarde 5-15 minutos** para propagar.

Verificar:
```bash
dig mail.daniloramos.dev.br +short
# Deve retornar seu IP
```

---

### 2. Instalar Servidor de E-mail

```bash
cd /tmp/azuracast-deploy-automation
sudo bash scripts/install_mailserver.sh
```

Digite seu domínio quando solicitado: `daniloramos.dev.br`

**Tempo:** ~5-10 minutos

---

### 3. Configurar Proxy (acesso web)

Acesse Nginx Proxy Manager: `http://SEU_IP:81`

**Criar Proxy Host para PostfixAdmin:**

```
Domain Names:     mailadmin.daniloramos.dev.br
Scheme:           http
Forward Host/IP:  postfixadmin
Forward Port:     80
Block Exploits:   ✓
Websockets:       ✓

[SSL tab]
SSL Certificate:  Request Let's Encrypt
Force SSL:        ✓
```

**Salvar**

---

### 4. Setup Inicial do PostfixAdmin

1. Acesse: `https://mailadmin.daniloramos.dev.br/setup.php`

2. Abra o arquivo de credenciais:
   ```bash
   cat /var/mailserver/credentials.txt
   ```

3. Cole a **Setup Password** no campo do setup

4. Clique em **Generate password hash** e copie o hash

5. Volte ao terminal e edite:
   ```bash
   docker exec -it postfixadmin sh
   vi /var/www/html/config.local.php
   ```
   
   Adicione:
   ```php
   $CONF['setup_password'] = 'HASH_AQUI';
   ```
   
   Salve (`:wq`) e saia

6. Volte ao navegador e recarregue a página

7. Crie o primeiro admin:
   - Setup password: (a mesma)
   - Admin: `admin@daniloramos.dev.br`
   - Password: (escolha forte)
   - Clique em **Add Admin**

---

### 5. Criar Primeiro Domínio

1. Login: `https://mailadmin.daniloramos.dev.br`
2. Menu **Domain List** → **New Domain**
3. Preencha:
   ```
   Domain:       daniloramos.dev.br
   Description:  Domínio Principal
   Aliases:      50
   Mailboxes:    50
   Max Quota:    10240 (10GB)
   Active:       ✓
   ```
4. **Add Domain**

---

### 6. Criar Primeira Conta

1. Menu **Virtual List** → **Add Mailbox**
2. Preencha:
   ```
   Username:   contato@daniloramos.dev.br
   Password:   (senha forte)
   Name:       Contato
   Quota:      1024 MB
   Active:     ✓
   ```
3. **Add Mailbox**

---

### 7. Testar no Webmail

1. Acesse: `https://webmail.daniloramos.dev.br`
2. Login:
   - Usuário: `contato@daniloramos.dev.br`
   - Senha: (a que você definiu)
3. **Pronto!** Envie um e-mail de teste

---

## ✅ Checklist Rápido

- [ ] DNS configurado (A, MX, SPF)
- [ ] Servidor instalado com sucesso
- [ ] Proxy criado para PostfixAdmin
- [ ] Setup do PostfixAdmin concluído
- [ ] Domínio adicionado
- [ ] Primeira conta criada
- [ ] Testado login no Roundcube
- [ ] E-mail de teste enviado/recebido

---

## 📱 Configurar em Clientes

### Outlook / Thunderbird / Apple Mail

**IMAP (Receber):**
```
Servidor:   mail.daniloramos.dev.br
Porta:      993
Segurança:  SSL/TLS
Usuário:    contato@daniloramos.dev.br
Senha:      (sua senha)
```

**SMTP (Enviar):**
```
Servidor:   mail.daniloramos.dev.br
Porta:      587
Segurança:  STARTTLS
Requer autenticação: Sim
Usuário:    contato@daniloramos.dev.br
Senha:      (sua senha)
```

---

## 🆘 Problemas Comuns

### E-mail não chega

**Causa:** Porta 25 bloqueada

**Solução:** Contate seu provedor de VPS para liberar porta 25

**Verificar:**
```bash
telnet mail.daniloramos.dev.br 25
# Se conectar = OK
# Se timeout = bloqueado
```

### E-mail cai no spam

**Causa:** Falta DKIM e Reverse DNS

**Solução:**
```bash
# 1. Configurar DKIM
cd /var/mailserver
docker compose exec mailserver setup config dkim

# 2. Ver chave pública
cat /var/mailserver/config/opendkim/keys/daniloramos.dev.br/mail.txt

# 3. Adicionar no DNS:
#    mail._domainkey.daniloramos.dev.br TXT "v=DKIM1; k=rsa; p=CHAVE_AQUI"

# 4. Configurar PTR no painel do provedor
#    SEU_IP → mail.daniloramos.dev.br
```

### Roundcube não conecta

**Causa:** Redes Docker não conectadas

**Solução:**
```bash
docker network connect mailserver_network webmail
docker network connect mailserver_network webmail-nginx
cd /var/webmail && docker compose restart
```

---

## 📚 Documentação Completa

Ver [MAILSERVER_SETUP.md](MAILSERVER_SETUP.md) para:
- Configurações avançadas (DKIM, DMARC, SSL)
- Gerenciamento de contas
- Backup e restauração
- Troubleshooting detalhado
- Monitoramento

---

## 🎯 Próximos Passos

1. **Testar envio externo** - enviar e-mail para Gmail/Outlook
2. **Verificar reputação do IP** - https://mxtoolbox.com/
3. **Configurar DKIM** - assinar digitalmente
4. **Configurar Reverse DNS** - evitar spam
5. **Backup automático** - proteger dados

---

**Pronto!** Servidor de e-mail profissional funcionando! 📧✅
