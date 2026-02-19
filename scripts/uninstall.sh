#!/bin/bash
# =========================================================
# Script de remoção completa do AzuraCast + Nginx Proxy Manager
# =========================================================

set -e

echo "[INFO] Parando containers Docker..."
docker-compose -f /var/azuracast/docker-compose.yml down || true
docker-compose -f /var/proxy_manager/docker-compose.yml down || true

echo "[INFO] Removendo containers, volumes e redes..."
docker rm -f $(docker ps -aq) 2>/dev/null || true
docker network prune -f
docker volume prune -f

echo "[INFO] Removendo diretórios de instalação..."
rm -rf /var/azuracast
rm -rf /var/proxy_manager

echo "[INFO] Limpeza completa! Docker e imagens permanecem instalados."
