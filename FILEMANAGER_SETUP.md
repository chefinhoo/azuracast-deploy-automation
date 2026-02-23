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

---

## 🎯 Criar Usuários para Sites Específicos

### Cenário: Um usuário por site WordPress

Cada cliente/usuário deve ter acesso **apenas ao seu site**, sem ver os outros.

### Passo 1: Acessar o Filebrowser

```
https://files.seudominio.com.br
Login: admin / (sua senha)
```

### Passo 2: Criar Novo Usuário

**Via Interface Web:**

1. **Settings** (engrenagem) → **Users** → **New User**

2. Preencher:
   ```
   Username: cliente1
   Password: (senha forte)
   Scope: /var/www/site-do-cliente1.com.br
   ```

3. **Permissions** (Permissões):
   - ✅ `Download` - Baixar arquivos
   - ✅ `Upload` - Enviar arquivos
   - ✅ `Create` - Criar pastas/arquivos
   - ✅ `Rename` - Renomear
   - ✅ `Modify` - Editar arquivos
   - ✅ `Delete` - Apagar
   - ❌ `Share` - Compartilhar (desmarque para maior segurança)
   - ❌ `Admin` - Administrador (somente para você)

4. **Save**

5. **Repetir** para cada cliente/site

**Via CLI (mais rápido para múltiplos usuários):**

```bash
cd /var/filemanager

# Criar usuário restrito ao site
docker exec filemanager filebrowser users add cliente1 \
  --password="SenhaForte123" \
  --scope="/var/www/site-do-cliente1.com.br" \
  --perm.download \
  --perm.upload \
  --perm.create \
  --perm.rename \
  --perm.modify \
  --perm.delete

# Criar mais usuários
docker exec filemanager filebrowser users add cliente2 \
  --password="OutraSenha456" \
  --scope="/var/www/site-do-cliente2.com.br" \
  --perm.download \
  --perm.upload \
  --perm.create \
  --perm.rename \
  --perm.modify \
  --perm.delete
```

---

## 📋 Exemplos Práticos

### Exemplo 1: Cliente com WordPress

```bash
# Site: exemplo.com.br
# Usuário: admin_exemplo
# Acesso: Apenas aos arquivos do WordPress

docker exec filemanager filebrowser users add admin_exemplo \
  --password="Exemplo@2026!" \
  --scope="/var/www/exemplo.com.br" \
  --perm.download \
  --perm.upload \
  --perm.create \
  --perm.rename \
  --perm.modify \
  --perm.delete
```

**O que o usuário vê:**
```
/ (raiz aparente)
├── html/           (arquivos do WordPress)
│   ├── wp-content/
│   ├── wp-admin/
│   └── index.php
└── db_data/        (não acessível diretamente)
```

### Exemplo 2: Desenvolvedor com Acesso Total

```bash
# Usuário: dev_master
# Acesso: Todos os sites

docker exec filemanager filebrowser users add dev_master \
  --password="DevMaster@2026!" \
  --scope="/var/www" \
  --perm.admin \
  --perm.download \
  --perm.upload \
  --perm.create \
  --perm.rename \
  --perm.modify \
  --perm.delete \
  --perm.share
```

**O que o usuário vê:**
```
/ (raiz aparente)
├── site1.com.br/
├── site2.com.br/
├── exemplo.com.br/
└── outrosite.com.br/
```

### Exemplo 3: Cliente Somente Leitura

```bash
# Usuário: cliente_view
# Acesso: Apenas visualizar e baixar

docker exec filemanager filebrowser users add cliente_view \
  --password="View@2026!" \
  --scope="/var/www/seusite.com.br" \
  --perm.download
```

### Exemplo 4: Acesso ao AzuraCast

```bash
# Usuário: radio_admin
# Acesso: Apenas arquivos do AzuraCast

docker exec filemanager filebrowser users add radio_admin \
  --password="Radio@2026!" \
  --scope="/var/azuracast" \
  --perm.download \
  --perm.upload \
  --perm.create \
  --perm.rename \
  --perm.modify \
  --perm.delete
```

---

## 🔐 Estrutura de Permissões

| Permissão | Descrição | Recomendado para |
|-----------|-----------|------------------|
| `download` | Baixar arquivos | Todos |
| `upload` | Enviar arquivos | Clientes, Devs |
| `create` | Criar pastas/arquivos | Clientes, Devs |
| `rename` | Renomear arquivos | Clientes, Devs |
| `modify` | Editar arquivos | Clientes, Devs |
| `delete` | Apagar arquivos | **Com cuidado!** |
| `share` | Gerar links públicos | Apenas Admin |
| `admin` | Acesso administrativo | Apenas Você |

---

## 🛠️ Gerenciar Usuários via CLI

### Listar Todos os Usuários

```bash
docker exec filemanager filebrowser users ls
```

**Saída exemplo:**
```
+----+---------------+--------+-------------------------------+
| ID | Username      | Admin  | Scope                         |
+----+---------------+--------+-------------------------------+
| 1  | admin         | true   | /srv                          |
| 2  | admin_exemplo  | false  | /var/www/exemplo.com.br |
| 3  | cliente1      | false  | /var/www/site1.com.br        |
+----+---------------+--------+-------------------------------+
```

### Modificar Usuário Existente

```bash
# Alterar senha
docker exec filemanager filebrowser users update admin_exemplo \
  --password="NovaSenha@2026!"

# Alterar scope (pasta raiz)
docker exec filemanager filebrowser users update admin_exemplo \
  --scope="/var/www/outro-site.com.br"

# Adicionar permissões
docker exec filemanager filebrowser users update admin_exemplo \
  --perm.download \
  --perm.upload \
  --perm.create \
  --perm.rename \
  --perm.modify \
  --perm.delete \
  --perm.share

# Remover permissões (adicione "no-" antes)
docker exec filemanager filebrowser users update admin_exemplo \
  --no-perm.delete \
  --no-perm.share
```

### Remover Usuário

```bash
docker exec filemanager filebrowser users rm admin_exemplo
```

### Verificar Configuração de um Usuário

```bash
# Listar e filtrar com grep
docker exec filemanager filebrowser users ls | grep admin_exemplo
```

---

## 🔍 Troubleshooting de Permissões

### Problema: Usuário não vê seus arquivos

**Causa:** Scope incorreto ou pasta não existe

**Solução:**
```bash
# 1. Verificar se a pasta existe
ls -la /var/www/exemplo.com.br

# 2. Se não existir, criar
mkdir -p /var/www/exemplo.com.br/html

# 3. Ajustar permissões
chown -R www-data:www-data /var/www/exemplo.com.br

# 4. Atualizar scope do usuário
docker exec filemanager filebrowser users update admin_exemplo \
  --scope="/var/www/exemplo.com.br"
```

### Problema: "Permission denied" ao tentar criar/editar arquivos

**Causa:** Permissões do sistema operacional

**Solução:**
```bash
# Ajustar owner dos arquivos no host
chown -R www-data:www-data /var/www/exemplo.com.br

# Ajustar permissões
chmod -R 755 /var/www/exemplo.com.br
chmod -R 775 /var/www/exemplo.com.br/html/wp-content/uploads
```

### Problema: Usuário pode ver outros sites

**Causa:** Scope muito abrangente (ex: `/var/www`)

**Solução:**
```bash
# Restringir ao diretório específico
docker exec filemanager filebrowser users update admin_exemplo \
  --scope="/var/www/exemplo.com.br"
```

### Problema: Não consigo fazer login

**Causa 1:** Senha incorreta

**Solução:**
```bash
# Resetar senha
docker exec filemanager filebrowser users update admin_exemplo \
  --password="NovaSenha@2026!"
```

**Causa 2:** Usuário não existe

**Solução:**
```bash
# Listar usuários
docker exec filemanager filebrowser users ls

# Se não existir, criar
docker exec filemanager filebrowser users add admin_exemplo \
  --password="Senha@2026!" \
  --scope="/var/www/exemplo.com.br" \
  --perm.download \
  --perm.upload \
  --perm.create \
  --perm.rename \
  --perm.modify \
  --perm.delete
```

---

## ✅ Melhores Práticas

### 1. Segurança de Senhas
```bash
# ✅ Bom: Senha forte
--password="Exemplo@2026!XyZ"

# ❌ Ruim: Senha fraca
--password="123456"
```

### 2. Princípio do Menor Privilégio
```bash
# ✅ Bom: Acesso restrito ao necessário
--scope="/var/www/cliente-site.com.br"
--perm.download --perm.upload --perm.modify

# ❌ Ruim: Acesso total desnecessário
--scope="/var/www"
--perm.admin --perm.delete --perm.share
```

### 3. Nomenclatura de Usuários
```bash
# ✅ Bom: Identificáveis
admin_exemploibipitanga
dev_maria_site1
cliente_joao_site2

# ❌ Ruim: Genéricos
user1
user2
teste
```

### 4. Documentar Usuários Criados
```bash
# Criar arquivo de registro
cat > /root/usuarios_filebrowser.txt << 'EOF'
Usuário: admin_exemploibipitanga
Senha: Exemplo@2026!
Scope: /var/www/exemplo.com.br
Criado: 2026-01-04
Finalidade: Administração do site igreja

Usuário: dev_master
Senha: DevMaster@2026!
Scope: /var/www
Criado: 2026-01-04
Finalidade: Desenvolvedor com acesso total
EOF

# Proteger o arquivo
chmod 600 /root/usuarios_filebrowser.txt
```

---

## 📊 Script Auxiliar: Criar Múltiplos Usuários

Crie o arquivo `/root/criar_usuarios_filebrowser.sh`:

```bash
#!/bin/bash

# Criar usuários para múltiplos sites WordPress

usuarios=(
  "admin_exemploibipitanga:Exemplo@2026!:/var/www/exemplo.com.br"
  "admin_site2:Site2@2026!:/var/www/site2.com.br"
  "admin_site3:Site3@2026!:/var/www/site3.com.br"
)

for dados in "${usuarios[@]}"; do
  IFS=':' read -r usuario senha scope <<< "$dados"
  
  echo "Criando usuário: $usuario"
  
  docker exec filemanager filebrowser users add "$usuario" \
    --password="$senha" \
    --scope="$scope" \
    --perm.download \
    --perm.upload \
    --perm.create \
    --perm.rename \
    --perm.modify \
    --perm.delete
  
  echo "✓ Usuário $usuario criado com scope: $scope"
  echo ""
done

echo "==================================="
echo "Todos os usuários criados!"
echo "==================================="
docker exec filemanager filebrowser users ls
```

**Usar:**
```bash
chmod +x /root/criar_usuarios_filebrowser.sh
/root/criar_usuarios_filebrowser.sh
```

---

## Permissões de Pasta

Cada usuário pode ter uma pasta raiz diferente (sandbox):

**Via Interface:**
1. Settings → Users → Selecionar usuário
2. Alterar "Scope" (pasta visível)
3. Exemplos:
   - `/var/www/exemplo.com.br` - Apenas um site
   - `/var/www` - Todos os WordPress
   - `/var/azuracast` - Apenas AzuraCast
   - `/` - Sistema inteiro (com cautela)

---

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

---

## 📖 Referência Rápida

### Comandos Essenciais

```bash
# LISTAR USUÁRIOS
docker exec filemanager filebrowser users ls

# CRIAR USUÁRIO PARA UM SITE ESPECÍFICO
docker exec filemanager filebrowser users add NOME_USUARIO \
  --password="SENHA_FORTE" \
  --scope="/var/www/DOMINIO.com.br" \
  --perm.download \
  --perm.upload \
  --perm.create \
  --perm.rename \
  --perm.modify \
  --perm.delete

# ALTERAR SENHA
docker exec filemanager filebrowser users update NOME_USUARIO \
  --password="NOVA_SENHA"

# ALTERAR PASTA DE ACESSO (SCOPE)
docker exec filemanager filebrowser users update NOME_USUARIO \
  --scope="/var/www/NOVO_DOMINIO.com.br"

# REMOVER USUÁRIO
docker exec filemanager filebrowser users rm NOME_USUARIO

# AJUSTAR PERMISSÕES DE ARQUIVOS NO HOST
chown -R www-data:www-data /var/www/DOMINIO.com.br
chmod -R 755 /var/www/DOMINIO.com.br
```

### Tabela de Scopes Comuns

| Scope | Descrição | Uso |
|-------|-----------|-----|
| `/var/www/exemplo.com.br` | Um site específico | Cliente individual |
| `/var/www` | Todos os sites WordPress | Desenvolvedor/Admin |
| `/var/azuracast` | Arquivos do AzuraCast | Gerente de rádio |
| `/var/filemanager/data` | Dados do Filebrowser | Backup/Manutenção |
| `/` | Sistema completo | **Evitar!** |

### Exemplo Completo: Adicionar Cliente

```bash
# 1. Verificar se a pasta do site existe
ls -la /var/www/exemplo.com.br

# 2. Criar usuário
docker exec filemanager filebrowser users add admin_exemplo \
  --password="Exemplo@2026!" \
  --scope="/var/www/exemplo.com.br" \
  --perm.download \
  --perm.upload \
  --perm.create \
  --perm.rename \
  --perm.modify \
  --perm.delete

# 3. Verificar criação
docker exec filemanager filebrowser users ls | grep admin_exemplo

# 4. Informar cliente
echo "Acesso ao Filebrowser:"
echo "URL: https://files.seudominio.com.br"
echo "Usuário: admin_exemplo"
echo "Senha: Exemplo@2026!"
```

---

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
