# Hermes local backend foundation

Status: implemented and exercised with real HTTP, subprocess, and SQLite tests. Not production-ready, not deployed, and not connected to an action executor.

## HTTP contract v1

Loopback only, default `http://127.0.0.1:8766`. JSON UTF-8. All dates ISO-8601 UTC whole seconds (`2026-01-01T00:00:00Z`); UUID strings. Responses `Cache-Control: no-store`. No CORS. Only health is public. Pair authenticates with a high-entropy, short-lived, single-use pairing credential; every other endpoint requires `Authorization: Bearer <deviceToken>`.

- `GET /health` → 200 `{"status":"ok","service":"hermes-local","executionEnabled":false}`.
- `POST /v1/pair`, JSON `{"code":"<pairing credential>"}` → 200 `{"deviceToken":"<opaque secret>","sessionID":"<UUID>","companyID":"<UUID>","expiresAt":"<ISO8601>"}`. Code confers access to exactly one company chosen by the local operator. Unknown, expired, or already-used code → 401. Tokens are returned once; store in iOS Keychain, never UserDefaults/logs. Pairing codes are credentials, not 6-digit PINs.
- `GET /v1/workspace` → 200 **bare `WorkspaceSnapshot`**, matching `Sources/HermesCore/Models.swift`: `{"companies":[Company],"chats":[CompanyChat],"messages":[ChatMessage],"agents":[CompanyAgent],"approvals":[ApprovalRequest],"selectedCompanyID":"<session company UUID>","selectedChatID":null}`. Exactly one company, only its records. Optional `?companyID=<UUID>` must match the session; otherwise 403. No invented/demo records; unconfigured companies cannot pair. UUID spelling follows stored Swift model data.
- `POST /v1/approvals/{id}/decision`, JSON `{"decision":"approve","idempotencyKey":"<unique UUID or 16–128 ASCII safe chars>"}` (`reject` also accepted) → 200 `{"approval":ApprovalRequest,"decisionID":"<UUID>","recordedAt":"<ISO8601>","executionStatus":"notExecuted"}`. Approval status becomes `approved` or `rejected`. This is **only an auditable local decision**, never evidence of message delivery, task start, or Hermes execution. Exact repeat with the same session/key/approval/decision returns the identical body. Key reuse for different content or any second decision with a different key → 409. Unknown/other-company approval → 404. Expired/non-pending approval → 409.
- `GET /v1/approvals/{id}/audit` → 200 `{"events":[{"approval":ApprovalRequest,"decisionID":"<UUID>","recordedAt":"<ISO8601>","executionStatus":"notExecuted"}]}` (empty before decision). Scoped to session company.
- `POST /v1/session/revoke`, JSON `{}` → 200 `{"revoked":true}`. Token then returns 401.

Errors: `{"error":"<stable error code>"}`; 400 invalid request, 401 unauthorized, 403 forbidden, 404 not_found, 409 conflict, 413 body_too_large, 415 unsupported_media_type. Client must handle non-2xx; no successful offline fallback. A revoked/expired session cannot retrieve an idempotent result. No public write/import/pair-creation endpoint.

## Operator commands and integration findings

Python 3.11+ standard library only; no install, gateway, network credentials, or external action runner required. From `/Users/edorfanini`:

```sh
python3 -B -m unittest discover -s hermes/backend -v
python3 -B hermes/backend/server.py --help
python3 -B hermes/backend/server.py --db hermes/backend/state/backend.sqlite3 add-company /path/to/operator-company.json
python3 -B hermes/backend/server.py --db hermes/backend/state/backend.sqlite3 serve --port 8766
# In a separate interactive, non-recorded terminal:
python3 -B hermes/backend/server.py --db hermes/backend/state/backend.sqlite3 pair-code COMPANY_UUID
```

`add-company` accepts one real operator-provided `Company` JSON object using the Swift model above, **not** a seeded `WorkspaceSnapshot`. It checks UUIDs, company/profile scope, organization and profile fields, and refuses duplicate company IDs. Database starts empty. No live identities are included in source/tests. Company ID spelling must match between provisioning, pairing, and query; use UUIDs exactly as returned by the API. `pair-code` generates 256 bits of random entropy, TTL 300 seconds, stores SHA-256 only, and refuses redirected output to avoid logging credentials. The local operator is trusted; anyone with filesystem access as that OS user can provision access. Device tokens also have 256 bits, are stored only as SHA-256, expire after 24 hours, and can revoke themselves. No refresh endpoint.

Explicit approval provisioning for a **genuine reviewed proposal**, not a notification or read marker:

```sh
python3 -B hermes/backend/server.py --db hermes/backend/state/backend.sqlite3 add-approval /path/to/reviewed-approval.json
```

Input is exactly an `ApprovalRequest` object with `chatID:null`, status `pending` or `expired`, and whole-second UTC `createdAt`. Other initial statuses and linked chats are rejected. No HTTP endpoint creates approvals. Decisions atomically update the approval and insert an immutable audit row (session ID, approval ID, decision, request hash, idempotency key, timestamp, full original receipt) within `BEGIN IMMEDIATE`. Unique constraints and triggers prevent ordinary duplicate/update/delete ledger writes. This is not tamper-proof against a filesystem owner; no external delivery evidence is recorded.

### Read-only Teams cache adapter

Read-only inspection of the existing default Hermes profile found:

- `~/.hermes/runtime/celeritech-teams-all-chats.json`: a real array of **282** cached chats at inspection, with Graph IDs, topic/chat type, timestamps, member metadata, and optional previews. Count is an observation, not a live service claim.
- `celeritech-teams-work-monitor.json`: only `seen` and `updated_at` (2 seen markers observed).
- `celeritech-msgraph-events.json`: only `processed_ids` (6 markers observed).
- The work-monitor source prepares approval notifications; these files do **not** constitute a durable pending-approval queue. Seen/processed markers must never become approvals or proof that an action ran.

The included adapter is **opt-in, metadata-only**, not a live subscription:

```sh
python3 -B hermes/backend/server.py --db hermes/backend/state/backend.sqlite3 import-teams-cache COMPANY_UUID /Users/edorfanini/.hermes/runtime/celeritech-teams-all-chats.json
```

Python operator API: `Store(db_path).import_teams_metadata(company_id, records)`. It reads the input file without modifying it; all writes stay in the selected backend database. One transaction upserts chats with deterministic `UUID5(UUID(company_id), "microsoft-teams:chat:" + source_id)` IDs. Source IDs/timestamps, original `source_chat_type`, and import time live separately in the private `provenance` table, not the public snapshot. Graph's `unknownFutureValue` is explicitly accepted as a generic `general` chat with fallback title `Teams chat (unknown type)`; the original source type and ID remain unchanged in provenance. Other unsupported chat type values reject the whole transaction. The additive provenance column is migrated automatically for earlier foundation databases. It maps topics and chat type only; missing topics have descriptive channel labels, not fabricated content. Emails, members, HTML/previews, and message bodies are not imported. `lastMessage` is empty and `lastMessageAt` null because a chat's modification time is not evidence of message time. Unread count/priority/pin defaults are local UI state, not Graph facts. Reimport updates metadata without duplicating chats; it does not delete missing chats and is not full synchronization. A bad record rolls back the entire import. Limit: 10,000 records / 16 MiB CLI file. No real cache content was copied into source, tests, or a persistent database by this task.

`messages` and `agents` remain empty until a separately reviewed adapter exists. `approvals` remain empty unless an operator explicitly provisions real proposals. Do not show seeded app data as live backend data. Before a future live adapter: establish tenant→company allowlists, source freshness/retention, idempotent source cursors, explicit proposal provenance, and separate execution authorization. Never reuse Hermes OAuth/gateway secrets as device tokens. Official integration research entry point: https://hermes-agent.nousresearch.com/docs/llms.txt ; local monitor scripts were inspected only, never executed.

## Security boundaries and remaining deployment work

- Socket always binds **127.0.0.1**, not configurable to public/LAN. Host must equal `127.0.0.1:<actual port>` exactly; any Origin header or absolute proxy URL is rejected (DNS rebinding/browser-origin defense). No CORS. Pairing is rate-limited globally to 10 requests per 60 seconds, reset on restart. 429 returns `{"error":"rate_limited"}`; wait 60 seconds before retrying. This local limiter is not a distributed anti-abuse system.
- JSON bodies capped at 8 KiB; connections have five-second socket timeout. Request logging is suppressed. No credentials in source/logs. Database file mode 0600, newly created state directory 0700; SQLite is not encrypted. Protect backups and host account. Input files may contain sensitive topics and require local access controls.
- HTTP is deliberately local-only. **The current Swift connection client requires HTTPS; direct physical-iPhone connectivity is not enabled.** A reviewed TLS/private-network ingress must rewrite Host to the local authority, terminate authenticated encrypted transport, retain no credential logs, apply resource limits, and be tested before real device use. Do not weaken the client transport policy or expose this stdlib development server directly. No tunnel, proxy, certificate, app ATS exception, launch agent, or gateway change was installed.
- Missing production work: hardened HTTP server/resource accounting, TLS ingress and device end-to-end verification, tenant/member authorization beyond one-company sessions, session management UI, audited migrations/backup/restore and retention, signed/tamper-evident audit if required, actual proposal and message ingestion, and a separately authorized action executor. Nothing here claims production readiness.

## Verification and repeatable workflow

Latest local run: **10 unittest methods passed**, covering real HTTP health/auth failures, pairing single-use/expiry/hash-at-rest, session expiration/revocation, cross-company rejection, approve/reject/no execution, replay/conflicting keys, immutable audit rows, restart persistence, concurrent pairing/decisions, input validation, Host/Origin defenses, pairing rate limit, transactional metadata adapter with stable IDs and private provenance, and actual subprocess CLI server startup. Tests use synthetic data only and temporary directories inside `backend/`; servers terminate on cleanup. No deployment remains running.

Development procedure: add a failing real HTTP/database test for the next behavior; run it and observe the missing behavior; implement; rerun the full suite. Keep integration discovery read-only and keep real data/credentials out of fixtures. Preserve the distinction between a recorded approval and an executed action.
