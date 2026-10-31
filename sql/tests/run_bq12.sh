#!/usr/bin/env bash
set -euo pipefail
sql_dir="$(cd "$(dirname "$0")/.." && pwd)"
container="wandr-bq12-test-$$"
trap 'docker rm -f "$container" >/dev/null 2>&1 || true' EXIT
docker run --detach --name "$container" -e POSTGRES_PASSWORD=local-test postgres:17-alpine >/dev/null
for attempt in $(seq 1 30); do
  if docker exec "$container" pg_isready -U postgres >/dev/null 2>&1; then break; fi
  sleep 1
done
run_sql() { docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 < "$1"; }
run_sql "$sql_dir/tests/reviews_bootstrap.sql"
docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 <<'SQL'
grant usage on schema public to authenticated, anon;
alter default privileges in schema public grant select on tables to authenticated;
SQL
run_sql "$sql_dir/schema_creation.sql"
run_sql "$sql_dir/rls_rules.sql"
run_sql "$sql_dir/rpc_functions.sql"
run_sql "$sql_dir/bq12.sql"
# psql resolves the migration rerun relative to this test file.
docker cp "$sql_dir/bq12.sql" "$container:/tmp/bq12.sql"
docker exec "$container" mkdir /tmp/tests
docker cp "$sql_dir/tests/bq12_test.sql" "$container:/tmp/tests/bq12_test.sql"
docker exec "$container" psql -U postgres -v ON_ERROR_STOP=1 -f /tmp/tests/bq12_test.sql
