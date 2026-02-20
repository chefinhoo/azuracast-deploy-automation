#!/bin/bash
# =========================================================
# Script de remoção completa do AzuraCast + Nginx Proxy Manager
# 
# Copyright (c) 2026 Danilo Ramos
# Licensed under MIT License (automation script only)
# 
# This script removes installations of:
# - AzuraCast © AzuraCast Contributors (Apache 2.0)
#   https://www.azuracast.com
# - Nginx Proxy Manager © Jamie Curnow (MIT License)
#   https://nginxproxymanager.com
# - Docker © Docker, Inc. (Apache 2.0)
#   https://www.docker.com
# =========================================================

set -euo pipefail

echo "[INFO] Parando todos os containers do Docker..."
mapfile -t containers < <(docker ps -aq)
if [ "${#containers[@]}" -gt 0 ]; then
    docker stop "${containers[@]}" || true
fi

echo "[INFO] Removendo todos os containers..."
if [ "${#containers[@]}" -gt 0 ]; then
    docker rm -f "${containers[@]}" || true
fi

echo "[INFO] Removendo todas as imagens do Docker..."
mapfile -t images < <(docker images -aq)
if [ "${#images[@]}" -gt 0 ]; then
    docker rmi -f "${images[@]}" || true
fi

echo "[INFO] Removendo redes do Docker criadas pelo AzuraCast e NPM..."
mapfile -t networks < <(docker network ls -q --filter name=azuracast --filter name=proxy_manager)
if [ "${#networks[@]}" -gt 0 ]; then
    docker network rm "${networks[@]}" || true
fi

echo "[INFO] Removendo volumes do Docker..."
mapfile -t volumes < <(docker volume ls -q --filter name=azuracast --filter name=proxy_manager)
if [ "${#volumes[@]}" -gt 0 ]; then
    docker volume rm "${volumes[@]}" || true
fi

echo "[INFO] Removendo diretórios de instalação e arquivos temporários..."
rm -rf /var/azuracast
rm -rf /var/proxy_manager
rm -rf ~/azuracast-deploy-automation
rm -rf ~/.docker
rm -rf /etc/docker
rm -rf /etc/apt/keyrings/docker.gpg
rm -rf /usr/local/bin/docker-compose

echo "[INFO] Removendo pacotes do Docker e dependências..."
apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin || true
apt-get autoremove -y --purge || true

echo "[INFO] Limpando cache do apt..."
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "[INFO] Removendo usuários e grupos criados (se existirem)..."
# Remove usuário nginx-proxy-manager se criado
id -u npm &>/dev/null && userdel -r npm || true
# Remove grupo docker se não usado por outros usuários
getent group docker &>/dev/null && groupdel docker || true

echo "[INFO] Removendo arquivos de logs e caches adicionais..."
rm -rf /var/log/azuracast
rm -rf /var/log/proxy_manager

echo "[OK] AzuraCast, Nginx Proxy Manager e Docker removidos completamente!"
