"""Local HTTPS runner for screenshot capture: wraps the real backend in TLS with a
self-signed localhost certificate that is trusted only inside the iOS Simulator.
Uses a throwaway demo database (not the private company DB)."""
import json, pathlib, ssl, sys, threading
sys.path.insert(0, str(pathlib.Path(__file__).parent / 'backend'))
import server as backend

root = pathlib.Path('/tmp/helios-demo'); root.mkdir(exist_ok=True)
db = root / 'demo.sqlite3'
store = backend.Store(db)
company = json.load(open(root / 'company.json'))
try:
    store.add_company(company)
except Exception as e:
    print('company exists or add failed:', e)
for f in sorted(root.glob('approval-*.json')):
    try: store.add_approval(json.load(open(f)))
    except Exception as e: print('approval', f.name, e)
if (root / 'teams.json').exists():
    try: print('import', store.import_teams_metadata(company['id'], json.load(open(root / 'teams.json'))))
    except Exception as e: print('teams import', e)
code = store.create_pairing(company['id'])
open(root / 'pair-code.txt', 'w').write(code if isinstance(code, str) else json.dumps(code))
srv = backend.make_server(store, 8766)
srv.extra_hosts = ('localhost',)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(root / 'localhost.pem', root / 'localhost-key.pem')
srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
print('Listening https://localhost:8766', flush=True)
srv.serve_forever()
