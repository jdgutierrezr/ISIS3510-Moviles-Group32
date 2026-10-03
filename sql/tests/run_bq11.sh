#!/usr/bin/env bash
set -euo pipefail
sql_dir="$(cd "$(dirname "$0")/.." && pwd)"
container="wandr-bq11-test-$$"
trap 'docker rm -f "$container" >/dev/null 2>&1 || true' EXIT
docker run --detach --name "$container" -e POSTGRES_PASSWORD=local-test postgres:17-alpine >/dev/null
for attempt in $(seq 1 30); do
  if docker exec "$container" pg_isready -U postgres >/dev/null 2>&1; then break; fi
  sleep 1
done
run_sql() { docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 < "$1"; }
run_sql "$sql_dir/tests/reviews_bootstrap.sql"
docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 <<'SQL'
grant usage on schema public to authenticated;
alter default privileges in schema public grant select on tables to authenticated;
SQL
run_sql "$sql_dir/schema_creation.sql"
run_sql "$sql_dir/rls_rules.sql"
run_sql "$sql_dir/rpc_functions.sql"
run_sql "$sql_dir/bq11.sql"
run_sql "$sql_dir/tests/bq11_fixtures.sql"
# A rerun must preserve mappings and completion records.
run_sql "$sql_dir/bq11.sql"
run_sql "$sql_dir/tests/bq11_test.sql"
run_sql "$sql_dir/reviews.sql"
run_sql "$sql_dir/tests/bq11_review_compatibility_setup.sql"
# The optional seed must be repeatable without multiplying activity.
run_sql "$sql_dir/bq11_seed_data.sql"
run_sql "$sql_dir/bq11_seed_data.sql"
run_sql "$sql_dir/tests/bq11_seed_test.sql"
run_sql "$sql_dir/tests/bq11_review_compatibility_test.sql"
run_sql "$sql_dir/bq11_seed_data.sql"
run_sql "$sql_dir/tests/bq11_review_reseed_test.sql"
