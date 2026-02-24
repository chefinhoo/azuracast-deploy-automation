# 🔐 RESUMO - Solução para Problemas com SSL

## 📌 SUA SITUAÇÃO ATUAL

```
❌ webmail.daniloramos.dev.br  → container: webmail-nginx
   (Não consegue criar certificado SSL)

❌ gospelibipitanga.com.br     → container: wp-app-gospelibipitanga-com-br
   (Não consegue criar certificado SSL)
```

---

## ⚡ O QUE FAZER AGORA (IMEDIATAMENTE)

### OPÇÃO 1: Solução Automática (RECOMENDADO)

```bash
sudo bash scripts/ssl_resolver.sh
```

**Isso vai:**
1. ✓ Testarprontidão do sistema
2. ✓ Identificar o problema
3. ✓ Sugerir solução
4. ✓ Executar correção

**Tempo:** ~2 minutos

---

### OPÇÃO 2: Se preferir etapas individuais

**Passo 1 - Testar Prontidão:**
```bash
sudo bash scripts/test_ssl_readiness.sh
```

**Passo 2 - Se tiver problemas:**
```bash
sudo bash scripts/ssl_troubleshoot_interactive.sh
```

**Passo 3 - Executar correção:**
```bash
sudo bash scripts/fix_ssl_issues.sh
```

---

## 🐛 ERROS MAIS COMUNS E SOLUÇÕES

| Erro | Solução |
|------|---------|
| `Domain validation failed` | DNS não propagou. Aguarde 5-30 min e tente novamente |
| `Connection refused` | `cd /var/proxy_manager && docker compose restart` |
| `Rate limit exceeded` | Aguarde 1 semana. Muito tentativas falhadas |
| `Permission denied` | `sudo chown -R 1000:1000 /var/proxy_manager` |
| Timeout / Sem resposta | Reinicie NPM e aguarde 2 minutos |

---

## 📚 DOCUMENTOS DISPONÍVEIS

| Arquivo | Descrição |
|---------|-----------|
| [SSL_QUICK_FIX.md](SSL_QUICK_FIX.md) | Guia rápido com soluções |
| [SSL_TROUBLESHOOTING.md](SSL_TROUBLESHOOTING.md) | Guia completo e detalhado |
| [README.md](README.md) | Documentação principal (seção "Solução de Problemas") |
| [TROUBLESHOOTING_PROXY.md](TROUBLESHOOTING_PROXY.md) | Problemas de proxy (conexão) |

---

## 🎯 PRÓXIMAS ETAPAS

1. **Execut e o script de diagnóstico:**
   ```bash
   sudo bash scripts/ssl_resolver.sh
   ```

2. **Siga as instruções na tela** - menu é interativo

3. **Se precisar, use um dos guias acima** para entender melhor

4. **Tente criar SSL no painel do NPM:**
   - Acesso: http://SEU_IP:81
   - Proxy Hosts → seu domínio → SSL → Request Certificate

---

## ✅ CHECKLIST ANTES DE DESISTIR

- [ ] DNS está propagado? (`dig seu_dominio.com.br +short`)
- [ ] Porta 80 aberta? (`curl -I http://seu_dominio.com.br`)
- [ ] NPM rodando? (`docker ps | grep nginx-proxy-manager`)
- [ ] Espaço em disco? (`df -h /var/proxy_manager`)
- [ ] Executou o teste automático? (`sudo bash scripts/test_ssl_readiness.sh`)

Se TODOS os itens acima forem OK, você consegue criar SSL!

---

**Dúvidas?** Revise: [SSL_TROUBLESHOOTING.md](SSL_TROUBLESHOOTING.md)
