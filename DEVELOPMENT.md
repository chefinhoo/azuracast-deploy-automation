# Guia de Desenvolvimento

Este documento descreve como estender e personalizar os scripts de automação.

## 🏗️ Arquitetura

### Fluxo de Dependências

```
install.sh (ou uninstall.sh)
    ↓
    ├── sources → scripts/lib/common.sh
    │
    ├── Carrega → .deploy-config (opcional)
    │
    └── Executa → Funções específicas
        ├── install_docker()
        ├── setup_nginx_proxy_manager()
        ├── setup_azuracast()
        ├── apply_azuracast_network_hardening()
        ├── setup_static_site()
        └── create_vhost()
```

## 📝 Adicionando Novas Funções à Biblioteca

### Estrutura Base

```bash
# Comentário descrevendo a função
# Padrão: Retorna 0 em sucesso, 1 em erro
function_name() {
    local param1="$1"  # Primeiro parâmetro
    
    # Validar entrada
    if [ -z "$param1" ]; then
        log_error "Parâmetro obrigatório não fornecido"
        return 1
    fi
    
    # Executar lógica
    log_info "Processando..."
    
    # Verificar sucesso
    if ! some_command "$param1"; then
        log_error "Falha ao processar"
        return 1
    fi
    
    # Sucesso
    log_success "Operação concluída"
    return 0
}
```

### Exemplo: Adicionar Função de Backup

```bash
# Em scripts/lib/common.sh, adicione:

# ==========================================================
# BACKUP E RESTORE
# ==========================================================

# Criar backup de diretório
backup_directory() {
    local source_dir="$1"
    local backup_dir="${2:-/var/backups/azuracast}"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    
    log_info "Criando backup de: $source_dir"
    
    mkdir -p "$backup_dir" || {
        log_error "Falha ao criar diretório de backup"
        return 1
    }
    
    if ! tar -czf "${backup_dir}/backup_${timestamp}.tar.gz" \
         --exclude='*.log' \
         "$source_dir" 2>/dev/null; then
        log_error "Falha ao criar arquivo de backup"
        return 1
    fi
    
    log_success "Backup criado: ${backup_dir}/backup_${timestamp}.tar.gz"
    return 0
}
```

### Então use em install.sh:

```bash
# Antes de atualizar
backup_directory "$AZURACAST_DIR" || {
    log_warn "Falha no backup, continuando..."
}
```

## 🔌 Adicionando Configurações Customizadas

### 1. Definir em .deploy-config:

```bash
# Novo serviço
ENABLE_CUSTOM_SERVICE=1
CUSTOM_SERVICE_PORT=9000
CUSTOM_SERVICE_VERSION="latest"
```

### 2. Carregar em install.sh:

```bash
# Já feito automaticamente via load_config()
# Variáveis ficarão disponíveis após chamar load_config
```

### 3. Usar na função:

```bash
setup_custom_service() {
    if [ "${ENABLE_CUSTOM_SERVICE:-0}" = "0" ]; then
        log_info "Custom service desabilitado, pulando..."
        return 0
    fi
    
    log_info "Instalando custom service versão: $CUSTOM_SERVICE_VERSION"
    # ... resto da lógica
}
```

## 🧪 Testando Suas Mudanças

### 1. Verificar Sintaxe

```bash
bash -n scripts/install.sh
bash -n scripts/lib/common.sh
```

### 2. Executar com Verbose

```bash
VERBOSE_LOGGING=1 sudo bash scripts/install.sh
```

### 3. Teste Seco (dry-run)

```bash
# Para uninstall.sh já existe
sudo bash scripts/uninstall.sh --dry-run
```

## 📦 Integrar Nova Função no Fluxo Principal

### No arquivo install.sh:

```bash
main() {
    # ... validações iniciais ...
    
    # Sua nova função
    setup_custom_service || { log_error "Setup custom failed"; exit 1; }
    
    # ... resto do setup ...
}
```

## 🎯 Boas Práticas

### ✅ Faça:

1. **Use logging apropriado**
   ```bash
   log_info "Iniciando..."
   log_success "Concluído!"
   log_error "Falha!"
   ```

2. **Retorne status correto**
   ```bash
   if ! comando; then
       return 1  # Erro
   fi
   return 0      # Sucesso
   ```

3. **Valide entrada**
   ```bash
   local param="$1"
   if [ -z "$param" ]; then
       log_error "Parâmetro obrigatório"
       return 1
   fi
   ```

4. **Use variáveis locais**
   ```bash
   local var="valor"  # Não polui escopo global
   ```

5. **Documente suas funções**
   ```bash
   # Descrição clara
   # Argumentos: param1 - descrição
   # Retorna: 0 sucesso, 1 erro
   function_name() {
       ...
   }
   ```

### ❌ Não Faça:

1. **Use `echo` para logs**
   ```bash
   echo "algo"  # ❌ Não - use log_info
   ```

2. **Ignore erros**
   ```bash
   comando  # ❌ Não - sempre verifique
   if ! comando; then ...  # ✅ Sim
   ```

3. **Variáveis globais desnecessárias**
   ```bash
   GLOBAL_VAR="x"  # ❌ Ruim
   local var="x"   # ✅ Bom
   ```

4. **Caminhos hardcoded**
   ```bash
   /var/app  # ❌ Use variável configurável
   "$APP_DIR"  # ✅ Bom
   ```

## 🔄 Versionamento

Ao fazer mudanças significativas:

1. Atualize `REFACTORING.md`
2. Documente breaking changes
3. Aumente versão em comments

```bash
# Versão 2.0 - Refatoração com biblioteca
#
# Breaking Changes:
# - Reorganizou estrutura de diretórios
# - Novo arquivo de configuração obrigatório
```

## 📤 Compartilhando Extensões

Se desenvolveu uma extensão útil:

1. Fork o repositório
2. Crie branch: `feature/sua-extensao`
3. Adicione testes (bash simples)
4. Faça PR com documentação

## 🚀 Próximos Passos Sugeridos

1. **Adicionar snapshots**: Backup antes de alterações
2. **Monitoramento**: Health checks periódicos
3. **Auto-update**: Verificar atualizações de componentes
4. **Multi-domain**: Suportar múltiplos domínios/estações
5. **Métricas**: Coletar dados de performance
6. **Restore**: Restaurar de backups automáticos

---

**Dúvidas?** Veja `scripts/lib/common.sh` para mais exemplos
