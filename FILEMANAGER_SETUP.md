# Configuração do Filebrowser

Este guia está alinhado com o fluxo atual dos scripts `install.sh` e `add_site.sh`.

## Visão geral

O Filebrowser é instalado em `/var/filemanager` e publicado via Nginx Proxy Manager (ex.: `files.seu-dominio.com.br`).

### Arquivos principais

- Docker Compose: `/var/filemanager/docker-compose.yml`
- Configuração: `/var/filemanager/settings.json`
- Banco SQLite (host): `/var/filemanager/filebrowser.db`
- Banco SQLite (container): `/database.db`

### Volumes montados no container

- `./root:/srv`
- `./filebrowser.db:/database.db`
- `./settings.json:/etc/config/settings.json`
- `/var:/var:rw`

> O instalador já corrige automaticamente cenários em que `filebrowser.db` virou diretório.

---

## Acesso inicial

1. Acesse `https://files.seu-dominio.com.br` (via proxy)
2. Usuário padrão: `admin`
3. Senha padrão: `password`
4. Altere a senha imediatamente em **Settings → Users → admin**

---

## Estrutura de clientes e sites

O projeto usa estrutura por cliente:

```text
$WEB_ROOT/
└── cliente-x/
    ├── .filebrowser-credentials.txt
    ├── html/
    │   ├── docker-compose.yml
    │   └── ...
    └── blog/
        ├── docker-compose.yml
        └── ...
```

- Padrão: `WEB_ROOT=/var`
- Para mudar: defina `WEB_ROOT` no ambiente ou no `.deploy-config`

---

## Criação automática de usuário por cliente

Ao criar site com `scripts/add_site.sh` (ou no fluxo interativo do `install.sh`), o script tenta:

1. Identificar/inicializar o banco do Filebrowser
2. Criar usuário com nome do cliente
3. Aplicar `scope` restrito ao diretório do cliente: `$WEB_ROOT/<cliente>`
4. Salvar credenciais em `$WEB_ROOT/<cliente>/.filebrowser-credentials.txt`

### Exemplo

```bash
sudo bash scripts/add_site.sh
```

Saída esperada (resumo):

- Usuário Filebrowser criado para o cliente
- Credenciais salvas no diretório do cliente

---

## Criar usuário manualmente (CLI)

Quando precisar criar manualmente:

```bash
docker exec filemanager filebrowser users add cliente1 "SenhaForte123" \
  --scope="${WEB_ROOT:-/var}/cliente1" \
  --perm.admin=false \
  --perm.execute=false \
  --perm.create=true \
  --perm.rename=true \
  --perm.modify=true \
  --perm.delete=true \
  --perm.share=false \
  --perm.download=true
```

### Permissões recomendadas

- `download=true`
- `create=true`
- `rename=true`
- `modify=true`
- `delete=true`
- `share=false`
- `admin=false`

---

## Comandos úteis

### Listar usuários

```bash
docker exec filemanager filebrowser -d /database.db -c /etc/config/settings.json users ls
```

### Atualizar scope

```bash
docker exec filemanager filebrowser -d /database.db -c /etc/config/settings.json users update cliente1 \
  --scope="${WEB_ROOT:-/var}/cliente1"
```

### Remover usuário

```bash
docker exec filemanager filebrowser -d /database.db -c /etc/config/settings.json users rm cliente1
```

---

## Troubleshooting

### 1) Erro na criação de usuário por banco de dados

Verifique:

```bash
ls -lah /var/filemanager/filebrowser.db
docker exec filemanager sh -lc 'ls -lah /database.db && filebrowser version'
```

Se necessário, reinicie:

```bash
cd /var/filemanager
docker compose restart filemanager
```

### 2) "Diretório não existe" ao criar usuário

O `scope` precisa apontar para o diretório real do cliente em `WEB_ROOT`.

Valide:

```bash
echo "WEB_ROOT=${WEB_ROOT:-/var}"
ls -lah "${WEB_ROOT:-/var}/nome-cliente"
```

### 3) Container não responde

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}' | grep filemanager
docker logs filemanager --tail 100
```

---

## Boas práticas

- Use um usuário por cliente
- Evite `scope` muito amplo (ex.: raiz completa)
- Não use `admin=true` para clientes
- Guarde as credenciais com permissão restrita (`chmod 600`)

---

## Referências

- [README.md](README.md)
- [AUTOMATED_INSTALL.md](AUTOMATED_INSTALL.md)
- [Documentação oficial do Filebrowser](https://filebrowser.org/)
