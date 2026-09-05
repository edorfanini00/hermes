# Helios release gates

App Store Connect record: 6808881436 (created initially as Koryn).
Bundle ID: com.prismtrade.hermes. Team: Prismtrade LLC / 6833T8P572.
Repository remains hermes. Display name: Helios. App Store name: Helios Workspace (saved and verified after reload). Bare Helios name was rejected by Apple as already used.

## Upload verification
Xcode Organizer reports `App upload complete: Hermes 1.0 (1) uploaded` for the connected archive, bundle `com.prismtrade.hermes`, under Prismtrade LLC. CLI upload failed with an App Store Connect credentials error; Organizer succeeded without reauthentication. Remote App Store Connect TestFlight readback confirms Version 1.0, Build (1), status Processing, created Sep 5, 2026 1:37 AM. Upload is verified remotely. Build 1.0 (1) subsequently appeared in Add Build, was selected and saved, and the App Store version Build table was read back after reload showing build 1 / version 1.0. The version remains Prepare for Submission. App Privacy readback shows an empty Privacy Policy URL and Get Started (questionnaire not completed). Testing availability and review submission remain unverified.

## Current scope
Tailscale/private VPN setup is deferred by the owner to a future update. It is installed but its private connection is not verified. Do not treat deferral as a working backend or remove HTTPS/authentication safeguards. The current app still requires a compatible reachable HTTPS server; a public release needs working reviewer access or a separately implemented useful offline experience.

## Distribution decision
Owner requests full public App Store submission, not an upload-only or TestFlight-only handoff. Launch choices: free, United States only; public support contact info@iqonhealth.com. Native App Store Connect readback verifies United States as the sole territory, Available on App Release, and Current Price for United States (USD) is $0.00. Support contact is authorized but not yet published as a support URL.

Owner clarified the required product: sign in/connect to their existing Hermes and chat as in Telegram. They did not select an offline replacement. The existing read-only pairing build does not meet this requirement. Complete real authenticated chat, off-device access and isolated reviewer access before uploading a replacement and submitting. Keep production company data and privileged tools inaccessible to reviewers. A successful build/archive is not an operational integration or release approval.

## Must pass before owner beta
- Production entry point requires explicit pairing; demo content is labeled and isolated.
- Device credentials live in Keychain; pairing credentials expire and cannot be replayed.
- Authenticated data is scoped to the paired company, including direct object requests.
- Actual imported work items retain provenance and timestamps; empty data is not replaced by invented activity.
- Approval payload shows exact proposed action; recording consent never implies execution.
- Persistent database survives process restart; request retries cannot duplicate a decision.
- Disconnect revokes remote access and removes device credentials.
- Stable HTTPS endpoint, service supervision, backups and tested restoration exist before off-device use.
- Existing Telegram/iMessage/Teams gateway remains unaffected.
- Swift unit tests, HTTP/database tests, signed iOS archive and distribution export pass.
- Physical-device pairing, reconnect, expired session, offline/error and approval acceptance tests pass.

## Must pass before public App Review
- Authenticated app works for reviewer without exposing the owner's real business data.
- Public privacy/support URLs reflect actual hosted services, retention, deletion, operators and contact details.
- App privacy labels, encryption declarations, age rating, category and screenshots match implementation.
- Every displayed control works; no unfinished placeholder destinations in production.
- Account deletion path exists if accounts are created; device unlinking is not misrepresented as account deletion.
- Company-data access and third-party integration authorization are documented.
- App Store name saved successfully; build selected, metadata complete, explicit submission response and status verified.

## Execution safety
The initial API records approval decisions only. External tool execution must remain disabled until a separate executor enforces owner/company authorization, immutable action payload/version binding, expiry, idempotency, audit events, and provider-result verification. Generic approval must never grant arbitrary code execution.
