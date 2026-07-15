# CLAUDE.md

Guidance for AI agents working in this repository.

## Project map

Sports Tracker — a SwiftUI iOS app recording sport performances to local storage (SwiftData) or a backend (Firebase Firestore), per record. Layout:

- `SportsTracker/` — Xcode project + app target: composition root only (`DI/` FactoryKit registrations, `Navigation/` router + screen factory, Firebase bootstrap).
- `Modules/Core` — shared utilities package; Apple frameworks only.
- `Modules/SportRecord` — the feature package, layered `Domain/` `Data/` `Presentation/`.
- `docs/` — `ARCHITECTURE.md` (deep dive) and `superpowers/` (dated design specs and implementation plans).

## Commands

Build the app (repo root; expect `** BUILD SUCCEEDED **`):

```bash
xcodebuild build -project SportsTracker/SportsTracker.xcodeproj -scheme SportsTracker -destination 'generic/platform=iOS Simulator'
```

Test a package (run from the package directory, not the repo root):

```bash
cd Modules/SportRecord   # or Modules/Core
xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'   # scheme Core for Modules/Core
```

Destination notes: with several simulator runtimes installed, a bare device name is ambiguous — keep the `OS=` qualifier (`xcrun simctl list devices available` shows what exists). The app scheme needs an iOS 18.6+ destination; the packages accept iOS 18.0+.

## Architecture rules

- Dependency direction is `App → SportRecord → Core` — never reversed; inside the feature, `Presentation → Domain ← Data`.
- Domain imports neither Firebase nor SwiftData; domain types stay `Sendable` value types.
- New UI is SwiftUI only — no Storyboards, no XIBs, no UIKit view controllers.
- ViewModels are `@MainActor @Observable`, constructor-injected, and built only in `ScreenFactory` — never resolved from the container inside a view or registered as singletons.
- Screens receive navigation as injected closures; only the app target knows `AppRouter`.
- DI registrations live in `SportsTracker/SportsTracker/DI/Container+SportRecord.swift`.
- New files go into the layer folders mapped in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) ("Folder organization"); tests mirror the source layout.

## Conventions

- **Swift Testing** (`import Testing`, `@Test`, `#expect`) — not XCTest. Fakes live in `Modules/SportRecord/Tests/SportRecordTests/Support/Fakes.swift`; append, don't overwrite.
- Swift 6 strict concurrency must stay warning-free (`@ModelActor` for SwiftData I/O, `Sendable` across boundaries).
- Typed throws for domain failure modes (see `SportRecordsDeleteError`).
- Conventional commits scoped as in history: `feat(sportrecord):`, `feat(app):`, `refactor(sportrecord):`, `docs:`, `chore(sportrecord):`.

## Gotchas

- `FirebaseApp.configure()` must run before the DI container is first touched (it happens in `SportsTrackerApp.init`); keep it that way.
- `GoogleService-Info.plist` and `Package.resolved` are **intentionally committed** (zero-setup clone) — do not gitignore or delete them.
- `Route` is an uninhabited enum until the first push destination exists — the first push adds an enum case plus a `.navigationDestination` branch in `AppFlowView`.
- A record's `storageType` is stamped by the data source, never persisted — don't add it to `SportRecordModel` or `SportRecordDTO`.

## Further reading

- [README.md](README.md) — assignment, setup, navigation rationale.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — modules, layers, data flow, DI, concurrency, testing.
- [docs/superpowers/](docs/superpowers/) — design history: dated specs and plans per iteration.
