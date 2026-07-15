# Sports Tracker

A SwiftUI app for recording sport performances. Each record is saved — at the user's choice — to a local database (SwiftData) or to a backend (Firebase Firestore), and the records list merges both stores into a single, filterable overview.

## The Assignment

Build a simple mobile app that records sport performances and stores them on a backend or in a local database, per the user's choice, with two screens:

1. **Add a sport record** — enter a name, a location and a duration, choose the target storage (local database or backend), and save.
2. **List sport records** — show the saved records filtered by **All | Local | Remote**, with items color-coded by storage type.

Additional constraints: design the navigation flow and justify the choice; no Storyboards or XIBs; correct behaviour in both portrait and landscape; a unified architecture across the whole project.

### Requirements checklist

| Requirement | Implementation |
|---|---|
| Name input | "Activity" section of [`AddRecordView`](Modules/SportRecord/Sources/SportRecord/Presentation/AddRecord/View/AddRecordView.swift); validation in [`AddRecordViewModel`](Modules/SportRecord/Sources/SportRecord/Presentation/AddRecord/ViewModel/AddRecordViewModel.swift) |
| Location input | same form section, same validation |
| Duration input | wheel-based [`DurationPicker`](Modules/SportRecord/Sources/SportRecord/Presentation/AddRecord/View/DurationPicker.swift) (hours / minutes / seconds) |
| Local database / backend choice | "Storage" menu picker bound to [`StorageType`](Modules/SportRecord/Sources/SportRecord/Domain/Entities/StorageType.swift) |
| Save to the chosen storage | [`SaveSportRecordUseCase`](Modules/SportRecord/Sources/SportRecord/Domain/UseCases/SaveSportRecordUseCase.swift) → [`DefaultSportRecordRepository`](Modules/SportRecord/Sources/SportRecord/Data/Repositories/DefaultSportRecordRepository.swift) routes the record by its storage type |
| List filtered by All / Local / Remote | segmented control in [`RecordsListView`](Modules/SportRecord/Sources/SportRecord/Presentation/List/View/RecordsListView.swift); pure in-memory filtering in [`RecordsListViewModel`](Modules/SportRecord/Sources/SportRecord/Presentation/List/ViewModel/RecordsListViewModel.swift) — switching segments never refetches |
| Color-coded by storage type | [`StorageType+Style`](Modules/SportRecord/Sources/SportRecord/Presentation/Shared/StorageType+Style.swift) — local records are blue, remote records purple |
| No Storyboards / XIBs | 100% SwiftUI; the app enters at [`SportsTrackerApp`](SportsTracker/SportsTracker/SportsTrackerApp.swift) |
| Portrait + landscape | adaptive SwiftUI layout (`List`, `Form`) — no orientation-specific code |
| Unified architecture | MVVM + Clean Architecture in every layer — see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Navigation flow designed & justified | [below](#navigation-flow--and-why) |

## Getting Started

**Prerequisites:** Xcode 26+. The app targets **iOS 18.6**; the packages support iOS 18.0+. Nothing else — no accounts, keys, or setup scripts.

```bash
git clone <repo-url>
open sports-tracker/SportsTracker/SportsTracker.xcodeproj
```

Select the **SportsTracker** scheme and an iOS 18.6+ simulator, then Run.

The repository is deliberately **zero-setup**:

- the Firebase configuration (`GoogleService-Info.plist`) is committed,
- dependency versions are pinned by the committed `Package.resolved` — Swift Package Manager resolves everything on first open.

### Command line

Common tasks are wrapped in a [`Makefile`](Makefile) (run from the repo root):

| Command | Does |
|---|---|
| `make build` | Build the app |
| `make test` | Run both package test suites |
| `make lint` | Lint with the SwiftLint CLI |
| `make format` | Format sources in place with swift-format |
| `make format-check` | Verify formatting without writing (fails on diffs) |
| `make ci` | `format-check` → `lint` → `build` → `test` |

`make build` expects `** BUILD SUCCEEDED **`; `make test` runs `make test-core` and `make test-sportrecord` (invoke either alone for one package). Linting also runs automatically at build time via the SwiftLint SPM plugin (pinned to 0.65.0). `make lint` additionally needs the SwiftLint CLI (`brew install swiftlint`); formatting uses the `swift format` bundled with the Xcode toolchain.

The targets wrap `xcodebuild` with `-skipPackagePluginValidation` (which stops the SwiftLint build-tool plugin from prompting for trust in non-interactive runs) and pin the test simulator to `iPhone 16 Pro, OS=18.5`. To target a different simulator, override `BUILD_DEST` / `TEST_DEST` in the [`Makefile`](Makefile) — any installed iOS 18+ simulator works (`xcrun simctl list devices available`); keep the `OS=` qualifier, since a bare device name is ambiguous and `xcodebuild` rejects it.

## Navigation Flow — and Why

The app is a single `NavigationStack` whose root is the **records list**; **adding a record is a modal sheet** presented on top of it.

- **List as home.** The user's data is the app's centre of gravity: reviewing records is the frequent action, adding one is the occasional action. Landing on the list gives immediate value on every launch — the same shape Apple's own data-collection apps (Health, Reminders, Calendar) use.
- **Add as a sheet.** Creating a record is a short, self-contained task with a clear finish-or-cancel contract — exactly what the Human Interface Guidelines recommend a sheet for (HIG: [Modality](https://developer.apple.com/design/human-interface-guidelines/modality)). The list stays visible beneath the sheet as context, and the sheet dismisses cleanly in both orientations.
- **HIG-consistent details.** `Cancel` and `Save` sit in the sheet's `.cancellationAction` / `.confirmationAction` toolbar placements and `Save` stays disabled until the form is valid; interactive dismissal is blocked only while a save is in flight. On the list, the destructive batch delete is guarded by a confirmation dialog (swipe-to-delete needs none — the gesture is its own confirmation), editing follows the standard Edit/Done pattern with a contextual bottom-bar action, and the storage filter is a segmented control switching mutually exclusive views.
- **Explicit return path.** The sheet reports success through an injected `onSaved` closure that reloads the list — a visible data-flow seam instead of hidden shared state.

The navigation infrastructure (router, flow view, screen factory) lives entirely in the app target; feature screens receive navigation as closures and never know a router exists — see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Beyond the Assignment

- **Offline awareness** — an `NWPathMonitor`-backed banner ("You're offline — showing local records").
- **Partial-failure-aware fetch** — the stores are read concurrently; one failing store never hides the other store's records, and the failure drives an in-list banner instead.
- **Local-first progressive loading** — local records paint immediately; the merged local + remote result follows.
- **Partial-failure-aware delete** — batch deletes are routed per store and commit independently; a typed error reports exactly which store failed, and only those rows are kept.
- **Pull-to-refresh** on every segment of the list, including empty ones, plus an automatic refresh when the app returns to the foreground.
- **Edit mode** with multi-select and confirmed batch delete; swipe-to-delete outside edit mode.
- **Per-segment empty states** and a global "add your first activity" empty state.
- **Unit tests across all layers** (Swift Testing) — data sources run against an in-memory SwiftData container; deletes are covered by a full local/remote combination matrix.

## Project Structure

```
├── SportsTracker/              # Xcode project + app target (composition root)
│   └── SportsTracker/
│       ├── DI/                 # FactoryKit container registrations
│       └── Navigation/         # AppRouter, AppFlowView, ScreenFactory
├── Modules/
│   ├── Core/                   # shared utilities (Apple frameworks only)
│   └── SportRecord/            # the feature package (Domain / Data / Presentation)
└── docs/
    ├── ARCHITECTURE.md         # architecture deep dive
    └── superpowers/            # design specs & implementation plans (project history)
```

Further reading:

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — modules, layers, folder organization, data flow, DI, concurrency, testing.
- [docs/superpowers/](docs/superpowers/) — dated specs and plans documenting how each iteration was designed and built.
