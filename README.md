# AzuraCast Deploy Automation

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Complete automation to install and manage **AzuraCast** + **Nginx Proxy Manager** + **Roundcube Webmail** + **Filebrowser** on **Ubuntu (ARM/x86)**.

---

## 🎯 What This Does

### Installation & Configuration
- ✅ Docker Engine and Docker Compose
- ✅ Nginx Proxy Manager (reverse proxy with SSL/Let's Encrypt)
- ✅ AzuraCast (online radio server)
- ✅ Roundcube (webmail client)
- ✅ Filebrowser (file manager)
- ✅ WordPress (multi-domain with MariaDB)
- ✅ Firewall protection (internal ports)

### Services Installed

| Service | Location | Internal Port | Access |
|---------|----------|-----------------|--------|
| **Nginx Proxy Manager** | `/var/proxy_manager` | 81 (admin) | http://ip:81 |
| **AzuraCast** | `/var/azuracast` | 8080/8043 | via proxy |
| **Roundcube** | `/var/webmail` | 9000 | webmail.domain.com |
| **Filebrowser** | `/var/filemanager` | 9001 | files.domain.com |
| **WordPress** | `/var/www/` | per domain | domain.com |

## ⚙️ Requirements

- **Ubuntu 20.04+** (x86 or ARM)
- **sudo access** (root privileges)
- **Available ports**: 80, 443, 81 (proxy) + 8080, 8043, 2022, 9000-9999 (internal)
- **Internet connection** (to download Docker images)
- **Domain** pointing to server public IP (for SSL with Let's Encrypt)

## 🚀 Quick Installation

```bash
git clone https://github.com/chefinhoo/azuracast-deploy-automation.git
cd azuracast-deploy-automation
sudo bash scripts/install.sh
```

The installation is **fully interactive** and prompts for required information.

## 📚 Documentation

After installation, consult these guides:

| Guide | Description |
|-------|-----------|
| [WEBMAIL_SETUP.md](WEBMAIL_SETUP.md) | Configure SMTP/IMAP for Roundcube |
| [FILEMANAGER_SETUP.md](FILEMANAGER_SETUP.md) | Manage users and folders in Filebrowser |

## 🔧 Add New Domains

```bash
sudo bash scripts/add_site.sh
```

Choose the desired model:
1. **WordPress** (app + MariaDB database)
2. **Static site** (Nginx)

## 🛡️ Firewall Management

After installation, use `manage_firewall.sh` to control access to internal ports:

```bash
# Interactive menu
sudo bash manage_firewall.sh

# Check status
sudo bash manage_firewall.sh status

# Block ports (production)
sudo bash manage_firewall.sh block

# Unblock ports (development)
sudo bash manage_firewall.sh unblock
```

## 🗑️ Uninstall

```bash
sudo bash scripts/uninstall.sh
```

Removes all containers, images, volumes, networks, and installation files.

## ⚙️ Optional Configuration

You can customize behavior by copying the example configuration:

```bash
cp .deploy-config.example .deploy-config
```

For test/lab environments, disable network hardening:
```bash
export DISABLE_NETWORK_HARDENING=1
```

For production, enable security blocking:
```bash
export BLOCK_DIRECT_AZURACAST_ACCESS=1
```

## 📄 Project Structure

- `scripts/install.sh` — Main installation script
- `scripts/add_site.sh` — Add new domain/WordPress
- `scripts/uninstall.sh` — Remove all services
- `scripts/lib/common.sh` — Shared functions
- `manage_firewall.sh` — Firewall management tool

## 🔐 License

MIT License - for automation scripts only.

Third-party software installed by these scripts have their own licenses:
- **AzuraCast** — Apache 2.0
- **Nginx Proxy Manager** — MIT  
- **Docker** — Apache 2.0
- **Roundcube** — GPL 3.0
- **Filebrowser** — Apache 2.0

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for details.

## 📞 Support

For issues, questions, or contributions, visit the [GitHub repository](https://github.com/chefinhoo/azuracast-deploy-automation).
