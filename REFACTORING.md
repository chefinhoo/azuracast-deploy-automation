# Refatoração do Script de Instalação

Este documento descreve as melhorias implementadas na refatoração dos scripts de automação do AzuraCast Deploy.

## 📋 Resumo das Mudanças

### Estrutura Modular
- **Biblioteca Comum**: Novo arquivo `scripts/lib/common.sh` contendo funções reutilizáveis
- **Separação de Responsabilidades**: Funções específicas organizadas por categoria
- **Reutilização de Código**: Eliminação de duplicação entre `install.sh` e `uninstall.sh`

### Melhorias de Segurança
- ✅ Validação robusta de entrada (domínios, portas)
- ✅ Verificação de privilégios no início
- ✅ Tratamento adequado de erros em cada etapa
- ✅ Health checks para containers antes de considerar sucesso
- ✅ Hardening opcional de rede via `DOCKER-USER` para bloquear acesso direto por IP às portas do AzuraCast

### Logging Aprimorado
- **Logging com Timestamp**: Todos os eventos incluem horário
- **Múltiplos Níveis**: INFO, SUCCESS, WARN, ERROR, DEBUG
- **Arquivo de Log**: Registro persistente em `/var/log/azuracast-deploy.log`
- **Modo Verbose**: Suporte a `VERBOSE_LOGGING=1` para debug detalhado

### Configuração Flexível
- **Arquivo `.deploy-config`**: Personalize portas, diretórios e comportamento
- **Valores Padrão**: Funciona sem configuração para caso padrão
- **Variáveis de Ambiente**: Suporte para override via `.deploy-config.example`
- **Bloqueio de IP configurável**: `BLOCK_DIRECT_AZURACAST_ACCESS` e `FIREWALL_INTERFACE`

### Melhorias na Validação
- ✅ Verifica distribuição (Ubuntu/Debian apenas)
- ✅ Valida conectividade de rede
- ✅ Verifica disponibilidade de portas
- ✅ Valida formato de domínios
- ✅ Health checks de containers com timeout

## 📁 Estrutura de Arquivos

```
scripts/
├── install.sh              # Script principal de instalação (refatorado)
├── uninstall.sh            # Script de desinstalação
└── lib/
    └── common.sh           # Biblioteca de funções comuns

.deploy-config.example      # Exemplo de configuração
```

## 🔧 Usando o Script

### Instalação Padrão
```bash
sudo bash scripts/install.sh
```

### Com Configuração Customizada
```bash
# 1. Copiar arquivo de exemplo
cp .deploy-config.example .deploy-config

# 2. Editar conforme necessário
nano .deploy-config

# 3. Executar instalação
sudo bash scripts/install.sh
```

### Modo Verbose
```bash
# Editar .deploy-config com:
VERBOSE_LOGGING=1

# Ou via variável de ambiente:
VERBOSE_LOGGING=1 sudo bash scripts/install.sh
```

## 📝 Configurações Disponíveis

Veja [.deploy-config.example](.deploy-config.example) para lista completa.

### Principais Configurações:

```bash
# Diretórios
PROXY_MANAGER_DIR="/var/proxy_manager"
AZURACAST_DIR="/var/azuracast"
WEB_ROOT="/var/www"

# Portas NPM
NPM_ADMIN_PORT=81
NPM_HTTP_PORT=80
NPM_HTTPS_PORT=443

# Portas AzuraCast
AZURACAST_HTTP_PORT=8080
AZURACAST_HTTPS_PORT=8043
AZURACAST_STATION_PORT_START=9000
AZURACAST_STATION_PORT_END=9999

# Comportamento
PROMPT_FOR_DOMAIN=1
VERBOSE_LOGGING=0
FORCE_FRESH_INSTALL=0

# Segurança de rede
BLOCK_DIRECT_AZURACAST_ACCESS=1
FIREWALL_INTERFACE=""
```

## 🧪 Funções da Biblioteca Comum

### Logging
- `log_info()` - Mensagem informativa (azul)
- `log_success()` - Sucesso (verde)
- `log_warn()` - Aviso (amarelo)
- `log_error()` - Erro (vermelho)
- `log_debug()` - Debug (apenas com VERBOSE_LOGGING=1)

### Validação
- `check_root()` - Verifica privilégios
- `check_distribution()` - Valida Ubuntu/Debian
- `check_connectivity()` - Testa conexão de rede
- `check_port_available()` - Verifica disponibilidade de porta
- `validate_domain()` - Valida formato de domínio

### Docker
- `docker_installed()` - Verifica instalação
- `docker_version()` - Retorna versão
- `wait_container_healthy()` - Aguarda container saudável
- `remove_container()` - Remove container

### Entrada/Saída
- `prompt_confirm()` - Solicita confirmação
- `prompt_domain()` - Solicita e valida domínio
- `prompt_input()` - Entrada customizada com regex
- `print_section()` - Título formatado
- `print_info_box()` - Caixa de informação
- `print_separator()` - Separador visual

### Sistema
- `get_public_ip()` - Obtém IP público
- `cleanup_cache()` - Limpa cache apt
- `command_exists()` - Verifica comando disponível

## 📊 Fluxo de Instalação

```
main()
├── init_logging()           → Inicializa arquivo de log
├── load_config()            → Carrega .deploy-config
├── check_root()             → Valida privilégios root
├── check_distribution()     → Valida Ubuntu/Debian
├── check_connectivity()     → Testa conexão
├── install_docker()         → Instala Docker
├── setup_nginx_proxy_manager() → NPM + MariaDB
├── setup_azuracast()        → AzuraCast
├── apply_azuracast_network_hardening() → Bloqueia acesso direto por IP (opcional)
├── setup_static_site()      → Prepara ambiente WordPress
├── create_vhost()           → Provisiona stack WordPress para o domínio (opcional)
└── display_summary()        → Exibe informações finais
```

## 🔒 Segurança

### Melhorias Implementadas
- Validação de entrada em todos os prompts
- Verificação de privilégios antes de qualquer operação
- Health checks de containers
- Tratamento de erros com rollback adequado
- Logs persistentes para auditoria
- Timeout em operações de rede

## 📋 Logs

Os logs são salvos em `/var/log/azuracast-deploy.log` com:
- ✅ Timestamp de cada operação
- ✅ Nível de severidade
- ✅ Mensagem descritiva
- ✅ Histórico completo

Visualize os logs:
```bash
tail -f /var/log/azuracast-deploy.log
```

## 🐛 Troubleshooting

### Erro: "Biblioteca comum não encontrada"
```bash
# Certifique-se que la

 está em:
ls -la scripts/lib/common.sh
```

### Erro: "Docker não está instalado"
```bash
# Execute apenas a função de instalação:
VERBOSE_LOGGING=1 sudo bash scripts/install.sh
```

### Container não fica saudável
```bash
# Verificar logs do container:
docker logs nginx-proxy-manager
docker logs azuracast-web-1
```

## 📚 Referências

- [Docker Documentation](https://docs.docker.com/)
- [AzuraCast GitHub](https://github.com/AzuraCast/AzuraCast)
- [Nginx Proxy Manager](https://nginxproxymanager.com)

## 📄 Licença

MIT License (apenas o script de automação)

## 👤 Autor

Danilo Ramos - 2026

---

**Última atualização**: Fevereiro 2026
