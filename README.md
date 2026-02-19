# AzuraCast Deploy Automation

[![Test Scripts](https://github.com/chefinhoo/azuracast-deploy-automation/actions/workflows/test-scripts.yml/badge.svg)](https://github.com/chefinhoo/azuracast-deploy-automation/actions/workflows/test-scripts.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Automated deployment and removal scripts for **AzuraCast** + **Nginx Proxy Manager** on Ubuntu ARM.

## Features

- Install AzuraCast with Docker and Docker Compose
- Automatic port adjustment for Nginx Proxy Manager
- Uninstall script to remove all services and containers
- Configured for multi-site setup behind Nginx Proxy Manager
- Easy-to-follow instructions for proxy and SSL setup

## Scripts

- `scripts/install.sh` — Install AzuraCast + Nginx Proxy Manager
- `scripts/uninstall.sh` — Remove everything installed

## Usage

### Installation

```bash
# Clone the repository
git clone https://github.com/chefinhoo/azuracast-deploy-automation.git
cd azuracast-deploy-automation

# Run the installation script
sudo bash scripts/install.sh
```

### Uninstallation

```bash
sudo bash scripts/uninstall.sh
```

## Recommended Next Steps

1. **Access Nginx Proxy Manager GUI:** `http://<IP_DO_SERVIDOR>:81`
   - Default credentials:
     - Email: `admin@example.com`
     - Password: `changeme`
   - **IMPORTANT:** Change credentials immediately after first login!

2. **Create a Proxy Host pointing to AzuraCast:**
   - Domain Names: `seu domínio` (ex: azura.daniloramos.dev.br)
   - Scheme: `http`
   - Forward Hostname/IP: `IP público do servidor` or Docker container name
   - Forward Port: `8000`
   - Enable Websockets: ✅
   - Block Common Exploits: ✅

3. **SSL Tab:**
   - Request a new SSL certificate
   - Force SSL: ✅
   - HTTP/2 Support: ✅
   - Provide email and accept Let's Encrypt Terms

4. **Access AzuraCast via your domain:** `https://azura.daniloramos.dev.br`

## What Gets Installed

- **Docker & Docker Compose** (if not already installed)
- **AzuraCast** in `/var/azuracast`
  - Web panel on port `8000`
  - Streaming ports `8010-8500`
- **Nginx Proxy Manager** in `/opt/nginx-proxy-manager`
  - Admin panel on port `81`
  - HTTP on port `80`
  - HTTPS on port `443`

## Requirements

- Ubuntu 20.04+ or Debian 11+
- ARM64 or x86_64 architecture
- Root or sudo access
- At least 4GB RAM
- 20GB free disk space

## Ports Used

| Service | Port | Description |
|---------|------|-------------|
| Nginx Proxy Manager | 80 | HTTP |
| Nginx Proxy Manager | 443 | HTTPS |
| Nginx Proxy Manager | 81 | Admin Panel |
| AzuraCast | 8000 | Web Panel |
| AzuraCast | 8010-8500 | Radio Streams |

## Troubleshooting

### Port Already in Use

```bash
# Check what's using the port
sudo lsof -i :80
sudo lsof -i :8000

# Stop conflicting services
sudo systemctl stop apache2
sudo systemctl stop nginx
```

### Check AzuraCast Logs

```bash
cd /var/azuracast
./docker.sh logs
```

### Check NPM Logs

```bash
cd /opt/nginx-proxy-manager
docker compose logs -f
```

### Update AzuraCast

```bash
cd /var/azuracast
./docker.sh update-self
./docker.sh update
```

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Links

- [AzuraCast Documentation](https://docs.azuracast.com)
- [Nginx Proxy Manager](https://nginxproxymanager.com/)
- [Docker Documentation](https://docs.docker.com/)
