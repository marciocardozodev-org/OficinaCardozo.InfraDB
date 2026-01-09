#!/bin/bash
set -e

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
RETRIES=60
until PGPASSWORD="$RDS_PASS" psql -h "$RDS_HOST" -U "$RDS_USER" -d "$RDS_DB" -p 5432 -c '\q' 2>/dev/null; do
  RETRIES=$((RETRIES-1))
  if [ $RETRIES -le 0 ]; then
    echo "Banco de dados não respondeu a tempo. Abortando."
    exit 1
  fi
  echo "Aguardando... ($RETRIES tentativas restantes)"
  sleep 10
done

echo "Banco de dados disponível! Rodando migrations EF Core..."
export PATH="$PATH:$DOTNET_ROOT:/home/runner/.dotnet/tools"
export ConnectionStrings__DefaultConnection="$CONNECTION_STRING"
export ASPNETCORE_ENVIRONMENT="Production"
export API_PROJECT_PATH="$API_PROJECT_PATH"

dotnet restore "$API_PROJECT_PATH/../OficinaCardozo.Infrastructure/OficinaCardozo.Infrastructure.csproj"
dotnet restore "$API_PROJECT_PATH/OficinaCardozo.API.csproj"
dotnet ef database update --project "$API_PROJECT_PATH/../OficinaCardozo.Infrastructure/OficinaCardozo.Infrastructure.csproj" --startup-project "$API_PROJECT_PATH/OficinaCardozo.API.csproj"
