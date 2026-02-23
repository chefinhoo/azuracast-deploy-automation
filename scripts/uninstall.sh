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
# - AzuraCast (Apache 2.0)
#   https://www.azuracast.com
# - Nginx Proxy Manager (MIT)
#   https://nginxproxymanager.com
# - Roundcube Webmail (GPL 3.0)
#   https://roundcube.net
# - Filebrowser (Apache 2.0)
#   https://filebrowser.org
# - Mail Server (Postfix + Dovecot + PostfixAdmin)
# - Docker (Apache 2.0)
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

run_compose_down() {
    local compose_dir="$1"
    if [ ! -d "$compose_dir" ] || [ ! -f "$compose_dir/docker-compose.yml" ]; then
        return 0
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY-RUN] (cd $compose_dir && docker compose down -v --remove-orphans)"
    else
        (cd "$compose_dir" && docker compose down -v --remove-orphans) || true
    fi
}

remove_firewall_rules() {
    local ports=("8080" "8043" "2022" "9000:9999")
    local chains=("INPUT" "DOCKER-USER")
    local iptables_cmd
    local chain
    local port
    local iface

    echo "[INFO] Removendo regras de firewall do projeto (se existirem)... / Removing project firewall rules (if any)..."

    for iptables_cmd in iptables ip6tables; do
        if ! command -v "$iptables_cmd" >/dev/null 2>&1; then
            continue
        fi

        for chain in "${chains[@]}"; do
            if ! "$iptables_cmd" -nL "$chain" >/dev/null 2>&1; then
                continue
            fi

            for port in "${ports[@]}"; do
                if [ "$DRY_RUN" -eq 1 ]; then
                    echo "[DRY-RUN] while $iptables_cmd -D $chain ! -i lo -p tcp --dport $port -j DROP; do :; done"
                    echo "[DRY-RUN] while $iptables_cmd -D $chain -p tcp --dport $port -j DROP; do :; done"
                else
                    while "$iptables_cmd" -D "$chain" ! -i lo -p tcp --dport "$port" -j DROP >/dev/null 2>&1; do :; done
                    while "$iptables_cmd" -D "$chain" -p tcp --dport "$port" -j DROP >/dev/null 2>&1; do :; done
                fi

                if [ -d /sys/class/net ]; then
                    while IFS= read -r iface; do
                        [ -n "$iface" ] || continue
                        if [ "$DRY_RUN" -eq 1 ]; then
                            echo "[DRY-RUN] while $iptables_cmd -D $chain -i $iface -p tcp --dport $port -j DROP; do :; done"
                        else
                            while "$iptables_cmd" -D "$chain" -i "$iface" -p tcp --dport "$port" -j DROP >/dev/null 2>&1; do :; done
                        fi
                    done < <(ls /sys/class/net 2>/dev/null || true)
                fi
            done
        done
    done

    if command -v netfilter-persistent >/dev/null 2>&1 && command -v iptables-save >/dev/null 2>&1; then
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "[DRY-RUN] iptables-save > /etc/iptables/rules.v4"
            if command -v ip6tables-save >/dev/null 2>&1; then
                echo "[DRY-RUN] ip6tables-save > /etc/iptables/rules.v6"
            fi
        else
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
            if command -v ip6tables-save >/dev/null 2>&1; then
                ip6tables-save > /etc/iptables/rules.v6 2>/dev/null || true
            fi
        fi
    fi
}

containers=()
images=()
networks=()
volumes=()

if command -v docker >/dev/null 2>&1; then
    echo "[INFO] Docker encontrado. Iniciando limpeza de recursos Docker... / Docker found. Starting Docker resources cleanup..."

    echo "[INFO] Derrubando stacks docker-compose do projeto... / Bringing down project docker-compose stacks..."
    run_compose_down /var/proxy_manager
    run_compose_down /var/azuracast
    run_compose_down /var/webmail
    run_compose_down /var/filemanager
    run_compose_down /var/mailserver

    echo "[INFO] Derrubando stacks WordPress criadas por este instalador... / Bringing down WordPress stacks created by this installer..."
    while IFS= read -r wp_creds; do
        wp_dir="$(dirname "$wp_creds")"
        run_compose_down "$wp_dir"
    done < <(find /var/www -maxdepth 2 -type f -name wordpress-credentials.txt 2>/dev/null || true)

    echo "[INFO] Removendo containers do stack... / Removing stack containers..."
    mapfile -t containers < <(
        {
            docker ps -aq --filter "name=nginx-proxy-manager" || true
            docker ps -aq --filter "name=azuracast" || true
            docker ps -aq --filter "name=webmail-db" || true
            docker ps -aq --filter "name=webmail$" || true
            docker ps -aq --filter "name=webmail-nginx" || true
            docker ps -aq --filter "name=filemanager" || true
            docker ps -aq --filter "name=mail-mysql" || true
            docker ps -aq --filter "name=mailserver" || true
            docker ps -aq --filter "name=postfixadmin" || true
            docker ps -aq --filter "name=wp-app-" || true
            docker ps -aq --filter "name=wp-db-" || true
        } | awk 'NF' | sort -u
    )

    if [ "${#containers[@]}" -gt 0 ]; then
        run_cmd docker stop "${containers[@]}" || true
        run_cmd docker rm -f "${containers[@]}" || true
    fi

    echo "[INFO] Removendo imagens principais do stack... / Removing stack primary images..."
    mapfile -t images < <(
        docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' 2>/dev/null | \
            awk '/^(jc21\/nginx-proxy-manager|mariadb:10\.11|roundcube\/roundcubemail|filebrowser\/filebrowser|ghcr\.io\/docker-mailserver\/docker-mailserver|postfixadmin\/postfixadmin|wordpress:php8\.2-apache|nginx:latest)/{print $2}' | \
            sort -u
    )
    if [ "${#images[@]}" -gt 0 ]; then
        run_cmd docker rmi -f "${images[@]}" || true
    fi

    echo "[INFO] Removendo redes Docker do stack... / Removing stack Docker networks..."
    mapfile -t networks < <(
        docker network ls --format '{{.Name}}' 2>/dev/null | \
            grep -E '^(azuracast|proxy_manager|.*npm_network.*|webmail_network|filemanager_network|mailserver_network|wp-.*-network)$' || true
    )
    if [ "${#networks[@]}" -gt 0 ]; then
        run_cmd docker network rm "${networks[@]}" || true
    fi

    echo "[INFO] Removendo volumes Docker do stack... / Removing stack Docker volumes..."
    mapfile -t volumes < <(
        docker volume ls --format '{{.Name}}' 2>/dev/null | \
            grep -E '^(azuracast_|proxy_manager_|webmail_|mailserver_|filemanager_)' || true
    )
    if [ "${#volumes[@]}" -gt 0 ]; then
        run_cmd docker volume rm "${volumes[@]}" || true
    fi
else
    echo "[AVISO] Docker não encontrado. Pulando limpeza de containers/imagens/redes/volumes. / [WARN] Docker not found. Skipping containers/images/networks/volumes cleanup."
fi

remove_firewall_rules

echo "[INFO] Removendo diretórios de instalação e arquivos temporários... / Removing installation directories and temporary files..."
run_cmd rm -rf /var/azuracast
run_cmd rm -rf /var/proxy_manager
run_cmd rm -rf /var/webmail
run_cmd rm -rf /var/filemanager
run_cmd rm -rf /var/mailserver
run_cmd rm -rf /var/vmail
run_cmd rm -f /tmp/deployed_services
run_cmd rm -f /tmp/deployed_domain

echo "[INFO] Removendo sites WordPress criados por este instalador... / Removing WordPress sites created by this installer..."
while IFS= read -r wp_creds; do
    wp_dir="$(dirname "$wp_creds")"
    run_cmd rm -rf "$wp_dir"
done < <(find /var/www -maxdepth 2 -type f -name wordpress-credentials.txt 2>/dev/null || true)

run_cmd rm -rf ~/azuracast-deploy-automation
run_cmd rm -rf ~/.docker
run_cmd rm -rf /etc/docker
run_cmd rm -rf /etc/apt/keyrings/docker.gpg
run_cmd rm -rf /etc/apt/keyrings/docker.asc
run_cmd rm -rf /etc/apt/sources.list.d/docker.list
run_cmd rm -rf /etc/apt/sources.list.d/docker-ce.list
run_cmd rm -rf /etc/apt/sources.list.d/docker.sources
run_cmd rm -rf /etc/apt/sources.list.d/docker-ce.sources
run_cmd rm -rf /usr/local/bin/docker-compose

echo "[INFO] Removendo pacotes do Docker e dependências... / Removing Docker packages and dependencies..."
if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin docker-compose-v2"
    echo "[DRY-RUN] apt-get autoremove -y --purge"
else
    apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin docker-compose-v2 || true
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
run_cmd rm -rf /var/log/mail
run_cmd rm -rf /var/log/webmail
run_cmd rm -rf /var/log/filemanager

if [ "$DRY_RUN" -eq 1 ]; then
    echo "[OK] Simulação concluída com sucesso. / Dry-run simulation completed successfully."
else
    echo "[OK] Stack removido: AzuraCast, Nginx Proxy Manager, Webmail, Filemanager, Mailserver e Docker. / Stack removed: AzuraCast, Nginx Proxy Manager, Webmail, Filemanager, Mailserver, and Docker."
fi
