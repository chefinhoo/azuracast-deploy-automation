#!/bin/bash
# Script para criar usuário no Filebrowser
# Uso: ./criar_usuario_filebrowser.sh <usuario> <senha> <diretorio>

if [ "$#" -ne 3 ]; then
  echo "Uso: $0 <usuario> <senha> <diretorio>"
  exit 1
fi

USUARIO="$1"
SENHA="$2"
DIRETORIO="$3"

# Cria usuário no Filebrowser apontando para o diretório desejado
# O container deve se chamar 'filemanager'
docker exec filemanager filebrowser users add "$USUARIO" "$SENHA" --scope "$DIRETORIO"

if [ $? -eq 0 ]; then
  echo "Usuário '$USUARIO' criado com sucesso para o diretório '$DIRETORIO'!"
else
  echo "Erro ao criar usuário. Verifique se o container está rodando e os parâmetros estão corretos."
  exit 2
fi
