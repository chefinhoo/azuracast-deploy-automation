# AzuraCast Deploy Automation

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ubuntu 20.04+](https://img.shields.io/badge/Ubuntu-20.04+-orange.svg)](https://ubuntu.com/)
[![Docker Ready](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)

Automação completa de instalação para **AzuraCast** + **Nginx Proxy Manager** + **WordPress** + **Roundcube** + **Filebrowser** em Ubuntu (x86 e ARM).

## 📋 Quick Links

- [Funcionalidades](#-funcionalidades)
- [Requisitos](#-requisitos)
- [Instalação](#-instalação)
- [Gerenciar Clientes](#-gerenciar-clientes)  
- [Documentação](#-documentação)
- [Problemas?](#-solução-de-problemas)

## ✨ Funcionalidades

- ✅ **Docker Compose** automatizado
- ✅ **Nginx Proxy Manager** com SSL/Let's Encrypt
- ✅ **AzuraCast** - servidor de rádio
- ✅ **WordPress** multi-site (structure: `/var/cliente-nome/subdirectory/`)
- ✅ **Roundcube** webmail
- ✅ **Filebrowser** com usuários isolados por cliente
- ✅ **Servidor de E-mail** (optional)
- ✅ **Firewall** automático

## ⚙️ Requisitos

| Item | Requisito |
|------|-----------|
| SO | Ubuntu 20.04+ |
| Arquitetura | x86_64 / ARM64 / ARMv7 |
| Acesso | sudo/root |
| Internet | Para download de imagens |
| Portas | 80, 443, 81 (proxy) |
| Domínio | Apontando para este servidor |

## 🚀 Instalação

### Instalação Básica

```bash
git clone https://github.com/chefinhoo/azuracast-deploy-automation.git
cd azuracast-deploy-automation
sudo bash scripts/install.sh
```

### Com Servidor de E-mail

```bash
export INSTALL_MAILSERVER=1
export MAIL_DOMAIN="seudominio.com.br"
sudo bash scripts/install.sh
```

Após instalação, acesse:
- **Nginx Proxy Manager**: `http://seu-ip:81` (admin@example.com / changeme)
- **AzuraCast**: via proxy (`radio.domain.com.br`)

## 👥 Gerenciar Clientes

### Adicionar Novo Cliente e Site

```bash
sudo bash scripts/add_site.sh
```

O script criará:
- Estrutura em `/var/cliente-nome/html/` (ou outro subdiretório)
- Usuário Filebrowser automático
- WordPress com MariaDB

**Exemplo:**
```
Novo cliente: empresa-xyz
Subdiretório: html
Domínio: empresa-xyz.com.br

✓ Criado em /var/empresa-xyz/html/
✓ Usuário Filebrowser: empresa-xyz
✓ Credenciais: /var/empresa-xyz/.filebrowser-credentials.txt
```

## 📁 Estrutura

```
/var/
├── proxy_manager/           # Nginx Proxy Manager
├── azuracast/               # AzuraCast
├── webmail/                 # Roundcube
├── filemanager/             # Filebrowser
└── cliente-nome/            # Cliente (estrutura por cliente)
    ├── .filebrowser-credentials.txt
    ├── html/                # Site principal
    │   ├── docker-compose.yml
    │   ├── db_data/
    │   └── (WordPress files)
    └── blog/                # Subsite (opcional)
        └── (outro WordPress)
```

## 🔧 Scripts

| Script | Descrição |
|--------|-----------|
| `install.sh` | Instalação completa |
| `add_site.sh` | Adicionar cliente/site |
| `manage_firewall.sh` | Controlar firewall |
| `diagnose_proxy.sh` | Diagnosticar proxy |
| `fix_proxy_issues.sh` | Corrigir rede Docker |
| `quick_fix_networks.sh` | Fix rápido |
| `install_mailserver.sh` | E-mail standalone |
| `uninstall.sh` | Remover tudo (⚠️) |

## 📚 Documentação

- [AUTOMATED_INSTALL.md](AUTOMATED_INSTALL.md) - Instalação não-interativa
- [FILEMANAGER_SETUP.md](FILEMANAGER_SETUP.md) - Gerenciar usuários Filebrowser
- [MAILSERVER_SETUP.md](MAILSERVER_SETUP.md) - Servidor de e-mail completo
- [WEBMAIL_SETUP.md](WEBMAIL_SETUP.md) - Configurar Roundcube
- [MAILSERVER_QUICKSTART.md](MAILSERVER_QUICKSTART.md) - E-mail em 5 min

## 🐛 Solução de Problemas

### Erro "502 Bad Gateway" no proxy

```bash
sudo bash scripts/fix_proxy_issues.sh
```

### Containers não respondendo

```bash
sudo bash scripts/diagnose_proxy.sh
```

### Filebrowser offline

```bash
cd /var/filemanager
docker compose restart filemanager
docker logs filemanager
```

### Ver logs

```bash
docker logs nome-container
docker logs -f nome-container  # em tempo real
```

## 🛠️ Configurar Proxy (Nginx Proxy Manager)

Após instalação, adicione um **Proxy Host** para cada serviço:

### AzuraCast
- **Domain**: `radio.dominio.com.br`
- **Forward**: `azuracast:8080`
- **SSL**: Let's Encrypt ✅

### WordPress (seu-site.com.br)
- **Domain**: `seu-site.com.br`
- **Forward**: `wp-app-seu-site-com-br:80`
- **SSL**: Let's Encrypt ✅

### Filebrowser
- **Domain**: `files.dominio.com.br`
- **Forward**: `filemanager:80`
- **SSL**: Let's Encrypt ✅

### Roundcube
- **Domain**: `webmail.dominio.com.br`
- **Forward**: `webmail-nginx:80`
- **SSL**: Let's Encrypt ✅

## 🔐 Segurança

### Senhas
- Geradas automaticamente e salvas em `.filebrowser-credentials.txt`
- Altere password padrão do NPM imediatamente!

### Firewall
```bash
# Bloquear portas internas (recomendado produção)
sudo bash scripts/manage_firewall.sh block

# Ver status
sudo bash scripts/manage_firewall.sh status
```

## 🗑️ Desinstalar

```bash
# Simular sem remover (SUPER RECOMENDADO)
sudo bash scripts/uninstall.sh --dry-run

# Remover tudo
sudo bash scripts/uninstall.sh --yes
```

⚠️ **Irreversível!** Remove todos os containers, imagens, volumes e sites.

## 📝 Licenças

- **Script**: MIT License
- **AzuraCast**: Apache 2.0
- **Nginx Proxy Manager**: MIT
- **Roundcube**: GPL 3.0
- **Filebrowser**: Apache 2.0
- **WordPress**: GPL 2.0
- **Docker**: Apache 2.0

Veja [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) para detalhes.

## 💬 Suporte

- 📖 Leia a documentação acima
- 🐛 Abra uma [Issue](https://github.com/chefinhoo/azuracast-deploy-automation/issues)
- ⭐ Deixe uma estrela se ajudou!

---

**Última atualização**: 2026-02-24
