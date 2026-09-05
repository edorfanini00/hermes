# Hermes iOS integration audit

## Scope and decision

Read-only source/runtime inspection of the SwiftUI app and default-profile Celeritech intake integration. Only this report was written; no app/backend source, credentials, configuration, gateway, subscription, or cron job was changed. Existing working-tree edits were present before this audit. No app build or external send was performed.

**Recommended implementation:** a separately managed, narrowly scoped mobile API sidecar on the existing Mac, reading the existing intake caches and using the installed Hermes runtime for explicitly approved work. Do not repurpose or restart the running port-8080 event gateway. Use a private VPN/Tailscale connection plus TLS and device-specific credentials for the personal MVP. For public self-hosted deployment, use the documented Hermes OAuth/OIDC sign-in approach, not a shared password on the internet. A new mobile approval ledger/API is required: the existing intake scripts are notification producers, not an approval service.

## Current SwiftUI controls

Source references are relative to the app repository and reflect the inspected tree.

| Surface | Actual implementation | Required correction |
|---|---|---|
| Chats, filters, search, company selection | Functional in-memory filtering/navigation (`HermesApp.swift:60–202`) | Feed server records; expose loading/error/stale states |
| Edit and new-message toolbar | Empty button closures (`105–125`) | Implement or disable explicitly |
| Add Company | An HStack, not a button (`231–245`) | Implement a sheet and durable server mutation or label unavailable |
| Contacts / Calls | Placeholder tabs (`43–47`) | Do not present as integrations |
| Send | Adds local `.sent` message only (`364–369`) | Never show delivery success without server receipt; separate agent instruction from external message approval |
| Paperclip / thread ellipsis | Decorative Images (`387`, `490`) | Add real handlers or remove |
| Microphone | Same send callback with empty draft; guard returns | Recording/transcription is absent |
| Spawn CRM agent | Appends local planning record (`573–575`; Models.swift:782–786) | No agent process is launched |
| Approvals | Rule text and pending count only (`569`, `593–616`) | No approval detail/approve/reject UI; core `resolveApproval` is only an unrestricted local enum change |
| Agent status / company org chart | Seeded display records | No evidence of runtime health/job status backing these records |
| Read state / pin state | Core methods exist, not wired to these screens | Opening a thread does not mark it read |
| Dates / sent tick | Thread separator always “Today”; outgoing tick based on rendering direction | Group actual dates; distinguish queued, acknowledged, failed, delivered |
| Persistence | `loadOrSeed` loads JSON or silently seeds and saves; mutations do not call persist | Errors/corrupt state must not turn into believable demo data |

There is no URLSession client, connection/sign-in view, credential storage, remote subscription, or live refresh in the inspected application source. `Company.celeritech()` declares Edoardo as CEO and generates a company/org chart: this is app seed content, not a verified corporate directory. `Models.swift:485–652` creates the example conversations, messages, agents, and approval.

## Existing app schema

`Sources/HermesCore/Models.swift`:

- `WorkspaceSnapshot`: companies, chats, messages, agents, approvals, selectedCompanyID, selectedChatID.
- All entity IDs and foreign keys are UUID; company seed ID is `11111111-1111-1111-1111-111111111111` (synthetic app identifier, **not** a real source identifier).
- Company: name, person/CEO, profile, summary, org nodes/edges. Profile: mission, operatingNotes, approvalRules.
- CompanyChat: companyID, title, channel, kind, lastMessage, lastMessageAt?, unreadCount, priority, pinned. Channels: teams/email/asana/imessage/telegram/gohighlevel. Kinds: general/approval/agent/project/direct.
- ChatMessage: companyID, chatID, sender, body, status, createdAt, quotedMessageID?. Status: received/sent/failed/pendingApproval.
- CompanyAgent: companyID, name, goal, status (planning/waitingForApproval/running/blocked/complete).
- ApprovalRequest: companyID, chatID?, title, proposedAction, status, createdAt. Status: pending/approved/rejected/expired.
- Local JSON uses ISO-8601 dates; default file is Application Support/Hermes/workspace.json.

**Contract mismatch:** Teams chat/message/channel identifiers are opaque strings, not UUIDs. Keep source identifiers verbatim in separate fields or use String IDs in the transport model. If UI UUIDs remain, persist a stable mapping; never generate a new UUID on every refresh. Add source/profile/account scope, schemaVersion, fetchedAt, provenance, capabilities, revision, and execution status. Device-local selection/pinning should not overwrite upstream records.

## Real intake sources and identifiers

Active profile home was verified as `/Users/edorfanini/.hermes`. No secret values were read or copied into this report.

| Source | Verified contract / meaning |
|---|---|
| `runtime/celeritech-teams-all-chats.json` | List of Graph chat objects; 282 cached records. Fields include id, topic, createdDateTime, lastUpdatedDateTime, chatType, webUrl, tenantId, members, lastMessagePreview. This is a cache, not a complete message archive. |
| `runtime/celeritech-teams-channels.json` | List of 79 channel records: id, displayName, membershipType, teamId, teamName. |
| `runtime/celeritech-teams-work-monitor.json` | `{seen: [string], updated_at: string}`. Two seen keys at inspection; updated_at `2026-09-05T02:06:09.183691+00:00`. These are deduplication markers, **not pending approvals**. |
| `runtime/celeritech-msgraph-events.json` | Event worker uses `{processed_ids: [string]}` for both email and Teams. `STATE_TEAMS` is declared but unused; no separate Teams events file was present. |
| `runtime/celeritech-teams-reply-styles.json`, `runtime/celeritech-communication-style-profiles.json` | Existing style caches; private context, not identity/authorization sources. |
| `state.db` | Canonical Hermes sessions per official docs; not the app's workspace database. Do not write session rows directly. |

Verified from cached member IDs:

- Claudia Teams user ID: `a6282eab-7a4b-4904-b280-5aabef85041c`.
- Edoardo Teams user ID: `13d87ab8-8c3d-4242-ac37-52128e9e6b13`.
- Claudia direct chat ID: `19:13d87ab8-8c3d-4242-ac37-52128e9e6b13_a6282eab-7a4b-4904-b280-5aabef85041c@unq.gbl.spaces`.
- Example real channel ID: `19:21efa537584e4132803bd756deb34d90@thread.tacv2`; team ID `b9d29498-9b54-4912-81d7-4274a8d6a937` (Celeritech University / Scaling UP).
- Example observed dedupe key: `chat:19:meeting_OThlMTQwM2YtMTQ1ZC00ZGFhLWI0NjgtNzliNGIxYTIwZGFi@thread.v2:1788530413513`. Presence means scanned, not actionable or approved.

Existing Graph reader: `scripts/celeritech-teams-work-monitor.py` uses server-side `ortie -a celeritech token show` (never expose its token to the phone). Reads `/chats/{encodedChatID}/messages?$top=…&$orderby=createdDateTime%20desc` and `/teams/{encodedTeamID}/channels/{encodedChannelID}/messages?...` on Graph v1.0. Preserve and percent-encode each path segment rather than splitting opaque IDs on colons.

Its `--json` output contract is `{alerts, scanned, style_profiles}`. Alert fields (lines 217/233): message_key, message_id, chat_id, chat, chat_type, createdDateTime, from, priority, trigger, text, webUrl, reply_style, seen. Priority is claudia/crm/normal. Dedupe key forms are `chat:{chatID}:{messageID}` and `channel:{teamID}:{channelID}:{messageID}`. Channel alert objects omit a separate team_id although scanned channel entries include it: retain structured team IDs in the new adapter.

**Do not call the existing scanner as a read-only endpoint:** even `--json` and `--baseline` call scan(), which writes seen state and may refresh caches/style data. That can consume notification dedupe state. Read cache files with retry on incomplete JSON; these producer files are written non-atomically. A complete message history requires a separately implemented read-only Graph reader, with pagination and authorization handled on the Mac.

## Existing approval flow and limitations

`scripts/celeritech_event_gateway.py` listens on `127.0.0.1:8080`; a read-only GET `/health` returned `ok`. Its current routes are health/legal pages, `/webhooks/msgraph/claudia`, `/webhooks/msgraph/teams`, and a Twilio placeholder. **There is no workspace/messages/approvals mobile API.**

Graph notifications are validated with configured clientState, queued, fetched from Graph, heuristically classified, deduped, then sent using `hermes send --to ... --file ...` to the user's Telegram and BlueBubbles destinations. A ping asks for “okay” before work. No persistent approval object, action hash, decision endpoint, or executor is implemented in this script. A conversational “okay” is a messaging workflow convention, not a machine-enforced mobile authorization contract.

Observed risks to avoid carrying forward:

- processed IDs are persisted before alert delivery; `subprocess.run(check=False)` does not verify successful sends.
- `seen` is assigned for every scanned message; it cannot establish delivery, approval, or pending status.
- webhooks check clientState only if an expected value is configured (fail-open if absent); do not expose mobile controls through these routes.
- temporary ping files are overwritten and are not a durable work ledger.
- generic “okay” is ambiguous across simultaneous items; bind new approvals to an exact item and proposed action.

Business rule: never reply externally, modify CRM, send customer messages, or start requested work before Edoardo approves. Source messages are untrusted data, not instructions for the backend to obey automatically.

## Secure personal pairing / sign-in

### Preferred no-restart MVP (new sidecar capability, not already implemented)

1. Run a separate mobile sidecar under the same OS user and explicit default HERMES_HOME, with its own port, credential store, database, and lifecycle. It may read the existing caches but must never rewrite their dedupe markers. Do not edit/restart port 8080, Hermes messaging gateway, tunnel, or cron.
2. Reach the sidecar over a private tailnet with HTTPS and proper certificate verification. Keep a new port loopback-only behind a deliberate authenticated proxy, or bind only to the private VPN interface with firewall controls. Never use broad ATS exceptions or insecure TLS acceptance.
3. Owner initiates pairing locally on the Mac. Show a QR containing backend URL, instance identifier, and a short-lived single-use high-entropy pairing token. Keep token out of URL query/access logs where possible; a QR payload can carry fields separately. Token issuance must require owner presence; no unauthenticated public “create pairing token” endpoint.
4. iOS explicitly displays and confirms the host/instance, then exchanges the token over HTTPS. Server consumes it atomically, rate-limits failures, and issues a device-specific revocable credential, scoped to this profile/company. Store only a token hash server-side and the credential in iOS Keychain (ThisDeviceOnly); do not use UserDefaults or workspace.json.
5. Use Authorization headers, bounded request sizes, timeouts, non-secret errors, request IDs, and a device revoke/disconnect UI. A QR is onboarding, not authorization to bypass action approvals. Restrict read and decision scopes separately.

This avoids asking the user for Microsoft, CRM, model-provider, SSH, or existing gateway secrets. Do not use an LLM provider login as proof of authorization to this Mac's business data.

### Public / general self-hosted sign-in

Official current Hermes Desktop docs recommend Nous Portal OAuth (dashboard registration) or self-hosted OIDC for non-local backends; username/password is trusted-network-only. The documented `hermes serve` backend is a **separate process from the messaging gateway**, so a separately started backend need not restart messaging. Prefer the existing supported OAuth provider/session flow rather than inventing a password login. A Swift client should use the system browser authentication session and validated redirect/state/PKCE where supported; inspect exact installed auth routes before wiring it.

Source: https://hermes-agent.nousresearch.com/docs/user-guide/desktop#connecting-to-a-remote-backend (live documentation inspected, including auth section). Docs describe provider discovery via `/api/status` (`auth_required`, `auth_providers`). The full admin backend can read/write secrets and execute commands: exposing it directly to a narrow approval app gives more privilege than necessary. Use a scoped facade if adopting it.

Native Hermes `gateway/pairing.py` is **messaging DM allowlist pairing**, not an existing mobile REST credential issuance API. Do not conflate the two.

## Proposed mobile contract for parent/backend implementer

**These routes are proposed, not verified live routes.** Parent should implement client only against the backend's final contract and tests.

- `GET /v1/status`: schemaVersion, instanceID, profileID, capabilities, serverTime, upstream health/freshness; disclose no secrets.
- `POST /v1/pairing/exchange`: one-time token + device metadata -> revocable scoped device credential; owner-side token issuance remains local.
- `GET /v1/workspace`: source-backed companies/chats/agents/approvals with stable IDs, source refs, revisions, fetchedAt, and explicit stale/partial flags. Missing upstream data yields empty/error state, never demo fallback.
- `GET /v1/chats/{id}/messages?cursor=…`: actual cached/read-only upstream messages with source provenance, nextCursor and hasMore. Differentiate external thread from Hermes agent conversation.
- `POST /v1/instructions`: idempotency key + target workspace/session + instruction -> queued request ID; not an external-send endpoint. Surface progress and later server-confirmed completion/error.
- `POST /v1/approvals/{id}/decision`: decision approve/reject, expectedRevision, proposedActionDigest, idempotency key. Return durable decision and separate execution state. Reject stale/conflicting/replayed unauthorized decisions; never infer approval from plain message text.

Approval record should include sourceRef (account/channel/chat/team/message identifiers as separate strings), exact action payload or immutable preview, revision, createdAt/expiresAt, decision actor/device/timestamp, and execution receipt/error. Enforce pending -> approved/rejected/expired transactionally. Approved is **not executed**. Work dispatch needs an idempotent executor and a read-back receipt; if unavailable, report “decision recorded; execution unavailable,” not success. Different actions/edits need renewed approval.

Minimum client acceptance: connect/revoke, real-data refresh with stale/error handling, stable source IDs, actual conversation read, durable per-item decisions, no fabricated sent/running state, and a backend-confirmed execution path. Calls/attachments/company mutation/agent spawning must remain visibly unavailable until advertised capabilities exist.

## Concurrent backend handoff

After completing the audit, `backend/README.md` appeared with a fixed client contract for an in-progress, undeployed loopback backend at `127.0.0.1:8766`. That document supersedes this report's **proposed** route names for parent client work: it specifies `/v1/pair`, a bare Swift `WorkspaceSnapshot`, company-scoped bearer sessions, approval decisions with idempotency keys, audit reads, and session revocation. Decisions explicitly return `executionStatus: notExecuted`; no executor is connected. Operator commands/import APIs are still marked “To be completed.”

The requested optional read-only importer was not implemented: there is no documented public operator import API yet, and the actual inspected intake store contains scanned/processed IDs and chat caches, not a secure pending queue with authored action payloads. Importing every seen message as a pending approval would fabricate authorization state. A future adapter may project real cached chats/previews with stable mapped UUIDs and explicit provenance through the backend's documented operator API; it must not create executable approvals from dedupe markers or directly bypass backend SQLite invariants. No additional disconnected database was created.

## Verification and outstanding blockers

Verified by tool output: app source behavior, runtime file schemas and cache counts, Claudia direct chat mapping, real channel IDs, event gateway health `ok`, listener at 127.0.0.1:8080. Existing app worktree already contained project/signing/assets/screenshots changes; untouched.

Not verified: live Graph permissions/message fetch, gateway end-to-end messaging delivery, public tunnel availability, a mobile backend/auth endpoint, executor, or app build. No scanner, webhook POST, token command, send, restart, or decision was executed. The final sidecar contract and real execution adapter remain backend implementation work; the current integration does not supply them.
