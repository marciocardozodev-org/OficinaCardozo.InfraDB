#!/bin/bash
set -e
set -x
echo "[DEBUG] Início do script: $(date)"

# Variáveis de ambiente esperadas:
# CONNECTION_STRING, API_PROJECT_PATH, DOTNET_ROOT, DOTNET_VERSION

echo "[DEBUG] Variáveis de ambiente recebidas para conexão com o RDS:"
echo "  RDS_HOST: $RDS_HOST"
echo "  RDS_USER: $RDS_USER"
echo "  RDS_PASS: ${RDS_PASS:0:2}********"  # Não exibe senha completa
echo "  RDS_DB: $RDS_DB"
echo "  CONNECTION_STRING: $CONNECTION_STRING"
echo "  API_PROJECT_PATH: $API_PROJECT_PATH"
echo "  DOTNET_ROOT: $DOTNET_ROOT"
echo "  DOTNET_VERSION: $DOTNET_VERSION"
echo "Aguardando o banco de dados responder na porta 5432..."
echo "[DEBUG] Tentando conexão com o banco às: $(date)"

RETRIES=12
until PGPASSWORD="$RDS_PASS" psql -h "$RDS_HOST" -U "$RDS_USER" -d "$RDS_DB" -p 5432 -c '\q'; do
  RETRIES=$((RETRIES-1))
  if [ $RETRIES -le 0 ]; then
    echo "Banco de dados não respondeu a tempo. Abortando."
    exit 1
  fi
  echo "Aguardando... ($RETRIES tentativas restantes)"
  sleep 10
done

dotnet restore "$API_PROJECT_PATH/../OficinaCardozo.Infrastructure/OficinaCardozo.Infrastructure.csproj"
dotnet restore "$API_PROJECT_PATH/OficinaCardozo.API.csproj"
dotnet ef database update --project "$API_PROJECT_PATH/../OficinaCardozo.Infrastructure/OficinaCardozo.Infrastructure.csproj" --startup-project "$API_PROJECT_PATH/OficinaCardozo.API.csproj"
echo "[DEBUG] Status dotnet ef database update: $? às $(date)"

echo "[DEBUG] Saída do dotnet ef database update: $?"

echo "Banco de dados disponível! Executando script SQL de criação do banco..."
# Caminho absoluto do script SQL gerado pelo EF Core
SQL_SCRIPT_PATH="${API_PROJECT_PATH}/../create-db.sql"
echo "[DEBUG] Checando existência do arquivo SQL em $SQL_SCRIPT_PATH às $(date)"
if [ ! -f "$SQL_SCRIPT_PATH" ]; then
  echo "ERRO: Script SQL não encontrado em $SQL_SCRIPT_PATH. Abortando."
  exit 1
fi
ls -l "$SQL_SCRIPT_PATH"
echo "[DEBUG] Iniciando execução do psql às $(date)"
PGPASSWORD="$RDS_PASS" psql -h "$RDS_HOST" -U "$RDS_USER" -d "$RDS_DB" -p 5432 -f "$SQL_SCRIPT_PATH"
PSQL_STATUS=$?
echo "[DEBUG] Status psql: $PSQL_STATUS às $(date)"
if [ $PSQL_STATUS -ne 0 ]; then
  echo "ERRO: Falha na execução do script SQL."
  exit $PSQL_STATUS
fi
echo "Script SQL executado com sucesso no RDS!"
# Caminho absoluto do script SQL gerado pelo EF Core
SQL_SCRIPT_PATH="${API_PROJECT_PATH}/../create-db.sql"

if [ ! -f "$SQL_SCRIPT_PATH" ]; then
  echo "ERRO: Script SQL não encontrado em $SQL_SCRIPT_PATH. Abortando."
  exit 1
fi

PGPASSWORD="$RDS_PASS" psql -h "$RDS_HOST" -U "$RDS_USER" -d "$RDS_DB" -p 5432 -f "$SQL_SCRIPT_PATH"
echo "Script SQL executado com sucesso no RDS!"

echo "[DEBUG] Saída do psql: $?"
