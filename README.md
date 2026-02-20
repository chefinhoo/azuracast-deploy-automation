# AzuraCast Deploy Automation

[![Test Scripts](https://github.com/chefinhoo/azuracast-deploy-automation/actions/workflows/test-scripts.yml/badge.svg)](https://github.com/chefinhoo/azuracast-deploy-automation/actions/workflows/test-scripts.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Automated deployment and removal scripts for **AzuraCast** + **Nginx Proxy Manager** on Ubuntu ARM/x86.

## Features

- Install AzuraCast with Docker and Docker Compose
- Automatic port adjustment for Nginx Proxy Manager
- Complete uninstall script to remove all services, containers, volumes, and configuration files
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
