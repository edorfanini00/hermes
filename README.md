# Hermes

Swift company command-center app for Edoardo/Celeritech.

MVP goal: a Telegram-like workspace where chats are grouped by company, each company has its CEO/profile, agents can be spawned per company, and the user can inspect a visual company structure before approving work.

## Current company

- Celeritech
- CEO: Edoardo Orfanini
- Manager priority: Claudia Ochoa
- Approval interfaces: Telegram + iMessage

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
