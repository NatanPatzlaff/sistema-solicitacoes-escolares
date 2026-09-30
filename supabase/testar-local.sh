#!/bin/sh
# Testa schema.sql e seed.sql num PostgreSQL local descartável (porta 54329).
# Requer o PostgreSQL portátil em %LOCALAPPDATA%\pgsql-portable (ver memoria.md).
# Uso: sh supabase/testar-local.sh
set -e
PG="$LOCALAPPDATA/pgsql-portable/pgsql/bin"
D="${TEMP:-/tmp}/pgdata-solicitacoes"
PSQL="$PG/psql.exe -p 54329 -U postgres -X -q -v ON_ERROR_STOP=1"
cd "$(dirname "$0")"

"$PG/pg_ctl.exe" -D "$D" -m immediate stop >/dev/null 2>&1 || true
rm -rf "$D"
"$PG/initdb.exe" -D "$D" -U postgres -A trust -E UTF8 --locale=C >/dev/null
"$PG/pg_ctl.exe" -D "$D" -o "-p 54329" -l "$D/log.txt" -w start >/dev/null
trap '"$PG/pg_ctl.exe" -D "$D" -m fast stop >/dev/null' EXIT

echo "== Regras de acesso e ciclo de status (teste.sql)"
SAIDA=$($PSQL -d postgres -f teste.sql 2>&1 || true)
echo "$SAIDA" | grep -E "^--- |PASSARAM|ERRO|ERROR|CONTEXTO"
echo "$SAIDA" | grep -q "TODOS OS TESTES PASSARAM" || { echo "FALHOU"; exit 1; }

echo "== Dados de teste (seed.sql)"
# Banco novo; os papéis anon/authenticated já existem no servidor (criados acima).
$PSQL -d postgres -c "create database seed"
$PSQL -d seed <<'SQL'
create schema auth;
create schema extensions;
create table auth.users (id uuid primary key, email text unique);
create function auth.uid() returns uuid language sql stable
as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema public, auth, extensions to anon, authenticated;
alter default privileges in schema public grant all on tables to anon, authenticated;
alter default privileges in schema public grant execute on functions to anon, authenticated;
\ir schema.sql
\ir seed.sql
\ir verificar-seed.sql
SQL
