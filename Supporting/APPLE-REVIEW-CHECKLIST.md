# Apple review and distribution acceptance checklist

Research checked: 2026-09-05. Scope: the official Apple pages listed below, with targeted review of relevant guideline sections—not all Apple documentation. This is a release checklist, not an approval guarantee or a code/security audit. App state is supplied context: SwiftUI local demo; intended personal/business AI agent command center; initially one owner and Celeritech company data. Unchecked items are acceptance gates, not verified defects.

**Required** = explicit Apple requirement for the indicated channel/feature. **Conditional** = required if that feature/condition applies. **Recommended** = project-specific engineering or distribution advice, not a prescribed Apple implementation.

## 1. Choose an honest distribution path

- [ ] **Recommended now:** use an on-device development build for a strictly personal experiment; use **internal TestFlight for genuine beta development**, not public App Store review of the local demo. Apple explicitly directs demos/betas to TestFlight and suggests Xcode/Ad Hoc for apps meant only for family/friends.[1]
- [ ] **Required for TestFlight:** provide test information and feedback contact, upload a correctly provisioned build, and resolve applicable encryption/export-compliance questions. Internal testers must be App Store Connect users with access; Apple allows up to 100 internal or 10,000 external testers, and builds expire after 90 days.[4]
- [ ] **Conditional—external testing:** provide review access; the first external build requires Beta App Review, and subsequent builds may require review. Guideline 2.2 also calls for significant beta updates to be reviewed; a TestFlight approval is not production approval.[4][1]
- [ ] **Required boundary:** do not use TestFlight as indefinite private production distribution. Guideline 2.2 says betas should be intended for public distribution; Apple's Custom Apps documentation separately permits beta testing before custom distribution. For a Celeritech-only endpoint, describe the real destination rather than claiming a public launch just to obtain testing access.[1][6]
- [ ] **Recommended production choice:** if the audience remains Celeritech employees, prefer **Custom App** distribution to its verified Organization ID through Apple's business distribution service (Apple Business/Apple Business Manager). Private availability must be selected before approval; Custom Apps still undergo review and sensitive-data apps need sample data and authentication.[6]
- [ ] **Conditional alternative:** choose **unlisted** for a limited audience needing a direct App Store link, including unmanaged devices. It requires a final, review-submitted app and a separate request; beta/prerelease requests are declined. Anyone holding the link can download it—unlisted is not authentication. Moving an already-private app to unlisted requires a new app record.[5]
- [ ] **Recommended public-release threshold:** pursue searchable public distribution only once other users can obtain useful, supported functionality without the owner's personal access. Neither unlisted nor custom distribution makes an unfinished demo acceptable.[1][5][6]

## 2. Authentication and secure self-hosted pairing

- [ ] **Required:** implement appropriate security against unauthorized access/disclosure (1.6), and do not demand unnecessary personal information or login where significant account-based features are absent (5.1.1(v)).[1]
- [ ] **Conditional—4.8:** Sign in with Apple is **not universally mandatory**. Third-party/social login for the primary app account triggers an equivalent privacy-preserving login option, subject to exceptions. The current rule specifies limited name/email collection, private email, and no advertising-interaction collection without consent; it does not simply mandate a particular button.[1]
- [ ] **Recommended interpretation:** pairing with an existing self-hosted Hermes server can avoid introducing a new consumer identity system. Document whether it is your company's own authentication, an existing enterprise account, or direct authentication to a specific third-party service—4.8 lists these exceptions. A QR code alone does not establish an exemption; classification depends on the actual account flow. Google/Microsoft login to the app's own primary account needs reassessment, even if connectors also use OAuth.[1]
- [ ] **Recommended security gates:** authenticated TLS; short-lived, single-use pairing challenge; explicit confirmation of server identity and requested permissions; device-scoped revocable credentials stored in Keychain; no embedded owner/master token; server-side authorization and tenant isolation on every request. Test replay, expired pairing, revoked/lost device, offline server, and cross-company access failures. Sign in with Apple, if added, does not replace gateway authorization.
- [ ] **Recommended agent controls:** require explicit confirmation for external messages, destructive changes, and sensitive actions; show actual execution status and maintain redacted audit records. Do not expose an unrestricted unauthenticated agent endpoint or present simulated execution as successful live work.

## 3. Privacy and deletion

- [ ] **Required:** publish a reachable privacy policy and link it in App Store Connect and visibly inside the app. Cover collected data, collection/use, third-party protections, retention/deletion, consent withdrawal, and deletion requests (5.1.1(i)). A local-only app still needs the policy.[1][3]
- [ ] **Required for App Store submission:** complete accurate App Privacy answers covering the app and integrated third-party partners. Map messages, prompts, documents, identifiers, diagnostics, backend logs, and AI providers before selecting labels. “Self-hosted” does not automatically mean “Data Not Collected”; classify actual off-device handling under Apple's definitions.[3]
- [ ] **Conditional—third-party AI/data access:** clearly disclose where personal data is sent and obtain explicit permission **before** sharing it with third-party AI (5.1.2(i)); implement relevant system permissions and minimize access. An owner's consent does not independently establish legal authority over employee/customer data—verify Celeritech's authorization and service terms (5.2.2). ATT applies if Apple's tracking definition is met, not merely because AI or a network connection exists.[1][3]
- [ ] **Conditional—account creation:** if the app supports creating accounts, including automatic guest accounts or linked web signup, let users initiate deletion inside the app. Delete the account and associated personal data except legally retained information; deactivation, logout, or unpairing alone is insufficient. A direct deletion-page link is acceptable; ordinary apps cannot force a phone/email support flow. Explain delays/retention and confirm completion; revoke Sign in with Apple tokens if used.[1][2]
- [ ] **Recommended applicability record:** if the app solely pairs with a pre-existing server and creates no account, document that fact and the server account lifecycle in Review Notes. The account-creation trigger may then not apply; do not claim a blanket enterprise/self-hosted exemption. Distinguish **Disconnect and erase this device** from **Delete account/server data**, provide a data-deletion request route, and identify who controls business-record retention.[1][2]

## 4. Reviewer access and production completeness

- [ ] **Required:** supply full review access, an active demo account and live backend where needed, pairing instructions/sample QR, prerequisites, and a reachable contact. Review Notes must explain non-obvious features and functionality changes (Before You Submit, 2.1, 2.3.1).[1]
- [ ] **Recommended:** provide an isolated, reachable review tenant with synthetic Celeritech-like records and resettable workflows. Reviewers must not need the owner's approval, private corporate VPN, personal credentials, or access to real company secrets. Keep review access working throughout review and verify it from a fresh device/network.
- [ ] **Conditional—demo-mode substitute:** under 2.1(a), if legal/security obligations prevent a demo account, obtain Apple's **prior approval** for a built-in demo mode that exhibits full features/functionality. This reviewer-access option is not permission to ship the current mock-only product as a finished connected service.[1]
- [ ] **Required:** submit a final, stable, on-device-tested product with functional URLs, accurate metadata/screenshots, useful app functionality, and no placeholders or undocumented hidden features (2.1, 2.3, 4.2). If live Hermes control is advertised, prove a real end-to-end flow; otherwise describe only the actually delivered local functionality.[1]
- [ ] **Recommended verification pack:** record physical-device launch, pairing, authorized reads/actions, errors, persistence, consent, unpairing/deletion, accessibility, and supported iPhone/iPad layouts. Treat signing/upload/processing, Beta App Review, and production review as separate milestones. Recheck Apple's current SDK/upload, age-rating, privacy-manifest/required-reason API, and export requirements against the final binary before submission; these build-specific requirements were not fully audited here.

## 5. Messaging and user-generated content

- [ ] **Conditional—actual shared messaging/UGC:** implement objectionable-content filtering, offensive-content reporting with timely response, abusive-user blocking, and published contact information (1.2). Private business distribution is not a stated blanket exemption; evaluate connected messaging services as actually exposed in the app.[1]
- [ ] **Recommended scope distinction:** owner-only private agent prompts and local fixture conversations are not automatically a social network. Document whether users can share/post content or message other humans. If shared features are absent, say so; if present, demonstrate moderation/report/block behavior rather than labeling all messages “AI” to evade assessment. Deleting an account also implicates its shared UGC, subject to legally required retention.[2]

**Release decision:** the supplied local-demo state supports continued development/beta evaluation, not a claim of production readiness. Resolve distribution audience, real authentication/data flows, deletion applicability, reviewer access, and implemented messaging scope before marking these gates complete.

## Sources

[1] https://developer.apple.com/app-store/review/guidelines
[2] https://developer.apple.com/support/offering-account-deletion-in-your-app
[3] https://developer.apple.com/app-store/app-privacy-details
[4] https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview
[5] https://developer.apple.com/support/unlisted-app-distribution
[6] https://developer.apple.com/custom-apps
