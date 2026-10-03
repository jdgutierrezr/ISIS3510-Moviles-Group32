// Only run against a disposable database. Pass the psql invocation as arguments:
// node sql/tests/reviews_drift_test.mjs docker exec -i <container> psql -U postgres -d <database>
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';

const [command, ...args] = process.argv.slice(2);
assert(command, 'Pass a psql command targeting a disposable test database');
const migration = readFileSync(new URL('../reviews.sql', import.meta.url), 'utf8');
function run(input) {
  return spawnSync(command, [...args, '-v', 'ON_ERROR_STOP=1', '-At'], { input, encoding: 'utf8' });
}
const snapshotSQL = `select jsonb_build_array(
  (select jsonb_agg(to_jsonb(r) order by id) from public.quest_reviews r),
  (select jsonb_agg(to_jsonb(u) order by id) from public.users u),
  (select jsonb_agg(to_jsonb(p) order by id) from public.places p),
  (select jsonb_agg(to_jsonb(o) order by id) from storage.objects o));`;
const snapshot = run(snapshotSQL);
assert.equal(snapshot.status, 0, snapshot.stderr);
for (const [change, expectedError] of [
  ['alter table public.quest_reviews add column unexpected text;', 'schema differs'],
  ['alter table public.quest_reviews alter column notes drop not null;', 'schema differs'],
  ['alter table public.quest_reviews alter column xp_awarded set default 0;', 'schema differs'],
  ['alter table public.quest_reviews drop constraint quest_reviews_user_id_fkey;', 'foreign keys differ'],
  ['drop index public.quest_reviews_place_idx; create index quest_reviews_place_idx on public.quest_reviews(rating);', 'incompatible definition'],
]) {
  // Connection exit rolls back the injected drift when the migration rejects it.
  const result = run('begin;\n' + change + '\n' + migration);
  assert.notEqual(result.status, 0, 'Incompatible schema was accepted');
  assert(result.stderr.includes(expectedError), result.stderr);
  const verify = run(migration + '\n' + snapshotSQL);
  assert.equal(verify.status, 0, verify.stderr);
  assert.equal(verify.stdout.trim().split('\n').at(-1), snapshot.stdout.trim(), 'Rollback changed data');
}
console.log('Five incompatible schema cases rejected and rolled back without changing data');
