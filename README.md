# Helios Workspace

Swift company command-center app. Repository and build target retain the internal name `hermes`.

## Release status

Active production-readiness work is tracked in [release gates](Supporting/RELEASE-GATES.md), [Apple requirements](Supporting/APPLE-REVIEW-CHECKLIST.md), and the [integration audit](Supporting/INTEGRATION-AUDIT.md). The original local UI was a seeded demonstration, not a live messaging or agent execution service. A local approval decision is not proof that work was executed.

Verified App Store Connect record: `6808881436`, name **Helios Workspace**, bundle `com.prismtrade.hermes`, Prismtrade LLC team `6833T8P572`. Existing IQONIC is separate. No build has been submitted for review.

## Original demonstration scope

The demo illustrates company-scoped chats, company profiles, agent records and approval concepts. Names, org hierarchy, CEO assignments and sample conversations in seed data are illustrative and are not a verified company directory.

## MVP scope

- Multi-company data model, seeded with Celeritech first.
- Company profile with CEO, mission, operating notes, and approval rules.
- Telegram-like company chat list + message thread with composer.
- Company-scoped chat list with channel/kind metadata.
- Messages and approval requests scoped to company + chat.
- Agent structures per company.
- Visual org chart/structure in SwiftUI.
- Local-first JSON workspace database (Application Support); ready to move to SwiftData.
- iOS Xcode project generated from `project.yml`.

## Build

```bash
swift test
swift run HermesPreview
swift build --product HermesApp
xcodegen generate
xcodebuild -project Hermes.xcodeproj -scheme Hermes -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

## GitHub

Remote: https://github.com/edorfanini00/hermes

## App Store Connect

Initial App Store app records cannot be created through the official App Store Connect REST API. Apple requires creating the app record in App Store Connect web first; API/CLI automation can continue after that for Bundle IDs, versions, metadata, and uploads once credentials are available.

See `Supporting/README-AppStore.md` for exact required fields and blocker.
