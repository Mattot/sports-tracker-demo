# CLAUDE.md

Guidance for AI agents working in this repository.

## Project map

Sports Tracker — a SwiftUI iOS app recording sport performances to local storage (SwiftData) or a backend (Firebase Firestore), per record. Layout:

- `SportsTracker/` — Xcode project + app target: composition root only (`DI/` FactoryKit registrations, `Navigation/` router + screen factory, Firebase bootstrap).
- `Modules/Core` — shared utilities package; Apple frameworks only.
- `Modules/SportRecord` — the feature package, layered `Domain/` `Data/` `Presentation/`.
- `docs/` — `ARCHITECTURE.md` (deep dive) and `superpowers/` (dated design specs and implementation plans).

## Commands

The [Makefile](Makefile) is the task runner (repo root):

```bash
make build          # build the app; expect ** BUILD SUCCEEDED **
make test           # both package suites (make test-core / make test-sportrecord for one)
make lint           # SwiftLint CLI over the repo
make format         # swift-format the sources in place
make format-check   # verify formatting without writing; make ci runs the full pipeline
```

These wrap `xcodebuild` / `swiftlint` / `swift format` and pass `-skipPackagePluginValidation`, which stops SwiftLint's build-tool plugin from prompting for trust in non-interactive runs. For a different simulator, override `BUILD_DEST` / `TEST_DEST` in the Makefile or call `xcodebuild` directly.

SwiftLint (SimplyDanny/SwiftLintPlugins, pinned 0.65.0) also runs as an SPM build-tool plugin on the `Core` and `SportRecord` source targets on every build; the shared ruleset is `.swiftlint.yml` at the repo root, inherited per package via `parent_config`. Formatting is Apple `swift-format` (`.swift-format`).

Destination notes: the Makefile pins tests to `iPhone 16 Pro, OS=18.5`, and the app scheme needs an iOS 18.6+ destination (packages accept iOS 18.0+). With several simulator runtimes installed a bare device name is ambiguous — keep the `OS=` qualifier (`xcrun simctl list devices available` shows what exists).

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
