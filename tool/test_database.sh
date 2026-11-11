#!/usr/bin/env bash
# Teste le schéma, les données initiales et les règles de sécurité (RLS) sur
# une base PostgreSQL locale jetable. Prérequis : PostgreSQL 15 ou plus.
#
#   PGUSER=postgres ./tool/test_database.sh
set -euo pipefail
cd "$(dirname "$0")/.."
DB="sifflet_test_$$"
createdb "$DB"
trap 'dropdb --if-exists "$DB"' EXIT
run() { psql -X -q -t -v ON_ERROR_STOP=1 -d "$DB" "$@" | sed '/^\s*$/d'; }
run -f supabase/tests/supabase_mock.sql
for f in supabase/migrations/*.sql; do run -f "$f"; done
run -f supabase/seed.sql
run -f supabase/seed.sql   # rejouable sans doublon
run -f supabase/tests/securite_rls.sql
