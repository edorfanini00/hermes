import importlib.util
import json
import pathlib
import tempfile
import threading
import unittest
import urllib.request
import urllib.error

ROOT = pathlib.Path(__file__).parent

class HTTPTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('server', ROOT / 'server.py')
        self.assertIsNotNone(spec)
        self.assertTrue((ROOT / 'server.py').exists(), 'HTTP backend implementation missing')
        self.api = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.api)
        self.tmp = tempfile.TemporaryDirectory(dir=ROOT)
        self.addCleanup(self.tmp.cleanup)
        self.db = self.api.Store(pathlib.Path(self.tmp.name) / 'state.sqlite3')
        self.start()

    def start(self):
        self.http = self.api.make_server(self.db, port=0)
        self.thread = threading.Thread(target=self.http.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.stop)
        self.url = 'http://127.0.0.1:%s' % self.http.server_port

    def stop(self):
        if self.http:
            self.http.shutdown()
            self.http.server_close()
            self.thread.join()
            self.http = None

    def request(self, path, body=None, token=None):
        headers = {'Content-Type': 'application/json'}
        if token: headers['Authorization'] = 'Bearer ' + token
        req = urllib.request.Request(self.url + path, data=None if body is None else json.dumps(body).encode(), headers=headers)
        try: response = urllib.request.urlopen(req, timeout=3)
        except urllib.error.HTTPError as error: response = error
        with response:
            self.assertEqual(response.headers['Cache-Control'], 'no-store')
            return response.status, json.load(response)

    def test_health_public_everything_else_authenticated(self):
        self.assertEqual(self.request('/health'), (200, {'status':'ok','service':'hermes-local','executionEnabled':False}))
        self.assertEqual(self.request('/v1/workspace')[0], 401)
        self.assertEqual(self.request('/unknown', token='invalid')[0], 401)

    def provision(self):
        import uuid
        cid = str(uuid.uuid4())
        company = {'id':cid,'name':'Test company','ceo':{'name':'Test owner','role':'CEO','email':None},'profile':{'companyID':cid,'ceoName':'Test owner','ceoTitle':'CEO','mission':'Test','operatingNotes':'','approvalRules':''},'summary':'Test','orgNodes':[],'orgEdges':[]}
        self.db.add_company(company)
        return cid

    def pair(self, cid):
        code = self.db.create_pairing(cid)
        status, response = self.request('/v1/pair', {'code':code})
        self.assertEqual(status, 200)
        return response['deviceToken']

    def test_pair_single_use_scoped_persistent_session(self):
        cid = self.provision()
        code = self.db.create_pairing(cid)
        status, result = self.request('/v1/pair', {'code':code})
        self.assertEqual(status, 200)
        self.assertEqual(self.request('/v1/pair', {'code':code})[0], 401)
        token = result['deviceToken']
        self.assertEqual(self.request('/v1/workspace', token=token)[1]['selectedCompanyID'], cid)
        other = self.provision()
        self.assertEqual(self.request('/v1/workspace?companyID='+other, token=token)[0], 403)
        raw = self.db.path.read_bytes()
        self.assertNotIn(code.encode(), raw)
        self.assertNotIn(token.encode(), raw)
        self.stop()
        self.db = self.api.Store(self.db.path)
        self.start()
        status, snapshot = self.request('/v1/workspace', token=token)
        self.assertEqual(status, 200)
        self.assertEqual([c['id'] for c in snapshot['companies']], [cid])
        self.assertEqual(snapshot['messages'], [])

    def test_expired_pairing_sessions_and_revocation(self):
        cid = self.provision()
        code = self.db.create_pairing(cid)
        with self.db.connect() as db:
            db.execute('UPDATE pairing SET expires=0')
        self.assertEqual(self.request('/v1/pair', {'code':code})[0], 401)
        self.assertEqual(self.request('/v1/pair', {'code':'invalid'})[0], 401)
        token = self.pair(cid)
        self.assertEqual(self.request('/v1/session/revoke', {}, token)[0], 200)
        self.assertEqual(self.request('/v1/workspace', token=token)[0], 401)
        token = self.pair(cid)
        with self.db.connect() as db:
            db.execute('UPDATE sessions SET expires=0')
        self.assertEqual(self.request('/v1/workspace', token=token)[0], 401)

    def approval(self, cid, status='pending'):
        import uuid
        row = dict(id=str(uuid.uuid4()), companyID=cid, chatID=None, title='Synthetic test approval', proposedAction='Test only; no external action', status=status, createdAt='2026-01-01T00:00:00Z')
        self.db.add_approval(row)
        return row

    def test_approve_reject_auditable_idempotent_and_persistent(self):
        import uuid
        cid = self.provision()
        token = self.pair(cid)
        for decision, expected in [('approve','approved'), ('reject','rejected')]:
            item = self.approval(cid)
            path = '/v1/approvals/'+item['id']
            body = dict(decision=decision, idempotencyKey=str(uuid.uuid4()))
            self.assertEqual(self.request(path+'/decision', body)[0], 401)
            status, receipt = self.request(path+'/decision', body, token)
            self.assertEqual(status, 200)
            self.assertEqual(receipt['approval']['status'], expected)
            self.assertEqual(receipt['executionStatus'], 'notExecuted')
            self.assertEqual(self.request(path+'/decision', body, token), (200,receipt))
            changed = dict(body, decision='reject' if decision=='approve' else 'approve')
            self.assertEqual(self.request(path+'/decision', changed, token)[0], 409)
            self.assertEqual(self.request(path+'/decision', dict(body,idempotencyKey=str(uuid.uuid4())), token)[0], 409)
            self.assertEqual(self.request(path+'/audit', token=token), (200, {'events':[receipt]}))
            with self.db.connect() as db:
                self.assertEqual(db.execute('SELECT count(*) FROM decisions WHERE approval_id=?',(item['id'],)).fetchone()[0], 1)
            self.stop()
            self.db = self.api.Store(self.db.path)
            self.start()
            self.assertEqual(self.request(path+'/decision', body, token), (200,receipt))
            snapshot = self.request('/v1/workspace', token=token)[1]
            self.assertEqual(next(a for a in snapshot['approvals'] if a['id']==item['id'])['status'], expected)
        outsider = self.pair(self.provision())
        self.assertEqual(self.request(path+'/decision', body, outsider)[0], 404)
        self.assertEqual(self.request(path+'/audit', token=outsider)[0], 404)
        expired = self.approval(cid, 'expired')
        self.assertEqual(self.request('/v1/approvals/'+expired['id']+'/decision', dict(decision='approve',idempotencyKey=str(uuid.uuid4())),token)[0],409)

    def test_operator_cli_real_process_health_and_validation(self):
        import subprocess
        import sys
        import uuid
        import time
        company_id = self.provision()
        with self.db.connect() as db:
            company = json.loads(db.execute('SELECT payload FROM companies WHERE id=?',(company_id,)).fetchone()[0])
        company['id'] = str(uuid.uuid4())
        company['profile']['companyID'] = company['id']
        source = pathlib.Path(self.tmp.name)/'company.json'
        source.write_text(json.dumps(company))
        command = [sys.executable, '-B', str(ROOT/'server.py'), '--db', str(self.db.path)]
        run = subprocess.run(command+['add-company',str(source)],capture_output=True,text=True)
        self.assertEqual(run.returncode,0,run.stderr)
        token = self.pair(company['id'])
        self.assertEqual(self.request('/v1/workspace', token=token)[1]['companies'],[company])
        run = subprocess.run(command+['pair-code',company['id']],capture_output=True,text=True)
        self.assertNotEqual(run.returncode,0, 'Pair credential must not be written to redirected stdout')
        proc = subprocess.Popen(command+['serve','--port','0'],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        self.addCleanup(lambda: (proc.terminate(), proc.wait(timeout=5)) if proc.poll() is None else None)
        import select
        self.assertTrue(select.select([proc.stdout],[],[],5)[0], 'server failed to announce readiness')
        line = proc.stdout.readline().strip()
        self.assertTrue(line.startswith('Listening http://127.0.0.1:'), line)
        with urllib.request.urlopen(line.removeprefix('Listening ')+'/health',timeout=3) as response:
            self.assertFalse(json.load(response)['executionEnabled'])
        proc.terminate()
        proc.communicate(timeout=5)
        invalid = dict(company, profile=dict(company['profile'],companyID=str(uuid.uuid4())))
        with self.assertRaises(ValueError):
            self.db.add_company(invalid)

    def test_host_origin_rate_limit_and_bad_input(self):
        import http.client
        def raw(headers, body=b'{}', path='/v1/pair'):
            connection = http.client.HTTPConnection('127.0.0.1',self.http.server_port,timeout=3)
            connection.request('POST',path,body,headers=headers)
            response = connection.getresponse()
            status = response.status
            response.read()
            connection.close()
            return status
        self.assertEqual(raw({'Host':'evil.example','Content-Type':'application/json'}),403)
        self.assertEqual(raw({'Origin':'https://evil.example','Content-Type':'application/json'}),403)
        self.assertEqual(raw({'Content-Type':'text/plain'}),415)
        self.assertEqual(raw({'Content-Type':'application/json'},b'{'),400)
        self.assertEqual(raw({'Content-Type':'application/json'},b'x'*8193),413)
        for _ in range(10):
            status, _ = self.request('/v1/pair', {'code':'bad'})
        self.assertEqual(status,429)

    def test_metadata_adapter_stable_ids_scoped_no_invented_approvals(self):
        import uuid
        cid = self.provision()
        token = self.pair(cid)
        source = [{'id':'synthetic-source-chat','topic':'Synthetic group','chatType':'group','lastUpdatedDateTime':'2026-01-01T00:00:00.123Z','members':[{'displayName':'Test person','email':'not-imported@example.invalid'}],'lastMessagePreview':{'body':{'content':'must not import preview'}}}]
        self.db.import_teams_metadata(cid, source)
        snapshot = self.request('/v1/workspace', token=token)[1]
        self.assertEqual(len(snapshot['chats']),1)
        chat = snapshot['chats'][0]
        self.assertEqual(chat['companyID'],cid)
        self.assertEqual(chat['channel'],'teams')
        self.assertEqual(chat['lastMessage'],'')
        self.assertEqual(chat['lastMessageAt'],None)
        self.assertEqual(snapshot['messages'],[])
        self.assertEqual(snapshot['approvals'],[])
        self.assertNotIn('not-imported',json.dumps(snapshot))
        self.assertNotIn('synthetic-source-chat',json.dumps(snapshot))
        source[0]['topic']='Changed title'
        self.db.import_teams_metadata(cid,source)
        updated = self.request('/v1/workspace', token=token)[1]['chats']
        self.assertEqual(len(updated),1)
        self.assertEqual(updated[0]['id'],chat['id'])
        self.assertEqual(updated[0]['title'],'Changed title')
        other = self.provision()
        self.db.import_teams_metadata(other,source)
        self.assertNotEqual(self.request('/v1/workspace',token=self.pair(other))[1]['chats'][0]['id'],chat['id'])
        with self.db.connect() as db:
            self.assertEqual(db.execute('SELECT count(*) FROM provenance').fetchone()[0],2)
        broken = source + [{'id':'bad','chatType':'unknown'}]
        with self.assertRaises(ValueError): self.db.import_teams_metadata(cid,broken)
        self.assertEqual(len(self.request('/v1/workspace',token=token)[1]['chats']),1)

    def test_import_cli_and_concurrent_pair_and_decisions(self):
        import concurrent.futures
        import subprocess
        import sys
        import uuid
        cid = self.provision()
        file = pathlib.Path(self.tmp.name)/'teams.json'
        file.write_text(json.dumps([{'id':'synthetic-concurrent','topic':'Test','chatType':'group'}]))
        result = subprocess.run([sys.executable,'-B',str(ROOT/'server.py'),'--db',str(self.db.path),'import-teams-cache',cid,str(file)],capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        code = self.db.create_pairing(cid)
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(lambda _:self.request('/v1/pair',{'code':code}),range(4)))
        self.assertEqual(sorted(r[0] for r in results),[200,401,401,401])
        token = next(r[1]['deviceToken'] for r in results if r[0]==200)
        self.assertEqual(len(self.request('/v1/workspace',token=token)[1]['chats']),1)
        item = self.approval(cid)
        path = '/v1/approvals/'+item['id']+'/decision'
        body = dict(decision='approve',idempotencyKey=str(uuid.uuid4()))
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(lambda _:self.request(path,body,token),range(4)))
        self.assertEqual([r[0] for r in results],[200]*4)
        self.assertTrue(all(r[1]==results[0][1] for r in results))
        with self.db.connect() as db:
            self.assertEqual(db.execute('SELECT count(*) FROM decisions').fetchone()[0],1)
            import sqlite3
            with self.assertRaises(sqlite3.IntegrityError): db.execute('DELETE FROM decisions')

    def test_reject_invalid_approval_and_import_record_shapes(self):
        cid = self.provision()
        item = self.approval(cid)
        import uuid
        bad = dict(item,id=str(uuid.uuid4()),createdAt='not-a-date')
        with self.assertRaises(ValueError): self.db.add_approval(bad)
        with self.assertRaises(ValueError): self.db.import_teams_metadata(cid,[None])
        with self.db.connect() as db:
            self.assertEqual(db.execute('SELECT count(*) FROM approvals').fetchone()[0],1)

    def test_graph_unknown_future_value_preserves_source_type(self):
        cid = self.provision()
        self.db.import_teams_metadata(cid,[{'id':'future-source','chatType':'unknownFutureValue','topic':None}])
        snapshot = self.request('/v1/workspace',token=self.pair(cid))[1]
        self.assertEqual(snapshot['chats'][0]['kind'],'general')
        self.assertEqual(snapshot['chats'][0]['title'],'Teams chat (unknown type)')
        with self.db.connect() as db:
            row = db.execute('SELECT source_id,source_chat_type FROM provenance').fetchone()
            self.assertEqual(tuple(row),('future-source','unknownFutureValue'))

if __name__ == '__main__': unittest.main()
