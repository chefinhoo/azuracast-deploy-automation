#!/bin/bash

# =========================================================
# Script de instalação de Servidor de E-mail Completo
# Mail Server Installation Script
# 
# Instala:
# - Postfix (SMTP - enviar/receber emails)
# - Dovecot (IMAP/POP3 - armazenar emails)
# - PostfixAdmin (Painel web para gerenciar contas)
# - MySQL (database para contas virtuais)
# - SpamAssassin (anti-spam)
# - Integração automática com Roundcube
# =========================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
log_error() { echo -e "${RED}[ERRO]${NC} $1"; }

# Verificar root
if [ "$EUID" -ne 0 ]; then 
    log_error "Este script precisa ser executado como root"
    echo "Execute: sudo bash $0"
    exit 1
fi

# Banner
clear
echo "════════════════════════════════════════════════════════"
echo "  📧 INSTALAÇÃO DE SERVIDOR DE E-MAIL COMPLETO"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Este script vai instalar:"
echo "  ✓ Postfix (SMTP - enviar/receber e-mails)"
echo "  ✓ Dovecot (IMAP - armazenar e-mails)"
echo "  ✓ PostfixAdmin (Painel web para criar contas)"
echo "  ✓ MySQL (Database)"
echo "  ✓ SpamAssassin (Anti-spam)"
echo "  ✓ Configuração automática do Roundcube"
echo ""
echo "════════════════════════════════════════════════════════"
echo ""

# Solicitar domínio principal
read -p "Digite o domínio principal para e-mail (ex: exemplo.com.br): " MAIL_DOMAIN
if [ -z "$MAIL_DOMAIN" ]; then
    log_error "Domínio não pode ser vazio"
    exit 1
fi

HOSTNAME="mail.$MAIL_DOMAIN"

log_info "Domínio configurado: $MAIL_DOMAIN"
log_info "Hostname recomendado do servidor: $HOSTNAME"
echo ""

# Avisos importantes
echo "════════════════════════════════════════════════════════"
echo "  ⚠️  REQUISITOS IMPORTANTES"
echo "════════════════════════════════════════════════════════"
echo ""
echo "1. DNS - Configure ANTES de continuar:"
echo "   • Registro A: mail.$MAIL_DOMAIN → SEU_IP_PUBLICO"
echo "   • Registro MX: $MAIL_DOMAIN → mail.$MAIL_DOMAIN (prioridade 10)"
echo "   • Registro PTR (Reverse DNS): SEU_IP → mail.$MAIL_DOMAIN"
echo ""
echo "2. Portas necessárias:"
echo "   • 25 (SMTP)"
echo "   • 587 (Submission)"
echo "   • 993 (IMAPS)"
echo "   • 995 (POP3S)"
echo ""
echo "3. Hostname do servidor será configurado como: $HOSTNAME"
echo ""
echo "════════════════════════════════════════════════════════"
echo ""

read -p "DNS configurado e pronto para continuar? (s/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
    log_warn "Configure o DNS primeiro e execute novamente"
    exit 0
fi

# Perguntar se deseja alterar o hostname
CHANGE_HOSTNAME="Y"
echo ""
read -p "Deseja alterar o hostname do servidor para '$HOSTNAME'? (S/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Nn]$ ]]; then
    CHANGE_HOSTNAME="N"
    log_warn "O hostname NÃO será alterado. Certifique-se que DNS PTR aponta para o hostname atual."
fi

MAIL_DIR="/var/mailserver"
POSTFIXADMIN_DIR="$MAIL_DIR/postfixadmin"
VMAIL_DIR="/var/vmail"

# Gerar senhas
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 24)
POSTFIX_DB_PASSWORD=$(openssl rand -base64 24)
POSTFIXADMIN_SETUP_PASSWORD=$(openssl rand -base64 24)

# Criar diretórios
log_info "Criando estrutura de diretórios..."
mkdir -p "$MAIL_DIR" "$POSTFIXADMIN_DIR" "$VMAIL_DIR"
chmod 770 "$VMAIL_DIR"

# Configurar hostname (se o usuário aceitou)
if [[ "$CHANGE_HOSTNAME" == "Y" ]]; then
    log_info "Configurando hostname do sistema..."
    hostnamectl set-hostname "$HOSTNAME" 2>/dev/null || echo "$HOSTNAME" > /etc/hostname
    hostname "$HOSTNAME" 2>/dev/null || true
    log_success "Hostname configurado: $HOSTNAME"
else
    log_info "Hostname não será alterado (mantendo: $(hostname))"
fi

# Docker Compose para Mail Server
log_info "Criando docker-compose.yml..."
cat > "$MAIL_DIR/docker-compose.yml" <<EOF
services:
  # MySQL para contas virtuais
  mail-mysql:
    image: mariadb:10.11
    container_name: mail-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: "${MYSQL_ROOT_PASSWORD}"
      MYSQL_DATABASE: "postfix"
      MYSQL_USER: "postfix"
      MYSQL_PASSWORD: "${POSTFIX_DB_PASSWORD}"
    volumes:
      - mail_mysql_data:/var/lib/mysql
      - ./init-mailserver.sql:/docker-entrypoint-initdb.d/init.sql:ro
    networks:
      - mailserver_network

  # Postfix + Dovecot (tudo-em-um)
  mailserver:
    image: ghcr.io/docker-mailserver/docker-mailserver:latest
    container_name: mailserver
    hostname: ${HOSTNAME}
    domainname: ${MAIL_DOMAIN}
    restart: unless-stopped
    ports:
      - "25:25"      # SMTP
      - "587:587"    # Submission (autenticado)
      - "993:993"    # IMAPS
      - "995:995"    # POP3S
    environment:
      - OVERRIDE_HOSTNAME=${HOSTNAME}
      - ENABLE_SPAMASSASSIN=1
      - ENABLE_CLAMAV=0   # AntiVirus desabilitado (usa muita RAM)
      - ENABLE_FAIL2BAN=1
      - ENABLE_POSTGREY=0
      - ONE_DIR=1
      - DMS_DEBUG=0
      - PERMIT_DOCKER=network
      - SSL_TYPE=manual
      - SSL_CERT_PATH=/etc/ssl/mail/cert.pem
      - SSL_KEY_PATH=/etc/ssl/mail/key.pem
    volumes:
      - mail_data:/var/mail
      - mail_state:/var/mail-state
      - mail_logs:/var/log/mail
      - ./config:/tmp/docker-mailserver:rw
      - /etc/letsencrypt:/etc/letsencrypt:ro
    cap_add:
      - NET_ADMIN
    networks:
      - mailserver_network
      - proxy_manager_npm_network

  # PostfixAdmin - Painel de administração
  postfixadmin:
    image: postfixadmin/postfixadmin:latest
    container_name: postfixadmin
    restart: unless-stopped
    ports:
      - "8888:80"
    environment:
      POSTFIXADMIN_DB_TYPE: "mysqli"
      POSTFIXADMIN_DB_HOST: "mail-mysql"
      POSTFIXADMIN_DB_NAME: "postfix"
      POSTFIXADMIN_DB_USER: "postfix"
      POSTFIXADMIN_DB_PASS word: "${POSTFIX_DB_PASSWORD}"
      POSTFIXADMIN_SMTP_SERVER: "mailserver"
      POSTFIXADMIN_SMTP_PORT: "25"
      POSTFIXADMIN_SETUP_PASSWORD: "${POSTFIXADMIN_SETUP_PASSWORD}"
    depends_on:
      - mail-mysql
      - mailserver
    networks:
      - mailserver_network
      - proxy_manager_npm_network

volumes:
  mail_mysql_data:
  mail_data:
  mail_state:
  mail_logs:

networks:
  mailserver_network:
    driver: bridge
  proxy_manager_npm_network:
    external: true
EOF

# Script SQL de inicialização
log_info "Criando script de inicialização do banco de dados..."
cat > "$MAIL_DIR/init-mailserver.sql" <<'SQLEOF'
-- Tabelas para PostfixAdmin
CREATE TABLE IF NOT EXISTS admin (
    username VARCHAR(255) NOT NULL PRIMARY KEY,
    password VARCHAR(255) NOT NULL,
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modified DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    active TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS domain (
    domain VARCHAR(255) NOT NULL PRIMARY KEY,
    description VARCHAR(255),
    aliases INT(10) NOT NULL DEFAULT 0,
    mailboxes INT(10) NOT NULL DEFAULT 0,
    maxquota BIGINT(20) NOT NULL DEFAULT 0,
    quota BIGINT(20) NOT NULL DEFAULT 0,
    transport VARCHAR(255),
    backupmx TINYINT(1) NOT NULL DEFAULT 0,
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modified DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    active TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS mailbox (
    username VARCHAR(255) NOT NULL PRIMARY KEY,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    maildir VARCHAR(255) NOT NULL,
    quota BIGINT(20) NOT NULL DEFAULT 0,
    local_part VARCHAR(255) NOT NULL,
    domain VARCHAR(255) NOT NULL,
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modified DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    active TINYINT(1) NOT NULL DEFAULT 1,
    FOREIGN KEY (domain) REFERENCES domain(domain) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS alias (
    address VARCHAR(255) NOT NULL PRIMARY KEY,
    goto TEXT NOT NULL,
    domain VARCHAR(255) NOT NULL,
    created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modified DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    active TINYINT(1) NOT NULL DEFAULT 1,
    FOREIGN KEY (domain) REFERENCES domain(domain) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Índices para performance
CREATE INDEX idx_mailbox_domain ON mailbox(domain);
CREATE INDEX idx_alias_domain ON alias(domain);
SQLEOF

# Criar diretório de configuração
mkdir -p "$MAIL_DIR/config"

log_info "Iniciando containers do servidor de e-mail..."
cd "$MAIL_DIR"
if docker compose up -d; then
    log_success "Servidor de e-mail iniciado com sucesso!"
else
    log_error "Falha ao iniciar servidor de e-mail"
    exit 1
fi

# Aguardar containers iniciarem
log_info "Aguardando containers iniciarem (60 segundos)..."
sleep 60

# Atualizar Roundcube para usar o servidor local
log_info "Configurando Roundcube para usar o servidor de e-mail local..."
if [ -f "/var/webmail/docker-compose.yml" ]; then
    # Backup do arquivo original
    cp /var/webmail/docker-compose.yml /var/webmail/docker-compose.yml.bak
    
    # Atualizar configurações
    sed -i "s|ROUNDCUBEMAIL_SMTP_SERVER:.*|ROUNDCUBEMAIL_SMTP_SERVER: \"mailserver\"|" /var/webmail/docker-compose.yml
    sed -i "s|ROUNDCUBEMAIL_SMTP_PORT:.*|ROUNDCUBEMAIL_SMTP_PORT: \"587\"|" /var/webmail/docker-compose.yml
    sed -i "s|ROUNDCUBEMAIL_IMAP_HOST:.*|ROUNDCUBEMAIL_IMAP_HOST: \"mailserver\"|" /var/webmail/docker-compose.yml
    sed -i "s|ROUNDCUBEMAIL_IMAP_PORT:.*|ROUNDCUBEMAIL_IMAP_PORT: \"993\"|" /var/webmail/docker-compose.yml
    
    # Conectar à rede do mailserver
    docker network connect mailserver_network webmail 2>/dev/null || true
    docker network connect mailserver_network webmail-nginx 2>/dev/null || true
    
    # Reiniciar Roundcube
    cd /var/webmail && docker compose restart
    log_success "Roundcube configurado para usar servidor local"
else
    log_warn "Roundcube não encontrado, configure manualmente"
fi

# Salvar credenciais
CREDENTIALS_FILE="$MAIL_DIR/credentials.txt"
cat > "$CREDENTIALS_FILE" <<EOF
════════════════════════════════════════════════════════
  📧 CREDENCIAIS DO SERVIDOR DE E-MAIL
════════════════════════════════════════════════════════

INFORMAÇÕES DO SERVIDOR:
  Domínio: $MAIL_DOMAIN
  Hostname: $HOSTNAME
  IP: $(hostname -I | awk '{print $1}')

MYSQL (Database):
  Host: mail-mysql
  Database: postfix
  Usuário: postfix
  Senha: $POSTFIX_DB_PASSWORD
  Senha Root: $MYSQL_ROOT_PASSWORD

POSTFIXADMIN (Painel Web):
  URL Externa: http://$(hostname -I | awk '{print $1}'):8888
  URL via Proxy: https://mailadmin.$MAIL_DOMAIN
  
  Setup Password (primeira configuração):
  $POSTFIXADMIN_SETUP_PASSWORD

SERVIDORES SMTP/IMAP (para clientes):
  SMTP (envio): mail.$MAIL_DOMAIN
  Porta SMTP: 587 (STARTTLS)
  
  IMAP (recebimento): mail.$MAIL_DOMAIN
  Porta IMAP: 993 (SSL/TLS)
  
  Autenticação: usuário@$MAIL_DOMAIN + senha

ROUNDCUBE (Webmail):
  URL: https://webmail.$MAIL_DOMAIN
  Login: usuário@$MAIL_DOMAIN

════════════════════════════════════════════════════════
  ⚠️  IMPORTANTE - GUARDAR EM LOCAL SEGURO
════════════════════════════════════════════════════════
EOF

chmod 600 "$CREDENTIALS_FILE"

# Exibir resultados
clear
echo ""
echo "════════════════════════════════════════════════════════"
echo -e "${GREEN}  ✅ SERVIDOR DE E-MAIL INSTALADO COM SUCESSO!${NC}"
echo "════════════════════════════════════════════════════════"
echo ""
echo "📋 Credenciais salvas em: $CREDENTIALS_FILE"
echo ""
cat "$CREDENTIALS_FILE"
echo ""
echo "════════════════════════════════════════════════════════"
echo "  📌 PRÓXIMOS PASSOS"
echo "════════════════════════════════════════════════════════"
echo ""
echo "1. CONFIGURAR NGINX PROXY MANAGER:"
echo "   • Acesse: http://$(hostname -I | awk '{print $1}'):81"
echo "   • Crie Proxy Host para:"
echo "     - mailadmin.$MAIL_DOMAIN → http://postfixadmin:80"
echo "   • SSL com Let's Encrypt"
echo ""
echo "2. CONFIGURAR POSTFIXADMIN (primeira vez):"
echo "   • Acesse: https://mailadmin.$MAIL_DOMAIN/setup.php"
echo "   • Cole a Setup Password: $POSTFIXADMIN_SETUP_PASSWORD"
echo "   • Crie o primeiro admin"
echo ""
echo "3. CRIAR CONTAS DE E-MAIL:"
echo "   • Acesse: https://mailadmin.$MAIL_DOMAIN"
echo "   • Login com admin criado no passo 2"
echo "   • Domain List → Add Domain → $MAIL_DOMAIN"
echo "   • Virtual List → Add Mailbox"
echo ""
echo "4. CONFIGURAR DNS (se ainda não fez):"
echo "   mail.$MAIL_DOMAIN     A      $(hostname -I | awk '{print $1}')"
echo "   $MAIL_DOMAIN          MX 10  mail.$MAIL_DOMAIN"
echo "   $MAIL_DOMAIN          TXT    \"v=spf1 mx ~all\""
echo ""
echo "5. TESTAR E-MAIL:"
echo "   • Roundcube: https://webmail.$MAIL_DOMAIN"
echo "   • Outlook/Thunderbird:"
echo "     - IMAP: mail.$MAIL_DOMAIN:993 (SSL)"
echo "     - SMTP: mail.$MAIL_DOMAIN:587 (STARTTLS)"
echo ""
echo "6. GERAR CERTIFICADO SSL PARA MAIL SERVER:"
echo "   sudo certbot certonly --standalone -d mail.$MAIL_DOMAIN"
echo "   # Depois copie os certificados para o container"
echo ""
echo "════════════════════════════════════════════════════════"
echo ""
echo "📚 Documentação completa: MAILSERVER_SETUP.md"
echo ""
