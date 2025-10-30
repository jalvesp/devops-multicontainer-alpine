#!/usr/bin/env sh
set -eu

# Valores vindos do docker-compose.yml (com defaults seguros)
: "${APP_DB_USER:=app_user}"
: "${APP_DB_PASSWORD:=app_password}"
: "${APP_DB_NAME:=app_db}"

# Variáveis padrão do container oficial do Postgres
: "${POSTGRES_USER:=postgres}"
: "${POSTGRES_DB:=postgres}"

echo ">> [initdb] criando usuário '${APP_DB_USER}' e banco '${APP_DB_NAME}'..."

# 1) Cria ROLE e DATABASE se não existirem
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
DO
\$do\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${APP_DB_USER}') THEN
      CREATE ROLE ${APP_DB_USER} LOGIN PASSWORD '${APP_DB_PASSWORD}';
   END IF;
END
\$do\$;

-- Cria o banco da aplicação se não existir (com owner = app_user)
SELECT 'CREATE DATABASE ${APP_DB_NAME} OWNER ${APP_DB_USER}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${APP_DB_NAME}')
\gexec

-- Não expor o DB publicamente
REVOKE ALL ON DATABASE ${APP_DB_NAME} FROM PUBLIC;
GRANT CONNECT ON DATABASE ${APP_DB_NAME} TO ${APP_DB_USER};
EOSQL

# 2) Ajusta privilégios dentro do banco da aplicação
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$APP_DB_NAME" <<-EOSQL
-- Garantir que o owner é o usuário da app (idempotente)
ALTER DATABASE ${APP_DB_NAME} OWNER TO ${APP_DB_USER};

-- Schema público: remover privilégios de PUBLIC e conceder apenas à app
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE, CREATE ON SCHEMA public TO ${APP_DB_USER};

-- Default privileges: tabelas e sequências futuras criadas pelo owner (admin) concedidas à app
ALTER DEFAULT PRIVILEGES FOR USER ${POSTGRES_USER} IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ${APP_DB_USER};

ALTER DEFAULT PRIVILEGES FOR USER ${POSTGRES_USER} IN SCHEMA public
    GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO ${APP_DB_USER};

-- Conveniência: search_path
ALTER ROLE ${APP_DB_USER} SET search_path TO public;
EOSQL

echo ">> [initdb] usuário e banco criados/ajustados com sucesso."
