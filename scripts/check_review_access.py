"""Verify an isolated reviewer service over HTTPS; never print credentials.
Usage: python3 scripts/check_review_access.py https://review-host.example
Prompts securely for a reusable synthetic-tenant review code. Creates and revokes
one session twice, so approval decisions and workspace data are not modified.
"""
import getpass
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None

def main():
    if len(sys.argv) != 2:
        raise SystemExit('Provide the stable HTTPS server origin.')
    origin = sys.argv[1].strip().rstrip('/')
    parts = urllib.parse.urlsplit(origin)
    if parts.scheme != 'https' or not parts.hostname or parts.path or parts.query or parts.fragment or parts.username or parts.password:
        raise SystemExit('Use an HTTPS origin without a path, credentials, query or fragment.')
    code = getpass.getpass('Reusable synthetic review code: ').strip()
    opener = urllib.request.build_opener(NoRedirect)
    def request(path, body=None, token=None):
        headers = {'Accept': 'application/json'}
        if body is not None:
            headers['Content-Type'] = 'application/json'
        if token:
            headers['Authorization'] = 'Bearer ' + token
        req = urllib.request.Request(origin + path, data=None if body is None else json.dumps(body).encode(), headers=headers)
        with opener.open(req, timeout=30) as response:
            return json.load(response)
    for attempt in (1, 2):
        session = request('/v1/pair', {'code': code})
        token = session['deviceToken']
        try:
            workspace = request('/v1/workspace', token=token)
            cid = session['companyID']
            assert len(workspace['companies']) == 1 and workspace['companies'][0]['id'] == cid, 'Company mismatch'
            assert workspace['selectedCompanyID'] == cid, 'Selection mismatch'
            for collection in ('chats', 'messages', 'agents', 'approvals'):
                assert all(item['companyID'] == cid for item in workspace[collection]), 'Scope mismatch'
            print(f'Attempt {attempt}: paired and loaded isolated workspace.')
        finally:
            assert request('/v1/session/revoke', {}, token)['revoked'] is True, 'Revocation failed'
        try:
            request('/v1/workspace', token=token)
        except urllib.error.HTTPError as error:
            if error.code != 401:
                raise
        else:
            raise AssertionError('Revoked session still has access')
    print('Repeated reviewer pairing, workspace reads and revocation passed.')

if __name__ == '__main__':
    try:
        main()
    except (urllib.error.URLError, AssertionError, KeyError, ValueError):
        # Do not leak response bodies, request headers or credentials into logs.
        raise SystemExit('Review access check failed. Check TLS, service availability, credentials and API compatibility.')
