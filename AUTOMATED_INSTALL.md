# 🚀 Instalação Automatizada Completa

Este guia mostra como instalar **tudo de uma vez** sem interação.

## ⚡ Instalação Completa (Tudo Incluído)

### Com Servidor de E-mail

```bash
# Clone o repositório
git clone https://github.com/chefinhoo/azuracast-deploy-automation.git
cd azuracast-deploy-automation

# Configure as variáveis
export INSTALL_MAILSERVER=1
export MAIL_DOMAIN="exemplo.com.br"
export INSTALL_WEBMAIL=1
export INSTALL_FILEMANAGER=1

# Execute a instalação
sudo -E bash scripts/install.sh
```

### Sem Servidor de E-mail (Padrão)

```bash
git clone https://github.com/chefinhoo/azuracast-deploy-automation.git
cd azuracast-deploy-automation
sudo bash scripts/install.sh
```

---

## 📝 Usando Arquivo de Configuração

### 1. Criar arquivo de configuração

```bash
cp .deploy-config.example .deploy-config
nano .deploy-config
```

### 2. Editar configurações

```bash
# Servidor de E-mail
INSTALL_MAILSERVER=1
MAIL_DOMAIN="exemplo.com.br"

# Outros serviços
INSTALL_WEBMAIL=1
INSTALL_FILEMANAGER=1

# Portas (opcional - já tem padrões)
NPM_ADMIN_PORT=81
AZURACAST_HTTP_PORT=8080

# Segurança (opcional)
BLOCK_DIRECT_AZURACAST_ACCESS=1
```

### 3. Executar instalação

```bash
source .deploy-config
sudo -E bash scripts/install.sh
```

---

## 🎯 Exemplos de Uso

### Exemplo 1: Servidor de Rádio + E-mail

```bash
export MAIL_DOMAIN="minharadio.com.br"
export INSTALL_MAILSERVER=1
sudo -E bash scripts/install.sh
```

**Resultado:**
- ✅ AzuraCast rodando
- ✅ Servidor de e-mail em mail.minharadio.com.br
- ✅ Webmail em webmail.minharadio.com.br
- ✅ PostfixAdmin em mailadmin.minharadio.com.br
- ✅ Filebrowser em files.minharadio.com.br
- ✅ Nginx Proxy Manager configurado

### Exemplo 2: Apenas Infraestrutura Web

```bash
export INSTALL_MAILSERVER=0
sudo bash scripts/install.sh
```

**Resultado:**
- ✅ AzuraCast rodando
- ✅ Roundcube (desconectado - precisa configurar SMTP externo)
- ✅ Filebrowser
- ✅ WordPress pronto para adicionar sites

### Exemplo 3: Instalação Mínima

```bash
export INSTALL_WEBMAIL=0
export INSTALL_FILEMANAGER=0
export INSTALL_MAILSERVER=0
sudo -E bash scripts/install.sh
```

**Resultado:**
- ✅ Apenas AzuraCast + Nginx Proxy Manager

---

## 📋 Checklist Pré-Instalação

### Se instalar servidor de e-mail:

- [ ] Porta 25 liberada pelo provedor (verificar com suporte)
- [ ] DNS configurado:
  ```dns
  mail.seudominio.com     A      SEU_IP
  seudominio.com          MX 10  mail.seudominio.com
  seudominio.com          TXT    "v=spf1 mx ~all"
  ```
- [ ] PTR (Reverse DNS) configurado no painel do provedor
- [ ] Domínio válido e funcionando

### Sempre necessário:

- [ ] Ubuntu 20.04+ (x86 ou ARM)
- [ ] Acesso root/sudo
- [ ] Portas 80, 443, 81 livres
- [ ] Conexão com internet
- [ ] Mínimo 2GB RAM (4GB recomendado com mail server)
- [ ] 20GB de espaço em disco

---

## 🔧 Pós-Instalação

### 1. Configurar Nginx Proxy Manager

Acesse: `http://SEU_IP:81`

**Login padrão:**
- Email: `admin@example.com`
- Senha: `changeme`

**Criar Proxy Hosts:**

| Domínio | Forward Para | Porta |
|---------|--------------|-------|
| azura.seudominio.com | azuracast | 8080 |
| webmail.seudominio.com | webmail-nginx | 80 |
| files.seudominio.com | filemanager | 80 |
| mailadmin.seudominio.com | postfixadmin | 80 |

### 2. Configurar PostfixAdmin (se instalou mail server)

1. Acesse: `https://mailadmin.seudominio.com/setup.php`
2. Ver credenciais: `cat /var/mailserver/credentials.txt`
3. Seguir: [MAILSERVER_QUICKSTART.md](MAILSERVER_QUICKSTART.md)

### 3. Criar Contas de E-mail

1. Login: `https://mailadmin.seudominio.com`
2. Domain List → Add Domain → `seudominio.com`
3. Virtual List → Add Mailbox
4. Testar: `https://webmail.seudominio.com`

---

## 🆘 Troubleshooting

### Containers não iniciam

```bash
# Ver logs
docker ps -a
docker logs NOME_DO_CONTAINER

# Reiniciar
cd /var/mailserver  # ou /var/webmail, etc
docker compose restart
```

### Proxy não acessa os serviços

```bash
# Conectar à rede do proxy
sudo bash scripts/quick_fix_networks.sh
```

### E-mail não funciona

**Verificar:**
1. Porta 25 aberta: `telnet mail.seudominio.com 25`
2. DNS: `dig mail.seudominio.com +short`
3. Logs: `docker logs mailserver -f`

---

## 📚 Documentação Completa

- [README.md](README.md) - Visão geral
- [MAILSERVER_QUICKSTART.md](MAILSERVER_QUICKSTART.md) - E-mail rápido
- [MAILSERVER_SETUP.md](MAILSERVER_SETUP.md) - E-mail completo
- [WEBMAIL_SETUP.md](WEBMAIL_SETUP.md) - Configurar Roundcube
- [FILEMANAGER_SETUP.md](FILEMANAGER_SETUP.md) - Filebrowser
- [TROUBLESHOOTING_PROXY.md](TROUBLESHOOTING_PROXY.md) - Problemas de rede

---

## ⏱️ Tempo de Instalação

| Configuração | Tempo Estimado |
|--------------|---------------|
| Mínima (AzuraCast + NPM) | 10-15 min |
| Padrão (+ Webmail + Files) | 15-20 min |
| Completa (+ Mail Server) | 25-35 min |

*Tempos variam conforme velocidade de internet e hardware*

---

## 🎉 Pronto!

Após a instalação, você terá:

- 🎙️ **AzuraCast** - Rádio online profissional
- 🌐 **Nginx Proxy Manager** - Proxy reverso com SSL
- 📧 **Servidor de E-mail** (opcional) - Sistema completo
- 📬 **Roundcube** - Webmail moderno
- 📁 **Filebrowser** - Gerenciador de arquivos
- 🌍 **WordPress** - Pronto para adicionar sites

**Tudo integrado e funcionando!** ✨
