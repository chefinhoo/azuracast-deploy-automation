# AzuraCast Deploy Automation

[![Test Scripts](https://github.com/chefinhoo/azuracast-deploy-automation/actions/workflows/test-scripts.yml/badge.svg)](https://github.com/chefinhoo/azuracast-deploy-automation/actions/workflows/test-scripts.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Automação de instalação e remoção para **AzuraCast** + **Nginx Proxy Manager** em **Ubuntu (ARM/x86)**.

Automation for installing and removing **AzuraCast** + **Nginx Proxy Manager** on **Ubuntu (ARM/x86)**.

---

## 🇧🇷 Português

## O que este projeto faz

O script de instalação:

- Instala Docker Engine e Docker Compose Plugin
- Sobe o Nginx Proxy Manager em `/var/proxy_manager`
- Baixa e instala o AzuraCast em `/var/azuracast`
- Define portas internas do AzuraCast para uso com proxy reverso
- Reinicia os serviços para aplicar o mapeamento de portas

O script de remoção:

- Para e remove containers, imagens, redes e volumes do Docker
- Remove diretórios e arquivos usados pela instalação
- Remove pacotes Docker instalados pelo script

## Estrutura

- `scripts/install.sh` — Instala AzuraCast + Nginx Proxy Manager
- `scripts/uninstall.sh` — Remove AzuraCast + Nginx Proxy Manager + Docker

## Portas utilizadas

### Nginx Proxy Manager

- `81` → painel administrativo
- `80` → HTTP
- `443` → HTTPS

### AzuraCast (interno)

- `8080` → HTTP AzuraCast
- `8043` → HTTPS AzuraCast
- `9000-9999` → streaming

## Pré-requisitos

- Ubuntu com acesso à internet
- Usuário com privilégios `sudo`
- Portas necessárias liberadas no firewall/security group
- Domínio apontando para o IP público do servidor (para SSL com Let’s Encrypt)

## Instalação

```bash
git clone https://github.com/chefinhoo/azuracast-deploy-automation.git
cd azuracast-deploy-automation
sudo bash scripts/install.sh
```

## Pós-instalação (Proxy Host)

Após instalar, acesse o Nginx Proxy Manager:

- `http://SEU_IP_PUBLICO:81`

Crie um Proxy Host com:

- **Domain Names:** `seudominio.com`
- **Scheme:** `https`
- **Forward Hostname/IP:** `localhost`
- **Forward Port:** `8043`
- **Websockets:** habilitado

Na aba SSL:

- Solicite novo certificado Let’s Encrypt
- Ative `Force SSL`
- Ative `HTTP/2`

## Desinstalação

> ⚠️ Atenção: o processo abaixo remove **AzuraCast, Nginx Proxy Manager e Docker** do servidor.

```bash
cd azuracast-deploy-automation
sudo bash scripts/uninstall.sh
```

Sem `--yes`, o script pede confirmação interativa (`yes`).

Para confirmar automaticamente:

```bash
cd azuracast-deploy-automation
sudo bash scripts/uninstall.sh --yes
```

Simulação sem remover nada (`dry-run`):

```bash
cd azuracast-deploy-automation
sudo bash scripts/uninstall.sh --dry-run
```

Exemplo combinado (simulação sem prompt):

```bash
cd azuracast-deploy-automation
sudo bash scripts/uninstall.sh --dry-run --yes
```

Flags suportadas (`scripts/uninstall.sh`):

- `--dry-run`, `-n` → simula ações sem remover nada
- `--yes`, `-y` → confirma remoção automaticamente
- `--help`, `-h` → exibe ajuda

## Licença

Este repositório usa licença MIT para os scripts de automação.

Softwares de terceiros instalados pelos scripts possuem licenças próprias:

- AzuraCast — Apache 2.0
- Nginx Proxy Manager — MIT
- Docker — Apache 2.0

---

## 🇺🇸 English

## What this project does

The install script:

- Installs Docker Engine and Docker Compose Plugin
- Starts Nginx Proxy Manager in `/var/proxy_manager`
- Downloads and installs AzuraCast in `/var/azuracast`
- Sets internal AzuraCast ports for reverse proxy usage
- Restarts services to apply port mappings

The uninstall script:

- Stops and removes Docker containers, images, networks, and volumes
- Removes installation directories and related files
- Removes Docker packages installed by the script

## Structure

- `scripts/install.sh` — Installs AzuraCast + Nginx Proxy Manager
- `scripts/uninstall.sh` — Removes AzuraCast + Nginx Proxy Manager + Docker

## Ports in use

### Nginx Proxy Manager

- `81` → admin panel
- `80` → HTTP
- `443` → HTTPS

### AzuraCast (internal)

- `8080` → AzuraCast HTTP
- `8043` → AzuraCast HTTPS
- `9000-9999` → streaming

## Requirements

- Ubuntu server with internet access
- User with `sudo` privileges
- Required ports open in firewall/security group
- Domain pointing to server public IP (for Let’s Encrypt SSL)

## Installation

```bash
git clone https://github.com/chefinhoo/azuracast-deploy-automation.git
cd azuracast-deploy-automation
sudo bash scripts/install.sh
```

## Post-install (Proxy Host)

After installation, open Nginx Proxy Manager:

- `http://YOUR_PUBLIC_IP:81`

Create a Proxy Host with:

- **Domain Names:** `yourdomain.com`
- **Scheme:** `https`
- **Forward Hostname/IP:** `localhost`
- **Forward Port:** `8043`
- **Websockets:** enabled

In the SSL tab:

- Request a new Let’s Encrypt certificate
- Enable `Force SSL`
- Enable `HTTP/2`

## Uninstall

> ⚠️ Warning: this process removes **AzuraCast, Nginx Proxy Manager, and Docker** from the server.

```bash
cd azuracast-deploy-automation
sudo bash scripts/uninstall.sh
```

Without `--yes`, the script asks for interactive confirmation (`yes`).

To auto-confirm:

```bash
cd azuracast-deploy-automation
sudo bash scripts/uninstall.sh --yes
```

Simulation without removing anything (`dry-run`):

```bash
cd azuracast-deploy-automation
sudo bash scripts/uninstall.sh --dry-run
```

Combined example (simulation without prompt):

```bash
cd azuracast-deploy-automation
sudo bash scripts/uninstall.sh --dry-run --yes
```

Supported flags (`scripts/uninstall.sh`):

- `--dry-run`, `-n` → simulate actions without removing anything
- `--yes`, `-y` → auto-confirm removal
- `--help`, `-h` → show help

## License

This repository uses the MIT License for automation scripts.

Third-party software installed by the scripts has its own licenses:

- AzuraCast — Apache 2.0
- Nginx Proxy Manager — MIT
- Docker — Apache 2.0
