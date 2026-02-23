# Configuração do Roundcube Webmail

## Visão Geral

O Roundcube é um webmail em PHP que permite acessar seus emails via navegador. Este guia mostra como configurar o SMTP e IMAP após a instalação.

## Arquivos Principais

- **Docker Compose**: `/var/webmail/docker-compose.yml`
- **Nginx Config**: `/var/webmail/nginx.conf`
- **Mariadb Database**: `/var/webmail/mariadb` (volume Docker)

## Configuração Básica

### 1. Editar Variáveis de Ambiente

O arquivo `/var/webmail/docker-compose.yml` contém as variáveis SMTP e IMAP. Você precisa atualizar:

```yaml
environment:
  SMTP_SERVER: "seu-servidor-smtp.com"
  SMTP_PORT: "587"
  IMAP_HOST: "seu-servidor-imap.com"
  IMAP_PORT: "993"
  MAIL_FROM: "seu-email@dominio.com.br"
```

### 2. Proveedores de Email Populares

#### Gmail (SMTP)
```yaml
SMTP_SERVER: "smtp.gmail.com"
SMTP_PORT: "587"
IMAP_HOST: "imap.gmail.com"
IMAP_PORT: "993"
SMTP_AUTH: "1"
IMAP_AUTH: "1"
```

**IMPORTANTE**: Gmail requer "Senhas de aplicativo". [Gerar aqui](https://myaccount.google.com/apppasswords)

#### Zoho Mail
```yaml
SMTP_SERVER: "smtp.zoho.com.br"
SMTP_PORT: "587"
IMAP_HOST: "imap.zoho.com.br"
IMAP_PORT: "993"
```

#### Custom (seu próprio servidor)
```yaml
SMTP_SERVER: "smtp.seu-dominio.com.br"
SMTP_PORT: "587"
IMAP_HOST: "mail.seu-dominio.com.br"
IMAP_PORT: "993"
SMTP_AUTH: "1"
IMAP_AUTH: "1"
SMTP_USER: "seu-usuario"
IMAP_USER: "seu-usuario"
```

### 3. Aplicar Configuração

```bash
cd /var/webmail

# Editar o docker-compose.yml
nano docker-compose.yml

# Reiniciar o Roundcube
docker compose restart roundcube
```

### 4. Verificar Logs

```bash
# Ver logs da aplicação
cd /var/webmail && docker compose logs roundcube

# Ver logs do Nginx
docker compose logs webmail-nginx
```

## Acesso Inicial

1. **URL**: https://webmail.seu-dominio.com.br (via Nginx Proxy Manager)
2. **Usuário**: Admin padrão criado no banco de dados
3. **Senha**: Configurada no `docker-compose.yml` (MYSQL_ROOT_PASSWORD)

### Criar Usuários Adicionais (via SSH)

```bash
cd /var/webmail

# Acessar banco de dados
docker compose exec roundcube-db mariadb -u root -p

# Dentro do MariaDB:
USE roundcube;
INSERT INTO users (username, mail_host, created, last_login) 
VALUES ('usuario@seu-dominio.com.br', 'mail.seu-dominio.com.br', NOW(), NOW());
```

## Troubleshooting

### "Falha ao conectar ao servidor IMAP"

Possíveis causas:
- Host/porta IMAP incorretos
- Credenciais erradas
- Firewall bloqueando porta 993/143
- Certificado SSL inválido (IMAP_SSL deve ser true ou verificação desabilitada)

Solução:
```bash
# Testar conexão IMAP
telnet mail.seu-dominio.com.br 993

# Ou com openssl
openssl s_client -connect mail.seu-dominio.com.br:993
```

### "Falha ao enviar email"

Possíveis causas:
- Host/porta SMTP incorretos
- Autenticação SMTP desabilitada
- Firewall bloqueando porta 587

Solução:
```bash
# Testar conexão SMTP
telnet seu-servidor-smtp.com 587
```

### "Roundcube não inicia"

```bash
cd /var/webmail

# Ver erro completo
docker compose logs roundcube

# Rebuild se necessário
docker compose down
docker compose up -d --build
```

## Variáveis de Ambiente Completas

```yaml
# IMAP
IMAP_HOST=imap.seu-servidor.com.br
IMAP_PORT=993
IMAP_AUTH=login        # login, plain, cram-md5, digest-md5
IMAP_SECURITY=ssl      # ssl, tls, none

# SMTP  
SMTP_SERVER=smtp.seu-servidor.com.br
SMTP_PORT=587
SMTP_AUTH=login        # login, plain, cram-md5, digest-md5
SMTP_SECURITY=tls      # tls, ssl, none

# Identidade do Email
MAIL_FROM=seu-email@seu-dominio.com.br
MAIL_FROM_NAME="Seu Nome"

# Banco de Dados
MYSQL_ROOT_PASSWORD=senha-forte-aqui
MYSQL_DATABASE=roundcube
```

## Performance

Para melhor performance em produção:

1. **Aumentar memória do container**:
```yaml
roundcube:
  mem_limit: 512m
  memswap_limit: 512m
```

2. **Usar cache Redis** (adicionar ao docker-compose.yml):
```yaml
redis:
  image: redis:7-alpine
  ports:
    - "6379:6379"

roundcube:
  depends_on:
    - redis
  environment:
    REDIS_HOST: redis
```

3. **Configurar timeout IMAP** (em /var/webmail/docker-compose.yml):
```yaml
environment:
  IMAP_TIMEOUT=0
  SESSIONPATH=/tmp
```

## Backup

```bash
cd /var/webmail

# Backup banco de dados
docker compose exec roundcube-db mysqldump -u root -p roundcube > roundcube-backup.sql

# Backup completo
tar -czf webmail_backup.tar.gz mariadb/ config/

# Restaurar
tar -xzf webmail_backup.tar.gz
docker compose up -d --build
```

## Segurança

- ✅ Sempre usar HTTPS (configurar no Nginx Proxy Manager)
- ✅ Trocar senha padrão do MariaDB
- ✅ Limitar acesso ao MariaDB apenas para Roundcube
- ✅ Usar senhas de app no Gmail/Office 365 (não senha real)
- ✅ Manter Roundcube atualizado
- ✅ Usar certificados SSL válidos

## Atualizar Roundcube

```bash
cd /var/webmail

# Atualizar imagem
docker compose pull roundcube

# Reiniciar
docker compose up -d --build

# Backup antes de atualizar!
```

## Suporte

- [Documentação Roundcube](https://roundcube.net/about/documentation/)
- [GitHub Roundcube](https://github.com/roundcube/roundcubemail)
- Logs: `docker compose logs roundcube`
