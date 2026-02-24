#!/bin/bash

# =========================================================
# GUIA COMPLETO - Solução de Problemas SSL/Let's Encrypt
# =========================================================

clear

cat << 'EOF'
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║  🔐 GUIA COMPLETO - PROBLEMAS COM SSL/LET'S ENCRYPT       ║
║                                                            ║
║  Domínios que não conseguem certificado:                 ║
║  • webmail.daniloramos.dev.br → webmail-nginx            ║
║  • gospelibipitanga.com.br → wp-app-gospelibipitanga    ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝

EOF

cat << 'EOF'
═══════════════════════════════════════════════════════════════
🚀 SOLUÇÃO PASSO A PASSO
═══════════════════════════════════════════════════════════════

PASSO 1: Executar Teste Automático
────────────────────────────────────
Primeiro, verifique se tudo está ok para criar SSL:

  $ sudo bash scripts/test_ssl_readiness.sh

Este script vai verificar:
  ✓ Docker e Nginx Proxy Manager
  ✓ Resolução DNS dos domínios
  ✓ Conectividade HTTP
  ✓ Let's Encrypt acessível
  ✓ Espaço em disco


PASSO 2: Se o teste apontar problemas
───────────────────────────────────────
Use o troubleshooter interativo:

  $ sudo bash scripts/ssl_troubleshoot_interactive.sh

Este script vai ajudá-lo a diagnosticar e resolver:
  1. Problemas de DNS
  2. Firewall bloqueando portas
  3. Containers parados
  4. Permissões incorretas
  5. Limites de rate do Let's Encrypt


PASSO 3: Corrigir Problemas Específicos
────────────────────────────────────────
Se precisar executar correções automáticas:

  $ sudo bash scripts/fix_ssl_issues.sh

Opções disponíveis:
  1. Reiniciar Nginx Proxy Manager
  2. Limpar cache do Let's Encrypt
  3. Corrigir permissões
  4. Resetar certificados expirados
  5. Diagnóstico completo


PASSO 4: Diagnóstico Detalhado
────────────────────────────────
Se ainda não funcionar, gere um diagnóstico completo:

  $ sudo bash scripts/diagnose_ssl.sh

Este script monta um relatório com:
  • Status de todos os containers
  • Logs de erro do NPM
  • DNS configuration
  • Firewall rules
  • Diretórios de certificados
  • Permissões de arquivos

═══════════════════════════════════════════════════════════════
📋 CHECKLIST ANTES DE CRIAR SSL
═══════════════════════════════════════════════════════════════

Antes de tentar criar certificados, verifique:

□ DNS Configurado
  └─ Registro A para webmail.daniloramos.dev.br apontando para seu IP
  └─ Registro A para gospelibipitanga.com.br apontando para seu IP
  └─ Testar: dig webmail.daniloramos.dev.br +short

□ Firewall Desbloqueado
  └─ Porta 80 (HTTP) aberta
  └─ Porta 443 (HTTPS) aberta
  └─ Porta 81 (NPM Admin) aberta (apenas local)
  └─ Testar: curl -I http://webmail.daniloramos.dev.br

□ Docker Rodando
  └─ docker ps | grep nginx-proxy-manager
  └─ Se não constar: cd /var/proxy_manager && docker compose up -d

□ Espaço em Disco
  └─ df -h /var/proxy_manager
  └─ Deve ter pelo menos 1GB livre

□ Permissões OK
  └─ ls -la /var/proxy_manager/letsencrypt
  └─ Se tiver "Permission denied": sudo chown -R 1000:1000 /var/proxy_manager

═══════════════════════════════════════════════════════════════
🐛 ERROS COMUNS E SOLUÇÕES
═══════════════════════════════════════════════════════════════

❌ "Domain validation failed"
   └─ Causa: DNS não propagou ou firewall bloqueando porta 80
   └─ Solução:
      1. Verifique DNS: dig webmail.daniloramos.dev.br +short
      2. Aguarde 5-30 minutos pela propagação
      3. Teste porta 80: curl -I http://webmail.daniloramos.dev.br
      4. Se tudo ok, tente novamente no painel

❌ "Connection refused"
   └─ Causa: Nginx Proxy Manager não está rodando
   └─ Solução:
      cd /var/proxy_manager
      docker compose down
      docker compose up -d
      sleep 30
      # Tente novamente no painel

❌ "Rate limit exceeded"
   └─ Causa: Muito tentativas falhadas no Let's Encrypt
   └─ Solução:
      1. Aguarde 1 semana para tentar novamente
      2. Ou use certificado self-signed temporário
      3. Ou use Let's Encrypt Staging (não válido, apenas para teste)

❌ "Permission denied"
   └─ Causa: /var/proxy_manager tem problemas de permissão
   └─ Solução:
      sudo chown -R 1000:1000 /var/proxy_manager
      sudo chmod -R 755 /var/proxy_manager
      sudo chmod -R 700 /var/proxy_manager/letsencrypt
      cd /var/proxy_manager && docker compose restart

❌ Timeout / Sem Resposta
   └─ Causa: Let's Encrypt muito lento ou container lento
   └─ Solução:
      1. Reinicie NPM: cd /var/proxy_manager && docker compose restart
      2. Aguarde 2 minutos
      3. Tente novamente
      4. Se persistir, aumentar memória/CPU do container

❌ SSL criado mas navegador mostra erro
   └─ Causa: Certificado inválido ou domínio não aponta para servidor
   └─ Solução:
      1. Verifique DNS novamente: dig webmail.daniloramos.dev.br
      2. Aguarde propagação DNS completa
      3. Limpe cache do navegador (Ctrl+Shift+Del)
      4. Tente em outro navegador/computador

═══════════════════════════════════════════════════════════════
🔧 COMO CRIAR SSL MANUALMENTE NO PAINEL
═══════════════════════════════════════════════════════════════

Se os scripts não funcionarem, faça manualmente:

1. Acesse http://SEU_IP:81
2. Login: admin@example.com / changeme (padrão)
3. Vá em "Hosts" → "Proxy Hosts"
4. Clique no domínio que precisa de SSL
5. Vá na aba "SSL"
6. Escolha "Request a new SSL Certificate"
7. Preencha:
   - Email: seu@email.com
   - ☑ I Agree to the Let's Encrypt Terms of Service
8. Clique "Save"
9. Aguarde (pode levar 30-60 segundos)
10. Se sucesso, as opções "Force SSL" aparecem ativas

═══════════════════════════════════════════════════════════════
📞 COMO REPORTAR PROBLEMA
═══════════════════════════════════════════════════════════════

Se nada funcionar, reporte com:

1. Gere diagnóstico:
   $ sudo bash scripts/diagnose_ssl.sh > /tmp/ssl_report.txt

2. Salve logs:
   $ docker logs nginx-proxy-manager > /tmp/npm_logs.txt

3. Verifique DNS:
   $ dig webmail.daniloramos.dev.br | tee /tmp/dns_report.txt
   $ dig gospelibipitanga.com.br | tee /tmp/dns_report2.txt

4. Compartilhe os arquivos:
   /tmp/ssl_report.txt
   /tmp/npm_logs.txt
   /tmp/dns_report.txt
   /tmp/dns_report2.txt

===================================================================

EOF

read -p "Pressione ENTER para continuar..."

echo ""
echo "✓ Escolha um passo acima:"
echo ""
echo "  1. Executar teste automático"
echo "  2. Usar troubleshooter interativo"
echo "  3. Executar correção automática"
echo "  4. Ver diagnóstico detalhado"
echo "  5. Sair"
echo ""

read -p "Digite (1-5): " choice

case $choice in
    1) sudo bash "$(dirname "$0")/test_ssl_readiness.sh" ;;
    2) sudo bash "$(dirname "$0")/ssl_troubleshoot_interactive.sh" ;;
    3) sudo bash "$(dirname "$0")/fix_ssl_issues.sh" ;;
    4) sudo bash "$(dirname "$0")/diagnose_ssl.sh" ;;
    5) exit 0 ;;
    *) echo "Opção inválida" ;;
esac
