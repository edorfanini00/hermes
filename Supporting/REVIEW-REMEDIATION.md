# September 14 review remediation — version 1.1 (7)

Submission: cfe8d3c6-98d6-42bc-9ac4-ed9a72acf5b0.
The rejection supplied by the owner supersedes the older submission status in README and RELEASE-GATES. Main already contained build 8 changes. Build settings now consistently target 1.1 (9); it is not uploaded.

## Code changes

- Pair is actionable when fields are incomplete and reports validation errors instead of silently staying disabled. It is disabled only during a request; the button displays progress.
- Whitespace is trimmed from pasted URLs/codes. Empty codes never reach the network. Duplicate pairing tasks are ignored. Codes survive transport failures and are cleared after successful pairing.
- Requests have bounded network timeouts, actionable connectivity errors, and readable invalid-response errors. HTTPS and redirect protections remain intact.
- Removed the hardcoded temporary tunnel/demo credential shortcut. Its removal does not resolve reviewer access; a working review service remains a release blocker.
- Onboarding uses Dynamic Type, persistent field labels, larger hit targets, stronger text contrast, a content-sized dark header, and a centered maximum width on iPad. Live workspace captions were enlarged; approval controls can stack vertically.
- Errors appear in a system alert so keyboard/scroll position cannot hide them. Expired/revoked sessions return to pairing. Failed connections offer explicit local removal, explaining that this does not revoke the remote session.
- Fixed Xcode test-module imports, added iPad/iPhone UI checks, and added a macOS CI workflow that generates the project and saves test evidence.

## Distribution — still unresolved

Do not resubmit while an unlisted request is pending, per Apple's rejection.
Confirm whether the owner already requested unlisted distribution and its result.
If this remains a limited-business app, unlisted distribution permits a direct App Store download link on managed and unmanaged devices. Custom App distribution is another option for identified organizations. If pursuing public distribution, demonstrate a genuine supported audience beyond the specific business; do not simply change the wording to claim this.

Official source: https://developer.apple.com/support/unlisted-app-distribution/
No distribution settings or review messages were changed by this patch.

## Required before resubmission

- Provision a stable HTTPS review service with synthetic isolated data, available throughout review. A temporary tunnel and a five-minute single-use code are insufficient for unattended repeat review. Do not weaken production pairing rules or embed production credentials.
- Supply working reviewer access and exact steps in App Store Connect. Test a fresh install and repeat access without operator intervention. Removing a demo shortcut is not a substitute for working reviewer access.
- On a Mac, run Swift tests with the package's required toolchain and build the iOS target. On iPad (including the review OS) and iPhone test blank fields, URL only, invalid URL/code, unavailable server, successful pairing, relaunch, refresh, and revocation.
- Check portrait, landscape, narrow split view, keyboard presentation, VoiceOver, and largest accessibility text sizes. Confirm errors and progress remain visible and controls remain usable.
- Increment the build number consistently, archive, upload, and select the new build only after device acceptance. Do not claim these checks passed from a Linux source review.

## Verification for this patch

Swift regression tests added for empty codes, pasted whitespace, HTML/non-API responses, and timeout messages. Swift/Xcode execution and device visual verification are unavailable in the current Linux environment. Backend test outcome is recorded in the accompanying change summary.


## Reviewer service handoff

The backend already supports `pair-code --review` for reusable credentials with a maximum 90-day lifetime and 30-day device sessions. Use only an isolated database seeded from `backend/review_tenant.json`. Normal production codes remain single-use with a maximum five-minute lifetime. Review credentials are not embedded in the app or committed to GitHub.

The operator must put the review backend behind a stable HTTPS endpoint with a valid certificate and keep it running throughout review. Once that origin exists, run `python3 scripts/check_review_access.py https://YOUR-STABLE-HOST` and enter the synthetic review code at its hidden prompt. The script refuses non-HTTPS origins and redirects, pairs twice, verifies company scope and revokes each test session. It never makes approval decisions.

Provide that tested origin and the review code in App Store Connect's private review-access fields. Instructions: enter the Server URL, enter the Access code, tap Pair securely, inspect chats/agents/approval records, and use Revoke session & disconnect when finished. Do not submit placeholder hosts or claim that the old temporary tunnel is production hosting.

Local verification: all 11 backend tests passed after these changes. Mac-hosted build/UI verification is tracked by the PR's iOS review checks. No signed archive, upload, production hosting, or Apple distribution outcome is claimed by this document.
