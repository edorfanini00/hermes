# App Store Connect setup

Planned app record:

- App name: Hermes
- Bundle ID: `com.edoardo.hermes`
- SKU: `hermes-ios-001`
- Platform: iOS
- Primary language: English (U.S.)
- User access: Full Access

## Exact blocker

The official App Store Connect REST API cannot create the initial app record. Apple's current API exposes `GET /v1/apps`, not `POST /v1/apps`. New app creation must start in the App Store Connect website.

After the app exists, automation can continue through API/CLI for bundle identifiers, App Store versions, metadata, screenshots, builds, and uploads.

## Required before the web creation step

- Apple Developer Program/App Store Connect account.
- Latest Apple agreements signed.
- User role: Account Holder, Admin, or App Manager.
- Bundle ID registered/matching the Xcode app: `com.edoardo.hermes`.
- Unique SKU: `hermes-ios-001`.
- App name availability confirmed by Apple.
- Signing team selected in Xcode/App Store Connect.

## Optional post-create automation credentials

- App Store Connect API key `.p8`.
- Key ID.
- Issuer ID.
- Team/provider selection if the account has multiple providers.

Do not reuse the existing IQON app record; this is a separate app.
