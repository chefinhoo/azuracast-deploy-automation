#!/usr/bin/env bash
#
# Gerenciar Bloqueio/Desbloqueio de Portas
# Manage Port Blocking/Unblocking for AzuraCast
#
# Este script oferece um controle granular sobre o acesso as portas do AzuraCast:
#
# Quando BLOQUEADO:
#   ✓ Acesso local (127.0.0.1)   - PERMITIDO (para diagnóstico/curl)
#   ✓ Acesso por domínio (DNS)   - PERMITIDO (via Nginx Proxy Manager)
#   ✗ Acesso por IP externo      - BLOQUEADO (força uso de proxy/domínio)
#
# Quando DESBLOQUEADO (padrão):
#   ✓ Acesso local (127.0.0.1)   - PERMITIDO
#   ✓ Acesso por domínio (DNS)   - PERMITIDO
#   ✓ Acesso por IP externo      - PERMITIDO (direto na porta)
#
# Recomendado: bloquear em PRODUÇÃO, desbloquear em DESENVOLVIMENTO
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Portas a gerenciar
AZURACAST_HTTP_PORT="8080"
AZURACAST_HTTPS_PORT="8043"
SFTP_PORT="2022"
STREAMING_PORTS="9000:9999"

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERRO]${NC} Este script precisa ser executado como root"
    exit 1
fi

# Funções de cores
print_header() {
    echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
}

check_iptables() {
    if ! command -v iptables &> /dev/null; then
        echo -e "${RED}[ERRO]${NC} iptables não está instalado"
        exit 1
    fi
}

# Bloquear portas
block_ports() {
    print_header "BLOQUEANDO PORTAS"
    echo ""
    
    check_iptables
    
    local iface="${FIREWALL_INTERFACE:-}"
    local ports=("$AZURACAST_HTTP_PORT" "$AZURACAST_HTTPS_PORT" "$SFTP_PORT" "$STREAMING_PORTS")
    
    add_drop_rule_v4() {
        local chain="$1"
        local port_spec="$2"
        local rule_args=()
        if [ -n "$iface" ]; then
            rule_args=( -i "$iface" )
        else
            # Não bloquear tráfego local (localhost/loopback).
            # Mantém testes com curl http://127.0.0.1:<porta> funcionando.
            rule_args=( ! -i lo )
        fi
        
        if iptables -C "$chain" "${rule_args[@]}" -p tcp --dport "$port_spec" -j DROP >/dev/null 2>&1; then
            echo -e "${YELLOW}•${NC} IPv4 já existe: $chain porta $port_spec"
        else
            iptables -I "$chain" 1 "${rule_args[@]}" -p tcp --dport "$port_spec" -j DROP
            echo -e "${GREEN}✓${NC} IPv4 bloqueada ($chain): porta $port_spec"
        fi
    }
    
    add_drop_rule_v6() {
        local chain="$1"
        local port_spec="$2"
        local rule_args=()
        
        if ! command -v ip6tables &> /dev/null || ! ip6tables -nL "$chain" >/dev/null 2>&1; then
            return 0
        fi
        
        if [ -n "$iface" ]; then
            rule_args=( -i "$iface" )
        else
            # Preservar tráfego local IPv6 (::1/loopback)
            rule_args=( ! -i lo )
        fi
        
        if ip6tables -C "$chain" "${rule_args[@]}" -p tcp --dport "$port_spec" -j DROP >/dev/null 2>&1; then
            echo -e "${YELLOW}•${NC} IPv6 já existe: $chain porta $port_spec"
        else
            ip6tables -I "$chain" 1 "${rule_args[@]}" -p tcp --dport "$port_spec" -j DROP
            echo -e "${GREEN}✓${NC} IPv6 bloqueada ($chain): porta $port_spec"
        fi
    }
    
    add_drop_rule() {
        local port_spec="$1"
        
        if iptables -nL DOCKER-USER >/dev/null 2>&1; then
            add_drop_rule_v4 "DOCKER-USER" "$port_spec"
        fi
        
        add_drop_rule_v4 "INPUT" "$port_spec"
        
        add_drop_rule_v6 "DOCKER-USER" "$port_spec"
        add_drop_rule_v6 "INPUT" "$port_spec"
    }
    
    for port in "${ports[@]}"; do
        add_drop_rule "$port"
    done
    
    echo ""
    if [ -n "$iface" ]; then
        echo -e "${BLUE}ℹ${NC} Bloqueio aplicado na interface: $iface"
    else
        echo -e "${BLUE}ℹ${NC} Localhost/loopback permanece liberado para diagnóstico"
    fi
    
    echo ""
    save_firewall_rules
}

# Desbloquear portas
unblock_ports() {
    print_header "DESBLOQUEANDO PORTAS"
    echo ""
    
    check_iptables
    
    local iface="${FIREWALL_INTERFACE:-}"
    local ports=("$AZURACAST_HTTP_PORT" "$AZURACAST_HTTPS_PORT" "$SFTP_PORT" "$STREAMING_PORTS")
    
    remove_drop_rule_v4() {
        local chain="$1"
        local port_spec="$2"
        local rule_args=()
        if [ -n "$iface" ]; then
            rule_args=( -i "$iface" )
        else
            rule_args=( ! -i lo )
        fi
        
        while iptables -D "$chain" "${rule_args[@]}" -p tcp --dport "$port_spec" -j DROP >/dev/null 2>&1; do
            echo -e "${GREEN}✓${NC} IPv4 desbloqueada ($chain): porta $port_spec"
        done
    }
    
    remove_drop_rule_v6() {
        local chain="$1"
        local port_spec="$2"
        local rule_args=()
        
        if ! command -v ip6tables &> /dev/null || ! ip6tables -nL "$chain" >/dev/null 2>&1; then
            return 0
        fi
        
        if [ -n "$iface" ]; then
            rule_args=( -i "$iface" )
        else
            rule_args=( ! -i lo )
        fi
        
        while ip6tables -D "$chain" "${rule_args[@]}" -p tcp --dport "$port_spec" -j DROP >/dev/null 2>&1; do
            echo -e "${GREEN}✓${NC} IPv6 desbloqueada ($chain): porta $port_spec"
        done
    }
    
    remove_drop_rule() {
        local port_spec="$1"
        
        if iptables -nL DOCKER-USER >/dev/null 2>&1; then
            remove_drop_rule_v4 "DOCKER-USER" "$port_spec"
        fi
        
        remove_drop_rule_v4 "INPUT" "$port_spec"
        
        remove_drop_rule_v6 "DOCKER-USER" "$port_spec"
        remove_drop_rule_v6 "INPUT" "$port_spec"
    }
    
    for port in "${ports[@]}"; do
        remove_drop_rule "$port"
    done
    
    echo ""
    echo -e "${BLUE}ℹ${NC} Acesso direto por IP agora está disponível"
    echo ""
    save_firewall_rules
}

# Verificar status
check_status() {
    print_header "STATUS DAS PORTAS"
    echo ""
    
    check_iptables
    
    local iface="${FIREWALL_INTERFACE:-}"
    
    if [ -n "$iface" ]; then
        echo -e "${BLUE}Interface: $iface${NC}"
        echo ""
    else
        echo -e "${BLUE}Tráfego local (localhost) permanece liberado${NC}"
        echo ""
    fi
    
    check_rule_v4() {
        local chain="$1"
        local port="$2"
        local name="$3"
        local rule_args=()
        if [ -n "$iface" ]; then
            rule_args=( -i "$iface" )
        else
            rule_args=( ! -i lo )
        fi
        
        if iptables -C "$chain" "${rule_args[@]}" -p tcp --dport "$port" -j DROP >/dev/null 2>&1; then
            echo -e "  ${RED}✗ Porta $port ($name)${NC} - BLOQUEADA"
            return 0
        else
            echo -e "  ${GREEN}✓ Porta $port ($name)${NC} - ABERTA"
            return 1
        fi
    }
    
    echo -e "${BLUE}Input Chain (IPv4):${NC}"
    echo ""
    check_rule_v4 "INPUT" "$AZURACAST_HTTP_PORT" "AzuraCast HTTP"
    check_rule_v4 "INPUT" "$AZURACAST_HTTPS_PORT" "AzuraCast HTTPS"
    check_rule_v4 "INPUT" "$SFTP_PORT" "SFTP"
    check_rule_v4 "INPUT" "$STREAMING_PORTS" "Streaming"
    
    echo ""
    
    if command -v ip6tables &> /dev/null && ip6tables -nL INPUT >/dev/null 2>&1; then
        check_rule_v6() {
            local chain="$1"
            local port="$2"
            local name="$3"
            local rule_args=()
            if [ -n "$iface" ]; then
                rule_args=( -i "$iface" )
            else
                rule_args=( ! -i lo )
            fi
            
            if ip6tables -C "$chain" "${rule_args[@]}" -p tcp --dport "$port" -j DROP >/dev/null 2>&1; then
                echo -e "  ${RED}✗ Porta $port ($name)${NC} - BLOQUEADA"
                return 0
            else
                echo -e "  ${GREEN}✓ Porta $port ($name)${NC} - ABERTA"
                return 1
            fi
        }
        
        echo -e "${BLUE}Input Chain (IPv6):${NC}"
        echo ""
        check_rule_v6 "INPUT" "$AZURACAST_HTTP_PORT" "AzuraCast HTTP"
        check_rule_v6 "INPUT" "$AZURACAST_HTTPS_PORT" "AzuraCast HTTPS"
        check_rule_v6 "INPUT" "$SFTP_PORT" "SFTP"
        check_rule_v6 "INPUT" "$STREAMING_PORTS" "Streaming"
        echo ""
    fi
}

# Salvar regras persistentemente
save_firewall_rules() {
    echo -e "${YELLOW}→${NC} Salvando regras de firewall..."
    
    if command -v iptables-save &> /dev/null && command -v netfilter-persistent &> /dev/null; then
        if iptables-save > /etc/iptables/rules.v4 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Regras salvas em /etc/iptables/rules.v4"
        fi
        
        if command -v ip6tables-save &> /dev/null; then
            if ip6tables-save > /etc/iptables/rules.v6 2>/dev/null; then
                echo -e "${GREEN}✓${NC} Regras IPv6 salvas em /etc/iptables/rules.v6"
            fi
        fi
        
        echo ""
        echo -e "${BLUE}Para persistir após reboot, instale:${NC}"
        echo "  sudo apt-get install -y iptables-persistent"
        echo "  sudo netfilter-persistent save"
    else
        echo -e "${YELLOW}⚠${NC} iptables-persistent não instalado"
        echo -e "${YELLOW}⚠${NC} Regras podem ser perdidas após reboot"
        echo ""
        echo -e "${BLUE}Para salvar persistentemente:${NC}"
        echo "  sudo apt-get install -y iptables-persistent"
    fi
}

# Menu principal
show_menu() {
    echo ""
    echo -e "${BLUE}Escolha uma opção:${NC}"
    echo "  1) Verificar status das portas"
    echo "  2) Bloquear portas (acesso apenas via proxy/domínio)"
    echo "  3) Desbloquear portas (acesso direto por IP)"
    echo "  4) Sair"
    echo ""
}

# Main
main() {
    if [ $# -eq 0 ]; then
        print_header "GERENCIAR FIREWALL - AzuraCast"
        echo ""
        echo "Este script permite bloquear/desbloquear portas do AzuraCast"
        echo ""
        echo -e "${BLUE}Comportamento do bloqueio:${NC}"
        echo "  • Localhost (127.0.0.1) permanece sempre acessível para testes"
        echo "  • Acesso externo por IP é bloqueado/liberado conforme configurado"
        echo "  • Acesso por domínio via Nginx Proxy Manager (NPM) não é afetado"
        echo ""
        
        while true; do
            show_menu
            read -rp "Opção: " option
            
            case $option in
                1)
                    check_status
                    ;;
                2)
                    read -rp "Tem certeza que deseja BLOQUEAR as portas? [s/N]: " confirm
                    if [[ "$confirm" =~ ^[sS]$ ]]; then
                        block_ports
                        echo -e "${GREEN}✓${NC} Portas bloqueadas com sucesso"
                        echo -e "${BLUE}ℹ${NC} Acesso agora apenas via:"
                        echo "     - Localhost: http://127.0.0.1:8080/ (para diagnóstico)"
                        echo "     - Domínio: http://azura.exemplo.com.br/"
                    else
                        echo "Cancelado."
                    fi
                    ;;
                3)
                    read -rp "Tem certeza que deseja DESBLOQUEAR as portas? [s/N]: " confirm
                    if [[ "$confirm" =~ ^[sS]$ ]]; then
                        unblock_ports
                        echo -e "${GREEN}✓${NC} Portas desbloqueadas com sucesso"
                        echo -e "${BLUE}ℹ${NC} Acesso agora disponível em:"
                        echo "     - IP direto: http://147.15.92.21:8080/"
                        echo "     - Localhost: http://127.0.0.1:8080/"
                        echo "     - Domínio: http://azura.exemplo.com.br/"
                    else
                        echo "Cancelado."
                    fi
                    ;;
                4)
                    echo "Saindo..."
                    exit 0
                    ;;
                *)
                    echo -e "${RED}Opção inválida${NC}"
                    ;;
            esac
        done
    else
        case "$1" in
            status)
                check_status
                ;;
            block)
                echo -e "${YELLOW}→${NC} Bloqueando portas..."
                block_ports
                echo -e "${GREEN}✓${NC} Concluído"
                ;;
            unblock)
                echo -e "${YELLOW}→${NC} Desbloqueando portas..."
                unblock_ports
                echo -e "${GREEN}✓${NC} Concluído"
                ;;
            *)
                echo "Uso: $0 [status|block|unblock]"
                echo ""
                echo "Exemplos:"
                echo "  sudo bash $0               # Menu interativo"
                echo "  sudo bash $0 status        # Verificar status"
                echo "  sudo bash $0 block         # Bloquear portas"
                echo "  sudo bash $0 unblock       # Desbloquear portas"
                echo ""
                echo "Variáveis de ambiente:"
                echo "  FIREWALL_INTERFACE=eth0   # Bloquear em interface específica"
                exit 1
                ;;
        esac
    fi
}

main "$@"
