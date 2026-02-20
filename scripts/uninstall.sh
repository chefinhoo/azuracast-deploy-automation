#!/bin/bash
# =========================================================
# Script de remoção completa do AzuraCast + Nginx Proxy Manager
# Complete removal script for AzuraCast + Nginx Proxy Manager
# 
# Copyright (c) 2026 Danilo Ramos
# Licensed under MIT License (automation script only)
# Licenciado sob MIT (apenas script de automação)
# 
# This script removes installations of:
# Este script remove instalações de:
# - AzuraCast © AzuraCast Contributors (Apache 2.0)
#   https://www.azuracast.com
# - Nginx Proxy Manager © Jamie Curnow (MIT License)
#   https://nginxproxymanager.com
# - Docker © Docker, Inc. (Apache 2.0)
#   https://www.docker.com
# =========================================================

set -euo pipefail

DRY_RUN=0
FORCE_YES=0

for arg in "$@"; do
    case "$arg" in
        --dry-run|-n)
            DRY_RUN=1
            ;;
        --yes|-y)
            FORCE_YES=1
            ;;
        --help|-h)
            cat <<EOF
Uso / Usage:
  sudo bash scripts/uninstall.sh [--dry-run|-n] [--yes|-y]

Opções / Options:
  --dry-run, -n   Simula as ações sem executar remoção.
                  Simulate actions without removing anything.
  --yes, -y       Confirma automaticamente a remoção.
                  Automatically confirm removal.
  --help, -h      Exibe esta ajuda.
                  Show this help.
EOF
            exit 0
            ;;
        *)
            echo "[ERRO] Opção inválida: $arg / [ERROR] Invalid option: $arg"
            echo "Use --help para ver opções. / Use --help to see options."
            exit 1
            ;;
    esac
done

if [ "$DRY_RUN" -eq 1 ]; then
    echo "[INFO] Modo dry-run ativo. Nenhuma alteração será aplicada. / Dry-run mode enabled. No changes will be applied."
elif [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "[ERRO] Execute como root (sudo). / [ERROR] Run as root (sudo)."
    exit 1
fi

if [ "$DRY_RUN" -eq 0 ] && [ "$FORCE_YES" -eq 0 ]; then
    if [ ! -t 0 ]; then
        echo "[ERRO] Confirmação interativa indisponível neste terminal. Use --yes para continuar. / [ERROR] Interactive confirmation is unavailable in this terminal. Use --yes to continue."
        exit 1
    fi

    echo "[AVISO] Esta ação removerá AzuraCast, Nginx Proxy Manager e Docker deste servidor. / [WARN] This action will remove AzuraCast, Nginx Proxy Manager, and Docker from this server."
    read -r -p "Digite 'yes' para confirmar e continuar: / Type 'yes' to confirm and continue: " confirm
    if [ "$confirm" != "yes" ]; then
        echo "[INFO] Operação cancelada pelo usuário. / Operation canceled by user."
        exit 0
    fi
fi

run_cmd() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY-RUN] $*"
    else
        "$@"
    fi
}

containers=()
images=()
networks=()
volumes=()

if command -v docker >/dev/null 2>&1; then
    echo "[INFO] Docker encontrado. Iniciando limpeza de recursos Docker... / Docker found. Starting Docker resources cleanup..."

    echo "[INFO] Parando todos os containers do Docker... / Stopping all Docker containers..."
    mapfile -t containers < <(docker ps -aq 2>/dev/null || true)
    if [ "${#containers[@]}" -gt 0 ]; then
        run_cmd docker stop "${containers[@]}" || true
    fi

    echo "[INFO] Removendo todos os containers... / Removing all containers..."
    if [ "${#containers[@]}" -gt 0 ]; then
        run_cmd docker rm -f "${containers[@]}" || true
    fi

    echo "[INFO] Removendo todas as imagens do Docker... / Removing all Docker images..."
    mapfile -t images < <(docker images -aq 2>/dev/null || true)
    if [ "${#images[@]}" -gt 0 ]; then
        run_cmd docker rmi -f "${images[@]}" || true
    fi

    echo "[INFO] Removendo redes do Docker criadas pelo AzuraCast e NPM... / Removing Docker networks created by AzuraCast and NPM..."
    mapfile -t networks < <(docker network ls -q --filter name=azuracast --filter name=proxy_manager 2>/dev/null || true)
    if [ "${#networks[@]}" -gt 0 ]; then
        run_cmd docker network rm "${networks[@]}" || true
    fi

    echo "[INFO] Removendo volumes do Docker... / Removing Docker volumes..."
    mapfile -t volumes < <(docker volume ls -q --filter name=azuracast --filter name=proxy_manager 2>/dev/null || true)
    if [ "${#volumes[@]}" -gt 0 ]; then
        run_cmd docker volume rm "${volumes[@]}" || true
    fi
else
    echo "[AVISO] Docker não encontrado. Pulando limpeza de containers/imagens/redes/volumes. / [WARN] Docker not found. Skipping containers/images/networks/volumes cleanup."
fi

echo "[INFO] Removendo diretórios de instalação e arquivos temporários... / Removing installation directories and temporary files..."
run_cmd rm -rf /var/azuracast
run_cmd rm -rf /var/proxy_manager
run_cmd rm -rf ~/azuracast-deploy-automation
run_cmd rm -rf ~/.docker
run_cmd rm -rf /etc/docker
run_cmd rm -rf /etc/apt/keyrings/docker.gpg
run_cmd rm -rf /usr/local/bin/docker-compose

echo "[INFO] Removendo pacotes do Docker e dependências... / Removing Docker packages and dependencies..."
if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin"
    echo "[DRY-RUN] apt-get autoremove -y --purge"
else
    apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin || true
    apt-get autoremove -y --purge || true
fi

echo "[INFO] Limpando cache do apt... / Cleaning apt cache..."
if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] apt-get clean"
    echo "[DRY-RUN] rm -rf /var/lib/apt/lists/*"
else
    apt-get clean
    rm -rf /var/lib/apt/lists/*
fi

echo "[INFO] Removendo usuários e grupos criados (se existirem)... / Removing created users and groups (if any)..."
# Remove usuário nginx-proxy-manager se criado
if id -u npm &>/dev/null; then
    run_cmd userdel -r npm || true
fi
# Remove grupo docker se não usado por outros usuários
if getent group docker &>/dev/null; then
    run_cmd groupdel docker || true
fi

echo "[INFO] Removendo arquivos de logs e caches adicionais... / Removing additional log and cache files..."
run_cmd rm -rf /var/log/azuracast
run_cmd rm -rf /var/log/proxy_manager

if [ "$DRY_RUN" -eq 1 ]; then
    echo "[OK] Simulação concluída com sucesso. / Dry-run simulation completed successfully."
else
    echo "[OK] AzuraCast, Nginx Proxy Manager e Docker removidos completamente! / AzuraCast, Nginx Proxy Manager, and Docker were completely removed!"
fi
