# Configuração do Filebrowser

## Visão Geral

O Filebrowser é um gerenciador de arquivos web que permite acessar, fazer upload e download de arquivos via navegador. Nesta instalação, ele tem acesso aos arquivos do WordPress e do AzuraCast.

## Arquivos Principais

- **Docker Compose**: `/var/filemanager/docker-compose.yml`
- **Configuração**: `/var/filemanager/settings.json`
- **Banco de dados**: `/var/filemanager/database.db` (SQLite)
- **Volumes acessíveis**: 
  - `/var/www` - Arquivos do WordPress
  - `/var/azuracast` - Arquivos do AzuraCast

## Acesso Inicial

1. **URL**: https://files.seu-dominio.com.br (via Nginx Proxy Manager)
2. **Usuário padrão**: `admin`
3. **Senha padrão**: `password`

### ⚠️ IMPORTANTE: Alterar Senha Padrão

Logo na primeira vez que acessar, **MUDE A SENHA DO ADMIN**:

1. Acessar https://files.seu-dominio.com.br
2. Login com `admin` / `password`
3. Clicar em "Settings" (engrenagem) no canto superior direito
4. Ir para a aba "Users"
5. Clicar em "admin"
6. Mudar a senha em "Change Password"
7. Salvar

## Estrutura de Pastas

```
/var/www/
├── seudominio.com.br/  (WordPress do dominio 1)
│   ├── wp-content/
│   ├── wp-admin/
│   └── index.php
├── outrominio.com.br/  (WordPress do dominio 2)
└── ...

/var/azuracast/
├── storage/
├── stations/
├── web/
└── ...
```

## Gerenciar Usuários via Interface

1. Login como admin
2. Clicar em "Settings" (engrenagem)
3. Aba "Users"
4. Opções disponíveis:
   - **New User**: Criar novo usuário
   - **Edit**: Modificar permissões e pasta raiz
   - **Delete**: Remover usuário

## Gerenciar Usuários via CLI

```bash
cd /var/filemanager

# Acessar container Filebrowser
docker compose exec filemanager filebrowser hash sha256 -p "sua-nova-senha"

# Editar usuário via CLI
docker compose exec filemanager filebrowser users update admin -p "nova-senha"
```

## Permissões de Pasta

Cada usuário pode ter uma pasta raiz diferente (sandbox):

**Via Interface:**
1. Settings → Users → Selecionar usuário
2. Alterar "Scope" (pasta visível)
3. Exemplos:
   - `/var/www/seudominio.com.br` - Apenas um site
   - `/var/www` - Todos os WordPress
   - `/var/azuracast` - Apenas AzuraCast
   - `/` - Sistema inteiro (ser cautela)

**Via CLI:**
```bash
cd /var/filemanager

# Ver usuários
docker compose exec filemanager filebrowser users list

# Criar novo usuário
docker compose exec filemanager filebrowser users add usuario senha

# Definir pasta raiz (scope)
docker compose exec filemanager filebrowser users update usuario -scope /var/www

# Remover usuário
docker compose exec filemanager filebrowser users delete usuario
```

## Configuração Avançada

### Editar settings.json

```bash
nano /var/filemanager/settings.json
```

Opções principais:

```json
{
  "port": 80,
  "baseURL": "/",
  "logfilename": "/data/filebrowser.log",
  "database": "/data/database.db",
  "root": "/srv",
  "auth": {
    "method": "json",
    "header": ""
  },
  "shell": ["/bin/bash", "-c"],
  "commands": {
    "copy": "cp -r {src} {dst}",
    "move": "mv {src} {dst}",
    "remove": "rm -rf {path}",
    "rename": "mv {old} {new}",
    "mkdir": "mkdir -p {path}",
    "archive": "cd {src} && tar -czf {dst} *",
    "extract": "cd {dst} && tar -xzf {archive}",
    "compress": "cd {src} && tar -czf {dst} {files}"
  },
  "signup": false,
  "allowCommands": true,
  "allowEdit": true,
  "allowNew": true,
  "allowPublish": false,
  "allowShell": false,
  "enforceClean": true,
  "instanceURL": ""
}
```

### Desabilitar/Ativar Funcionalidades

```bash
cd /var/filemanager

# Desabilitar criação de novos arquivos
docker compose exec filemanager filebrowser config set -disable-create

# Desabilitar edição de arquivos
docker compose exec filemanager filebrowser config set -disable-rename

# Permitir acesso shell
docker compose exec filemanager filebrowser config set -allow-shell

# Desativar após config
docker compose restart filemanager
```

## Casos de Uso Comuns

### Editar Arquivo de Configuração do WordPress

1. Acessar https://files.seu-dominio.com.br
2. Navegar até `/var/www/seudominio.com.br/wp-config.php`
3. Clicar no arquivo
4. Clicar em "Edit"
5. Fazer alterações
6. Salvar

### Fazer Upload de Plugin WordPress

1. Acessar `/var/www/seudominio.com.br/wp-content/plugins/`
2. Botão "Upload"
3. Selecionar arquivo .zip do plugin
4. Fazer upload
5. No WordPress, ativar o plugin

### Fazer Backup de Arquivos

1. Selecionar pasta (`/var/www/seudominio.com.br`)
2. Clicar em "Download"
3. Navegador baixará como ZIP

### Restaurar Arquivo Apagado

Se tiver backup:
1. Upload do arquivo via Filebrowser
2. Ou restaurar container Docker com backup anterior

```bash
cd /var/filemanager

# Listar backups existentes
ls -la ../filemanager_backups/

# Restaurar de backup
tar -xzf ../filemanager_backups/filemanager_20240115.tar.gz -C /var/filemanager
docker compose up -d --build
```

## Troubleshooting

### "Permissão negada" ao editar arquivo

Causa: Container Filebrowser não tem permissão de escrita na pasta

Solução:
```bash
# Verificar permissões
ls -l /var/www/seu-arquivo

# Ajustar permissões (se necessário)
sudo chmod 644 /var/www/seu-arquivo
sudo chown 33:33 /var/www/seu-arquivo  # www-data (Apache)

# Ou no Filebrowser, fazer download + reupload
```

### "Conexão recusada" ao acessar

Causas possíveis:
- Nginx Proxy Manager não está configurado
- Filebrowser container não iniciou
- Porta 80 está bloqueada

Solução:
```bash
cd /var/filemanager

# Verificar status
docker compose ps

# Ver logs
docker compose logs filemanager

# Reiniciar
docker compose down
docker compose up -d --build
```

### Arquivo aparece mas não consegue baixar

Causa: Arquivo muito grande ou timeout de conexão

Solução:
1. Aumentar timeout no Nginx Proxy Manager
2. Ou fazer upload em SSH:
```bash
scp arquivo.zip seu-usuario@seu-ip:/var/www/seudominio.com.br/
```

### Login não funciona

Solução:
```bash
cd /var/filemanager

# Resetar banco de dados
rm database.db

# Reiniciar (recria db padrão)
docker compose restart filemanager

# Nova senha padrão: admin / password
```

## Performance e Otimizações

### Aumentar Tamanho Máximo de Upload

1. Editar `/var/filemanager/docker-compose.yml`
2. Adicionar ao container filemanager:
```yaml
environment:
  - AUTO_UPDATE=false
  - MAX_FILE_SIZE=1000m

ports:
  - "80:80"

# Se usar Nginx Proxy, ajustar lá também:
# client_max_body_size 1000m;
```

3. Restaurar:
```bash
docker compose up -d --build
```

### Otimizar para Muitos Arquivos

Se a pasta tiver milhares de arquivos:

1. Usar arquivos compactados (ZIP, TAR.GZ)
2. Aumentar timeout de visualização
3. Considerar usar SFTP (mais rápido para grandes transferências)

## Integração com WordPress

### Acessar Diretamente via Filebrowser

```
https://files.seu-dominio.com.br
→ Navegar a /var/www/seudominio.com.br
→ Editar wp-config.php, .htaccess, plugins, temas
```

### Criar Usuário para Gerenciador de Site

```bash
cd /var/filemanager

# Criar usuário com acesso apenas a um site
docker compose exec filemanager filebrowser users add gerenciador senha

# Definir scope (pasta acessível)
docker compose exec filemanager filebrowser users update gerenciador -scope /var/www/seudominio.com.br
```

## Integração com AzuraCast

### Acessar Arquivos do AzuraCast

```
https://files.seu-dominio.com.br
→ Navegar a /var/azuracast
→ Gerenciar estações, uploads, configurações
```

**CUIDADO**: Não editar arquivos críticos do AzuraCast sem backup!

## Segurança

- ✅ Use HTTPS (via Nginx Proxy Manager)
- ✅ Mude a senha admin padrão imediatamente
- ✅ Crie usuários com permissões limitadas
- ✅ Use senhas fortes
- ✅ Desative `allowShell` se não precisar
- ✅ Faça backups regulares
- ✅ Monitore logs: `docker compose logs filemanager`

## Backup

```bash
cd /var/filemanager

# Backup simples
tar -czf ../filemanager_backup.tar.gz .

# Backup com data
tar -czf ../filemanager_backup_$(date +%Y%m%d).tar.gz .

# Backup dos arquivos servidos (se necessário)
tar -czf ../www_arquivos_backup.tar.gz /var/www
```

## Atualizar Filebrowser

```bash
cd /var/filemanager

# Atualizar imagem
docker compose pull

# Reiniciar
docker compose up -d --build

# Verificar versão
docker compose exec filemanager filebrowser version
```

## Suporte

- [Documentação Filebrowser](https://filebrowser.org/)
- [GitHub Filebrowser](https://github.com/filebrowser/filebrowser)
- Logs: `docker compose logs filemanager`
- Interface Web: Settings → Logs

## Dicas de Produção

1. **Restringir Acesso**: Use Nginx Proxy Manager com autenticação adicional
2. **Monitorar**: Verificar logs regularmente
3. **Rotação de Logs**: O Filebrowser cria logs em `/data/filebrowser.log`
4. **Integração LDAP**: Para ambientes corporativos (versão Pro)
5. **2FA**: Considerar proxying com autenticação de dois fatores
