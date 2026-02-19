#!/bin/bash
# uninstall.sh
# Script para remover completamente AzuraCast + Nginx Proxy Manager + Docker

set -euo pipefail

echo "[INFO] Parando todos os containers do Docker..."
mapfile -t containers < <(docker ps -aq)
if [ "${#containers[@]}" -gt 0 ]; then
    docker stop "${containers[@]}"
fi

echo "[INFO] Removendo todos os containers..."
if [ "${#containers[@]}" -gt 0 ]; then
    docker rm -f "${containers[@]}"
fi

echo "[INFO] Removendo todas as imagens do Docker..."
mapfile -t images < <(docker images -aq)
if [ "${#images[@]}" -gt 0 ]; then
    docker rmi -f "${images[@]}"
fi

echo "[INFO] Removendo redes do Docker criadas pelo AzuraCast e NPM..."
mapfile -t networks < <(docker network ls -q --filter name=azuracast --filter name=proxy_manager)
if [ "${#networks[@]}" -gt 0 ]; then
    docker network rm "${networks[@]}"
fi

echo "[INFO] Removendo volumes do Docker..."
mapfile -t volumes < <(docker volume ls -q --filter name=azuracast --filter name=proxy_manager)
if [ "${#volumes[@]}" -gt 0 ]; then
    docker volume rm "${volumes[@]}"
fi

echo "[INFO] Removendo diretórios de instalação..."
rm -rf /var/azuracast
rm -rf /var/proxy_manager

echo "[INFO] Desinstalando Docker e Docker Compose (opcional)..."
apt-get remove -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin || true
apt-get autoremove -y || true

echo "[OK] AzuraCast e Nginx Proxy Manager removidos completamente!"
