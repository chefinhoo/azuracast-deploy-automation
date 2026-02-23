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
- Provisiona um stack WordPress (app + MariaDB) no domínio informado
- Define portas internas do AzuraCast para uso com proxy reverso
- Reinicia os serviços para aplicar o mapeamento de portas

O script de remoção:

- Para e remove containers, imagens, redes e volumes do Docker
- Remove diretórios e arquivos usados pela instalação
- Remove pacotes Docker instalados pelo script

## Estrutura

- `scripts/install.sh` — Instala AzuraCast + Nginx Proxy Manager
- `scripts/add_site.sh` — Adiciona novo domínio (WordPress ou site estático)
- `scripts/uninstall.sh` — Remove AzuraCast + Nginx Proxy Manager + Docker

## Portas utilizadas

### Nginx Proxy Manager

- `81` → painel administrativo
- `80` → HTTP
- `443` → HTTPS

### AzuraCast (interno)

- `8080` → HTTP AzuraCast
- `8043` → HTTPS AzuraCast
- `9000-9999` → streaming (gerenciadas dinamicamente pelo AzuraCast)

> ℹ️ **Nota importante sobre portas:** O script remove portas hardcoded (8000-9999) do docker-compose.yml para permitir que o AzuraCast gerencie dinamicamente as portas das estações de rádio. Isso permite criar/remover estações livremente e reduz o uso de recursos. [Saiba mais](PORTS_EXPLAINED.md)

## Pré-requisitos

- Ubuntu com acesso à internet
- Usuário com privilégios `sudo`
- Portas necessárias liberadas no firewall/security group
- Domínio apontando para o IP público do servidor (para SSL com Let’s Encrypt)

## Configuração opcional (.deploy-config)

Você pode customizar comportamento e portas copiando o arquivo de exemplo:

```bash
cp .deploy-config.example .deploy-config
```

Para ambiente de teste/laboratório, desative hardening de rede:

```bash
DISABLE_NETWORK_HARDENING=1
```

Para produção, mantenha:

```bash
DISABLE_NETWORK_HARDENING=0
BLOCK_DIRECT_AZURACAST_ACCESS=1
```

## Instalação

```bash
git clone https://github.com/chefinhoo/azuracast-deploy-automation.git
cd azuracast-deploy-automation
sudo bash scripts/install.sh
```

## Adicionar novos domínios

Para adicionar um novo domínio após a instalação, use o assistente interativo:

```bash
cd azuracast-deploy-automation
sudo bash scripts/add_site.sh
```

O script pergunta qual modelo você deseja provisionar:

- `1` → WordPress (app + MariaDB)
- `2` → Site estático (Nginx)

Em ambos os casos, o backend é criado em rede interna Docker (sem porta pública), para uso via Nginx Proxy Manager.

## Pós-instalação (Proxy Host)

Após instalar, configure o proxy reverso para acessar via domínio com HTTPS.

📖 **[Guia Completo de Configuração do Proxy](PROXY_SETUP.md)**

### Configuração Rápida

1. Acesse o Nginx Proxy Manager: `http://SEU_IP_PUBLICO:81`
2. Login padrão: `admin@example.com` / `changeme`
3. Crie um Proxy Host:
   - **Domain Names:** `seudominio.com`
   - **Scheme:** `http` ⚠️ (não https)
   - **Forward Hostname/IP:** `azuracast`
   - **Forward Port:** `8080`
   - **Websockets:** ✅ habilitado
4. Na aba SSL: Solicite certificado Let's Encrypt

> ℹ️ Se o NPM estiver em container Docker, não use `localhost`.
> Use o hostname do serviço (`azuracast`) e garanta que o container `nginx-proxy-manager` esteja na rede `azuracast_default`.

### WordPress (provisionado automaticamente)

Após informar o domínio durante a instalação, o script cria um stack WordPress em `/var/www/SEU_DOMINIO`.
O acesso é feito via proxy interno (sem expor porta pública do WordPress).

No Nginx Proxy Manager:

- **Domain Names:** `seudominio.com`
- **Scheme:** `http`
- **Forward Hostname/IP:** `wp-app-seudominio-com`
- **Forward Port:** `80`

> ℹ️ O instalador conecta automaticamente o `nginx-proxy-manager` na rede Docker do WordPress.

As credenciais do banco do WordPress ficam em:

- `/var/www/SEU_DOMINIO/wordpress-credentials.txt`

### Diagnóstico de Problemas de Proxy

Se tiver problemas ao configurar o proxy (erro "internal" ou 502):

```bash
cd azuracast-deploy-automation
sudo bash diagnose_proxy.sh seu-dominio.com
```

Este script verifica automaticamente conectividade, portas e fornece a configuração recomendada.

## Ferramentas de Diagnóstico

### Verificar Status e Portas do AzuraCast

Após a instalação, você pode verificar se o AzuraCast está usando as portas corretas:

```bash
cd azuracast-deploy-automation
sudo bash check_azuracast.sh
```

Este script mostra:
- ✅ Configuração de portas no arquivo `.env`
- ✅ Status de todos os containers Docker
- ✅ Portas mapeadas do container web
- ✅ Teste de conectividade HTTP
- ✅ Comandos úteis para gerenciamento

### Debugar Conflitos de Porta

Se houver problemas com portas já em uso:

```bash
cd azuracast-deploy-automation
sudo bash debug_ports.sh
```

Este script identifica:
- ❌ Processos usando as portas 8080, 8043, 9000
- ❌ Containers Docker bloqueando portas
- ✅ Comandos para liberar portas

### Corrigir Portas do AzuraCast

Se após a instalação o AzuraCast estiver usando portas incorretas (80/443 em vez de 8080/8043):

```bash
cd azuracast-deploy-automation
sudo bash fix_azuracast_ports.sh
```

Este script:
- 🔍 Mostra configuração atual e nova
- ✅ Pede confirmação antes de aplicar
- 💾 Cria backup do arquivo `.env`
- 🔧 Atualiza todas as portas
- 🔄 Reinicia containers automaticamente
- ✅ Verifica portas após reinício

### Corrigir WordPress com Erro YAML

Se o WordPress falhou na instalação com erro `yaml: line 4: mapping values are not allowed in this context`:

```bash
cd azuracast-deploy-automation
sudo bash fix_wordpress.sh
```

Este script:
- 🔍 Detecta WordPress que falharam na instalação
- 📝 Recria docker-compose.yml com indentação correta
- 🔄 Reinicia stack WordPress
- 🔌 Conecta NPM à rede do WordPress
- ✅ Valida conectividade interna

### Diagnosticar Performance

Se o site está lento para carregar:

```bash
cd azuracast-deploy-automation
sudo bash diagnose_performance.sh
```

Este script analisa:
- 💻 Recursos do sistema (CPU, RAM, disco)
- 🐳 Uso de recursos pelos containers Docker
- ⚙️ Configurações PHP do WordPress (memória, OPcache)
- 📊 Tamanho do banco de dados
- ⏱️ Tempo de resposta HTTP
- 🌐 Conectividade de rede
- 💡 Recomendações de otimização

### Otimizar WordPress

Para aplicar otimizações de performance ao WordPress:

```bash
cd azuracast-deploy-automation
sudo bash optimize_wordpress.sh
```

Este script aplica:
- 🚀 OPcache (cache de código PHP compilado)
- 💾 Aumento de limites (memória: 256MB, upload: 64MB)
- ⏱️ Timeouts estendidos (300s)
- 🗜️ Compressão GZIP
- 📦 Cache de navegador (imagens, CSS, JS)
- ⚡ Realpath cache

**Recomendações adicionais após otimização:**
- Instale plugin de cache (WP Super Cache, W3 Total Cache)
- Otimize imagens antes de fazer upload
- Use CDN para conteúdo estático
- Minimize número de plugins ativos

### Otimizar Nginx Proxy Manager

Se **todos os sites** (WordPress e AzuraCast) estão lentos, o problema pode estar no NPM:

```bash
cd azuracast-deploy-automation
sudo bash optimize_npm.sh
```

Este script aplica otimizações globais:
- ⚡ Worker processes otimizados (auto-detecta CPUs)
- 🔗 Worker connections aumentadas (768 → 4096)
- 📦 Buffers otimizados para grandes uploads
- ⏱️ Timeouts estendidos (60s → 300s)
- 🔄 Keepalive connections habilitado
- 🌐 DNS resolver rápido (Google, Cloudflare)
- 🗜️ Gzip compression ativado
- 📤 Upload máximo: 256MB
- 💾 Cache de arquivos estáticos

**⚠️ Importante:** Esta otimização afeta **todos** os sites que passam pelo proxy.

## Documentação Adicional

### Guias Específicos

- **[PORTS_EXPLAINED.md](PORTS_EXPLAINED.md)** - Por que removemos portas hardcoded e como o AzuraCast gerencia portas dinamicamente
- **[PERFORMANCE.md](PERFORMANCE.md)** - Guia completo de troubleshooting e otimização de performance
- **[PROXY_SETUP.md](PROXY_SETUP.md)** - Configuração detalhada do Nginx Proxy Manager

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

## Créditos

- Autor e mantenedor: Danilo Ramos
- Colaboração: contribuidores da comunidade

## Avisos de Terceiros

Referências e créditos de componentes de terceiros em:

- [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)

Softwares de terceiros instalados pelos scripts possuem licenças próprias:

- AzuraCast — Apache 2.0
- Nginx Proxy Manager — MIT
- Docker — Apache 2.0

Páginas oficiais:

- AzuraCast: https://www.azuracast.com
- Nginx Proxy Manager: https://nginxproxymanager.com
- Docker: https://www.docker.com

Este projeto não é afiliado, endossado ou mantido pelos projetos acima. Nomes e marcas pertencem aos seus respectivos titulares.

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
- `scripts/add_site.sh` — Adds a new domain (WordPress or static site)
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

## Optional Configuration (.deploy-config)

You can customize behavior and ports by copying the example file:

```bash
cp .deploy-config.example .deploy-config
```

For test/lab environments, disable network hardening:

```bash
DISABLE_NETWORK_HARDENING=1
```

For production, keep:

```bash
DISABLE_NETWORK_HARDENING=0
BLOCK_DIRECT_AZURACAST_ACCESS=1
```

## Installation

```bash
git clone https://github.com/chefinhoo/azuracast-deploy-automation.git
cd azuracast-deploy-automation
sudo bash scripts/install.sh
```

## Add new domains

To add a new domain after installation, use the interactive wizard:

```bash
cd azuracast-deploy-automation
sudo bash scripts/add_site.sh
```

The script asks which model you want to provision:

- `1` → WordPress (app + MariaDB)
- `2` → Static site (Nginx)

In both cases, the backend is created on an internal Docker network (no public port), intended to be accessed via Nginx Proxy Manager.

## Post-install (Proxy Host)

After installation, open Nginx Proxy Manager:

- `http://YOUR_PUBLIC_IP:81`

Create a Proxy Host with:

- **Domain Names:** `yourdomain.com`
- **Scheme:** `http`
- **Forward Hostname/IP:** `azuracast`
- **Forward Port:** `8080`
- **Websockets:** enabled

> ℹ️ If NPM runs in Docker, avoid `localhost`.
> Use the service hostname (`azuracast`) and ensure `nginx-proxy-manager` is attached to the `azuracast_default` network.

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

## Credits

- Author and maintainer: Danilo Ramos
- Collaboration: community contributors

## Third-Party Notices

Third-party references and attributions:

- [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)

Third-party software installed by the scripts has its own licenses:

- AzuraCast — Apache 2.0
- Nginx Proxy Manager — MIT
- Docker — Apache 2.0

Official pages:

- AzuraCast: https://www.azuracast.com
- Nginx Proxy Manager: https://nginxproxymanager.com
- Docker: https://www.docker.com

This project is not affiliated with, endorsed by, or maintained by the projects above. Names and trademarks belong to their respective owners.
