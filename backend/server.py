"""Loopback-only approval ledger; deliberately no action executor."""
import hashlib
import json
import os
import pathlib
import secrets
import sqlite3
import time
import uuid
from contextlib import contextmanager
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit, parse_qs


def stamp(seconds=None):
    return datetime.fromtimestamp(time.time() if seconds is None else seconds, timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


class APIError(Exception):
    def __init__(self, status, code):
        self.status, self.code = status, code


class Store:
    def __init__(self, path):
        self.path = pathlib.Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        fd = os.open(self.path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        os.close(fd)
        self.path.chmod(0o600)
        with self.connect() as db:
            db.executescript('''
            CREATE TABLE IF NOT EXISTS companies(id TEXT PRIMARY KEY, payload TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS pairing(hash TEXT PRIMARY KEY, company_id TEXT NOT NULL REFERENCES companies(id), expires REAL NOT NULL, used INTEGER NOT NULL DEFAULT 0);
            CREATE TABLE IF NOT EXISTS sessions(id TEXT PRIMARY KEY, hash TEXT UNIQUE NOT NULL, company_id TEXT NOT NULL REFERENCES companies(id), expires REAL NOT NULL, revoked INTEGER NOT NULL DEFAULT 0);
            CREATE TABLE IF NOT EXISTS chats(id TEXT PRIMARY KEY, company_id TEXT NOT NULL REFERENCES companies(id), payload TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS provenance(record_id TEXT PRIMARY KEY REFERENCES chats(id), company_id TEXT NOT NULL REFERENCES companies(id), source TEXT NOT NULL, source_id TEXT NOT NULL, source_updated_at TEXT, imported_at TEXT NOT NULL, UNIQUE(company_id,source,source_id));
            CREATE TABLE IF NOT EXISTS approvals(id TEXT PRIMARY KEY, company_id TEXT NOT NULL REFERENCES companies(id), payload TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS decisions(id TEXT PRIMARY KEY, approval_id TEXT UNIQUE NOT NULL REFERENCES approvals(id), session_id TEXT NOT NULL REFERENCES sessions(id), idempotency_key TEXT NOT NULL, decision TEXT NOT NULL CHECK(decision IN ('approve','reject')), recorded_at TEXT NOT NULL, request_hash TEXT NOT NULL, response TEXT NOT NULL, UNIQUE(session_id,idempotency_key));
            CREATE TRIGGER IF NOT EXISTS decisions_no_update BEFORE UPDATE ON decisions BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
            CREATE TRIGGER IF NOT EXISTS decisions_no_delete BEFORE DELETE ON decisions BEGIN SELECT RAISE(ABORT,'immutable audit'); END;
            ''')
            db.execute('BEGIN IMMEDIATE')
            if 'source_chat_type' not in {row[1] for row in db.execute('PRAGMA table_info(provenance)')}:
                db.execute('ALTER TABLE provenance ADD COLUMN source_chat_type TEXT')

    @contextmanager
    def connect(self):
        db = sqlite3.connect(self.path, timeout=5)
        db.row_factory = sqlite3.Row
        db.execute('PRAGMA foreign_keys=ON')
        try:
            with db:
                yield db
        finally:
            db.close()

    def add_company(self, company):
        uuid.UUID(company['id'])
        if company['profile']['companyID'] != company['id']:
            raise ValueError('Company profile scope mismatch')
        for key in ('name', 'summary'):
            if not isinstance(company[key], str):
                raise ValueError('Invalid company string')
        for key in ('name','role'):
            if not isinstance(company['ceo'][key],str):
                raise ValueError('Invalid person')
        if company['ceo'].get('email') is not None and not isinstance(company['ceo']['email'],str):
            raise ValueError('Invalid email')
        for key in ('ceoName','ceoTitle','mission','operatingNotes','approvalRules'):
            if not isinstance(company['profile'][key],str):
                raise ValueError('Invalid profile')
        if not isinstance(company['orgNodes'],list) or not isinstance(company['orgEdges'],list):
            raise ValueError('Invalid organization')
        for node in company['orgNodes']:
            uuid.UUID(node['id'])
            if not all(isinstance(node[k],str) for k in ('title','person')):
                raise ValueError('Invalid organization node')
        for edge in company['orgEdges']:
            if not all(isinstance(edge[k],str) for k in ('parentTitle','childTitle')):
                raise ValueError('Invalid organization edge')
        with self.connect() as db:
            db.execute('INSERT INTO companies VALUES (?,?)', (company['id'], json.dumps(company)))

    def create_pairing(self, company_id, ttl=300):
        if not 0 < ttl <= 300:
            raise ValueError('pairing TTL must be 1..300 seconds')
        code = secrets.token_urlsafe(32)
        with self.connect() as db:
            db.execute('INSERT INTO pairing(hash,company_id,expires) VALUES (?,?,?)', (digest(code), company_id, time.time()+ttl))
        return code

    def pair(self, code):
        if not isinstance(code, str) or not 32 <= len(code) <= 128:
            raise APIError(401, 'unauthorized')
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            row = db.execute('SELECT * FROM pairing WHERE hash=? AND used=0 AND expires>?', (digest(code), time.time())).fetchone()
            if row is None:
                raise APIError(401, 'unauthorized')
            token, sid, expires = secrets.token_urlsafe(32), str(uuid.uuid4()), time.time()+86400
            db.execute('UPDATE pairing SET used=1 WHERE hash=?', (digest(code),))
            db.execute('INSERT INTO sessions(id,hash,company_id,expires) VALUES (?,?,?,?)', (sid, digest(token), row['company_id'], expires))
            return dict(deviceToken=token, sessionID=sid, companyID=row['company_id'], expiresAt=stamp(expires))

    def authenticate(self, authorization):
        if not authorization.startswith('Bearer ') or len(authorization) > 256:
            raise APIError(401, 'unauthorized')
        with self.connect() as db:
            row = db.execute('SELECT * FROM sessions WHERE hash=? AND revoked=0 AND expires>?', (digest(authorization[7:]), time.time())).fetchone()
            if row is None:
                raise APIError(401, 'unauthorized')
            return dict(row)

    def import_teams_metadata(self, company_id, records):
        namespace = uuid.UUID(company_id)
        if not isinstance(records, list) or len(records) > 10000:
            raise ValueError('Expected bounded chat metadata array')
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            for record in records:
                if not isinstance(record,dict):
                    raise ValueError('Invalid Teams record')
                source_id = record.get('id')
                kind = record.get('chatType')
                if not isinstance(source_id,str) or not source_id or len(source_id)>2048 or kind not in ('oneOnOne','group','meeting','unknownFutureValue'):
                    raise ValueError('Invalid Teams metadata')
                topic = record.get('topic')
                if topic is not None and not isinstance(topic,str):
                    raise ValueError('Invalid chat topic')
                # No participant emails, previews, content, or source IDs enter the public snapshot.
                title = (topic or '').strip() or ('Teams chat (unknown type)' if kind == 'unknownFutureValue' else 'Teams direct chat' if kind == 'oneOnOne' else 'Teams '+kind+' chat')
                chat_id = str(uuid.uuid5(namespace, 'microsoft-teams:chat:'+source_id))
                chat = dict(id=chat_id, companyID=company_id, title=title, channel='teams', kind='direct' if kind=='oneOnOne' else 'general', lastMessage='', lastMessageAt=None, unreadCount=0, priority=False, pinned=False)
                updated = record.get('lastUpdatedDateTime')
                if updated is not None and not isinstance(updated,str):
                    raise ValueError('Invalid source timestamp')
                db.execute('INSERT INTO chats VALUES (?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload', (chat_id, company_id, json.dumps(chat)))
                db.execute('INSERT INTO provenance(record_id,company_id,source,source_id,source_updated_at,imported_at,source_chat_type) VALUES (?,?,?,?,?,?,?) ON CONFLICT(record_id) DO UPDATE SET source_updated_at=excluded.source_updated_at, imported_at=excluded.imported_at, source_chat_type=excluded.source_chat_type', (chat_id, company_id, 'microsoft-teams-cache', source_id, updated, stamp(), kind))

    def add_approval(self, approval):
        uuid.UUID(approval['id'])
        uuid.UUID(approval['companyID'])
        if set(approval) != {'id','companyID','chatID','title','proposedAction','status','createdAt'}:
            raise ValueError('Invalid approval schema')
        if not all(isinstance(approval[k],str) for k in ('title','proposedAction','createdAt')):
            raise ValueError('Invalid approval fields')
        datetime.strptime(approval['createdAt'], '%Y-%m-%dT%H:%M:%SZ')
        if approval['status'] not in ('pending', 'expired') or approval.get('chatID') is not None:
            raise ValueError('Only new pending/expired unlinked approvals may be inserted')
        with self.connect() as db:
            db.execute('INSERT INTO approvals VALUES (?,?,?)', (approval['id'], approval['companyID'], json.dumps(approval)))

    def scoped_approval(self, db, session, aid):
        row = db.execute('SELECT payload FROM approvals WHERE id=? AND company_id=?', (aid, session['company_id'])).fetchone()
        if row is None:
            raise APIError(404, 'not_found')
        return json.loads(row[0])

    def decide(self, session, aid, body):
        import re
        decision, key = body.get('decision'), body.get('idempotencyKey')
        if set(body) != {'decision','idempotencyKey'} or decision not in ('approve','reject') or not isinstance(key,str) or not re.fullmatch(r'[A-Za-z0-9_-]{16,128}', key):
            raise APIError(400, 'invalid_request')
        request_hash = digest(json.dumps([aid, decision], separators=(',', ':')))
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            # Recheck within the write transaction; a concurrent revoke wins if committed first.
            if not db.execute('SELECT 1 FROM sessions WHERE id=? AND revoked=0 AND expires>?', (session['id'], time.time())).fetchone():
                raise APIError(401, 'unauthorized')
            approval = self.scoped_approval(db, session, aid)
            previous = db.execute('SELECT request_hash,response FROM decisions WHERE session_id=? AND idempotency_key=?', (session['id'], key)).fetchone()
            if previous:
                if previous['request_hash'] != request_hash:
                    raise APIError(409, 'conflict')
                return json.loads(previous['response'])
            if approval['status'] != 'pending':
                raise APIError(409, 'conflict')
            approval['status'] = 'approved' if decision == 'approve' else 'rejected'
            did, recorded = str(uuid.uuid4()), stamp()
            result = dict(approval=approval, decisionID=did, recordedAt=recorded, executionStatus='notExecuted')
            db.execute('INSERT INTO decisions VALUES (?,?,?,?,?,?,?,?)', (did, aid, session['id'], key, decision, recorded, request_hash, json.dumps(result)))
            db.execute('UPDATE approvals SET payload=? WHERE id=?', (json.dumps(approval), aid))
            return result

    def audit(self, session, aid):
        with self.connect() as db:
            self.scoped_approval(db, session, aid)
            return {'events':[json.loads(r[0]) for r in db.execute('SELECT response FROM decisions WHERE approval_id=? ORDER BY recorded_at,id', (aid,))]}

    def workspace(self, session):
        cid = session['company_id']
        with self.connect() as db:
            db.execute('BEGIN')
            company = json.loads(db.execute('SELECT payload FROM companies WHERE id=?', (cid,)).fetchone()[0])
            approvals = [json.loads(r[0]) for r in db.execute('SELECT payload FROM approvals WHERE company_id=? ORDER BY id', (cid,))]
            chats = [json.loads(r[0]) for r in db.execute('SELECT payload FROM chats WHERE company_id=? ORDER BY id', (cid,))]
        return dict(companies=[company], chats=chats, messages=[], agents=[], approvals=approvals, selectedCompanyID=cid, selectedChatID=None)


class Handler(BaseHTTPRequestHandler):
    server_version = 'HermesLocal/1'
    sys_version = ''

    def setup(self):
        super().setup()
        self.connection.settimeout(5)

    def log_message(self, format, *args):
        pass  # Never log request paths, bodies, or credentials.

    def send_json(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def body(self):
        if self.headers.get('Content-Type', '').split(';')[0] != 'application/json':
            raise APIError(415, 'unsupported_media_type')
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if size > 8192:
                raise APIError(413, 'body_too_large')
            if size <= 0 or self.headers.get('Transfer-Encoding'):
                raise ValueError()
            data = json.loads(self.rfile.read(size))
            if not isinstance(data, dict):
                raise ValueError()
            return data
        except (ValueError, UnicodeError):
            raise APIError(400, 'invalid_request')

    def dispatch(self):
        try:
            route = urlsplit(self.path)
            store = self.server.store
            if self.headers.get_all('Host') != [f'127.0.0.1:{self.server.server_port}'] or self.headers.get('Origin') is not None or route.scheme or route.netloc:
                raise APIError(403, 'forbidden')
            if self.command == 'GET' and self.path == '/health':
                result = dict(status='ok', service='hermes-local', executionEnabled=False)
            elif self.command == 'POST' and self.path == '/v1/pair':
                self.server.check_pair_rate()
                result = store.pair(self.body().get('code'))
            else:
                session = store.authenticate(self.headers.get('Authorization', ''))
                if self.command == 'GET' and route.path == '/v1/workspace':
                    query = parse_qs(route.query, keep_blank_values=True)
                    if query and query != {'companyID':[session['company_id']]}:
                        raise APIError(403, 'forbidden')
                    result = store.workspace(session)
                elif route.path.startswith('/v1/approvals/') and not route.query:
                    parts = route.path.split('/')
                    if len(parts) != 5:
                        raise APIError(404, 'not_found')
                    if self.command == 'POST' and parts[4] == 'decision':
                        result = store.decide(session, parts[3], self.body())
                    elif self.command == 'GET' and parts[4] == 'audit':
                        result = store.audit(session, parts[3])
                    else:
                        raise APIError(404, 'not_found')
                elif self.command == 'POST' and self.path == '/v1/session/revoke':
                    if self.body() != {}:
                        raise APIError(400, 'invalid_request')
                    with store.connect() as db:
                        db.execute('UPDATE sessions SET revoked=1 WHERE id=?', (session['id'],))
                    result = {'revoked':True}
                else:
                    raise APIError(404, 'not_found')
            self.send_json(200, result)
        except APIError as error:
            self.send_json(error.status, {'error':error.code})
        except (sqlite3.Error, KeyError, TypeError, ValueError):
            self.send_json(500, {'error':'internal_error'})

    do_GET = dispatch
    do_POST = dispatch


class LocalServer(ThreadingHTTPServer):
    daemon_threads = True
    store: Store

    def __init__(self, *args, **kwargs):
        import threading
        super().__init__(*args, **kwargs)
        self.pair_lock = threading.Lock()
        self.pair_attempts = []

    def check_pair_rate(self):
        now = time.monotonic()
        with self.pair_lock:
            self.pair_attempts = [t for t in self.pair_attempts if now-t < 60]
            if len(self.pair_attempts) >= 10:
                raise APIError(429, 'rate_limited')
            self.pair_attempts.append(now)


def make_server(store, port=8766):
    server = LocalServer(('127.0.0.1', port), Handler)
    server.store = store
    return server


def main():
    import argparse
    import sys
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--db', type=pathlib.Path, default=pathlib.Path(__file__).parent/'state'/'backend.sqlite3')
    commands = parser.add_subparsers(dest='command', required=True)
    serve = commands.add_parser('serve')
    serve.add_argument('--port', type=int, default=8766)
    for command in ('add-company','add-approval'):
        commands.add_parser(command).add_argument('file', type=pathlib.Path)
    commands.add_parser('pair-code').add_argument('company_id')
    importer = commands.add_parser('import-teams-cache')
    importer.add_argument('company_id')
    importer.add_argument('file',type=pathlib.Path)
    args = parser.parse_args()
    try:
        if args.command == 'pair-code' and not sys.stdout.isatty():
            parser.exit(2, 'Pair credentials require an interactive terminal; refusing redirected output.\n')
        store = Store(args.db)
        if args.command == 'serve':
            server = make_server(store, args.port)
            print(f'Listening http://127.0.0.1:{server.server_port}', flush=True)
            try:
                server.serve_forever()
            except KeyboardInterrupt:
                pass
            finally:
                server.server_close()
        elif args.command == 'pair-code':
            print(store.create_pairing(args.company_id))
        else:
            if args.file.stat().st_size > (16777216 if args.command == 'import-teams-cache' else 1048576):
                raise ValueError('Input too large')
            data = json.loads(args.file.read_text())
            if args.command == 'import-teams-cache':
                store.import_teams_metadata(args.company_id, data)
            else:
                (store.add_company if args.command == 'add-company' else store.add_approval)(data)
            print('Record stored locally; no external action executed.')
    except (ValueError, KeyError, TypeError, OSError, sqlite3.Error):
        parser.exit(2, 'Operation failed: check input schema, company scope, duplicates, and database access.\n')


if __name__ == '__main__':
    main()
