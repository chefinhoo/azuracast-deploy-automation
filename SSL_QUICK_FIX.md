# 🔐 SSL QUICK FIX - Guia Rápido

Para seus domínios:
- ✗ webmail.daniloramos.dev.br (webmail-nginx)
- ✗ gospelibipitanga.com.br (wp-app-gospelibipitanga)

---

## ⚡ SOLUÇÃO RÁPIDA (Execute AGORA)

```bash
# 1. Abrir menu de SSL (RECOMENDADO)
sudo bash scripts/ssl_resolver.sh
```

Este menu vai:
- ✓ Testar se tudo está pronto
- ✓ Identificar o problema
- ✓ Sugerir correção
- ✓ Executar solução automática

---

## 🔧 Alternativas por Problema

### Se der erro "Domain validation failed"
```bash
# 1. Verifique DNS
dig webmail.daniloramos.dev.br +short
dig gospelibipitanga.com.br +short

# Deve retornar seu IP público. Se não retornar:
# → DNS não está configurado
# → Aguarde 5-30 minutos pela propagação
# → Depois tente novamente
```

### Se der erro "Connection refused"
```bash
# 1. Reiniciar proxy
cd /var/proxy_manager
docker compose down
docker compose up -d
sleep 30

# 2. Tente novamente no painel
```

### Se der erro de permissão
```bash
# Corrigir permissões
sudo chown -R 1000:1000 /var/proxy_manager
sudo chmod -R 755 /var/proxy_manager

# Reiniciar
cd /var/proxy_manager && docker compose restart
sleep 30
```

### Se der "Rate limit exceeded"
```bash
# Let's Encrypt bloqueou por muitas tentativas
# Solução: Aguarde 1 semana ou use certificado staging
# Não há como corrigir agora
```

---

## 📋 CHECKLIST

Antes de criar SSL, verifique TODOS esses pontos:

```bash
# 1. DNS configurado?
dig webmail.daniloramos.dev.br +short
# Deve retornar seu IP público

# 2. Porta 80 acessível?
curl -I http://webmail.daniloramos.dev.br
# Deve retornar "HTTP/1.1 301" ou "HTTP/1.1 200"

# 3. NPM rodando?
docker ps | grep nginx-proxy-manager
# Deve mostrar o container

# 4. Espaço em disco?
df -h /var/proxy_manager
# Deve ter pelo menos 1GB livre
```

Se todos retornarem OK → Você pode criar SSL no painel!

---

## 📱 CRIAR SSL NO PAINEL

1. Acesse: `http://SEU_IP:81`
2. Login: `admin@example.com` / `changeme`
3. Procure: **Proxy Hosts**
4. Encontre seu domínio (webmail.daniloramos.dev.br ou gospelibipitanga.com.br)
5. Clique **no domínio** → Aba **SSL**
6. Escolha: **Request a new SSL Certificate**
7. Preencha:
   - Email: seu@email.com (importante!)
   - ☑ Agree to Terms
8. Clique **Save**
9. ⏳ Aguarde 30-60 segundos...
10. ✓ Pronto!

Se der erro novamente, volte a este guia e use o `ssl_resolver.sh`

---

## 🚨 EMERGÊNCIA

Se nada funcionar:

```bash
# 1. Gere relatório de diagnóstico
sudo bash scripts/diagnose_ssl.sh > /tmp/report.txt

# 2. Limpe cache
sudo bash scripts/fix_ssl_issues.sh
# Escolha opção 2: "Limpar cache e logs"

# 3. Tente novamente
# Se ainda não funcionar, compartilhe o arquivo /tmp/report.txt
```

---

**Precisa de ajuda mais detalhada?**
Leia: [SSL_TROUBLESHOOTING.md](SSL_TROUBLESHOOTING.md)
