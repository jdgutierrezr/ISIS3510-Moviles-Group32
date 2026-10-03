#!/usr/bin/env python3
"""Isolated local PostgreSQL + PostgREST fixture server for iOS integration tests.
Requires Docker and Python 3. Writes ONLY a local-test JWT to the supplied env file.
Stop with Ctrl-C to remove its containers. Never connects to hosted Supabase.
"""
import argparse
import base64
import hashlib
import hmac
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import time
import urllib.error
import urllib.request

parser = argparse.ArgumentParser()
parser.add_argument('--env-file', type=Path, required=True)
args = parser.parse_args()
sql = Path(__file__).resolve().parents[1]
suffix = str(int(time.time()))
db = 'wandr-bq11-db-' + suffix
api = 'wandr-bq11-api-' + suffix
network = 'wandr-bq11-network-' + suffix
secret = 'bq11-local-only-secret-at-least-32-characters'

def run(*command, **kwargs):
    return subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, **kwargs)

def apply(filename):
    result = run('docker', 'exec', db, 'psql', '-U', 'postgres', '-v', 'ON_ERROR_STOP=1', '-f', '/backend/sql/' + filename)
    print(result.stdout.decode().strip(), flush=True)

try:
    run('docker', 'network', 'create', network)
    run('docker', 'run', '--detach', '--name', db, '--network', network,
        '-e', 'POSTGRES_PASSWORD=local-test', '-v', str(sql.parent) + ':/backend:ro', 'postgres:17-alpine')
    for attempt in range(30):
        ready = subprocess.run(['docker', 'exec', db, 'pg_isready', '-U', 'postgres'], capture_output=True)
        if ready.returncode == 0:
            break
        time.sleep(1)
    else:
        raise RuntimeError('Local PostgreSQL did not start')
    apply('tests/reviews_bootstrap.sql')
    run('docker', 'exec', '-i', db, 'psql', '-U', 'postgres', '-v', 'ON_ERROR_STOP=1', input=b'''
      grant usage on schema public to authenticated;
      alter default privileges in schema public grant select on tables to authenticated;
      create or replace function auth.uid() returns uuid language sql stable as $$
        select coalesce(nullif(current_setting('request.jwt.claim.sub',true),''),
          nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sub')::uuid;
      $$;
    ''')
    for filename in ['schema_creation.sql', 'rls_rules.sql', 'rpc_functions.sql', 'bq11.sql',
                     'tests/bq11_fixtures.sql', 'bq11.sql', 'tests/bq11_test.sql']:
        apply(filename)
    run('docker', 'run', '--detach', '--name', api, '--network', network,
        '-p', '127.0.0.1:55433:3000', '-e', 'PGRST_DB_URI=postgres://postgres:local-test@' + db + ':5432/postgres',
        '-e', 'PGRST_DB_ANON_ROLE=anon', '-e', 'PGRST_JWT_SECRET=' + secret,
        'public.ecr.aws/supabase/postgrest:v14.10')

    # Only removes Supabase's /rest/v1 prefix; PostgreSQL executes every RPC.
    class Proxy(BaseHTTPRequestHandler):
        def do_POST(self):
            if not self.path.startswith('/rest/v1/rpc/'):
                self.send_error(404)
                return
            data = self.rfile.read(int(self.headers.get('Content-Length', '0')))
            headers = {'Content-Type': 'application/json', 'Authorization': self.headers.get('Authorization', '')}
            request = urllib.request.Request('http://127.0.0.1:55433' + self.path[len('/rest/v1'):], data=data, headers=headers)
            try:
                response = urllib.request.urlopen(request, timeout=15)
            except urllib.error.HTTPError as error:
                response = error
            body = response.read()
            self.send_response(response.status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    def encode(value):
        return base64.urlsafe_b64encode(json.dumps(value, separators=(',', ':')).encode()).rstrip(b'=')
    header = encode({'alg': 'HS256', 'typ': 'JWT'})
    payload = encode({'role': 'authenticated', 'sub': '10000000-0000-0000-0000-000000000001', 'exp': int(time.time()) + 3600})
    message = header + b'.' + payload
    signature = base64.urlsafe_b64encode(hmac.new(secret.encode(), message, hashlib.sha256).digest()).rstrip(b'=')
    token = (message + b'.' + signature).decode()
    args.env_file.write_text(json.dumps({'WANDR_BQ11_TEST_URL': 'http://127.0.0.1:55434', 'WANDR_BQ11_TEST_TOKEN': token}))
    print('Local BQ11 integration server ready on 127.0.0.1:55434', flush=True)
    ThreadingHTTPServer(('127.0.0.1', 55434), Proxy).serve_forever()
finally:
    for container in [api, db]:
        subprocess.run(['docker', 'rm', '-f', container], capture_output=True)
    subprocess.run(['docker', 'network', 'rm', network], capture_output=True)
