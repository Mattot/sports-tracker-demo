# Project Documentation — Design

**Date:** 2026-07-15
**Scope:** Add project documentation: a root `README.md`, a `docs/ARCHITECTURE.md` deep dive, and a root `CLAUDE.md` for AI agents. No code changes.

---

## 1. Goals

- A reviewer opening the repo understands within a minute what the app is, what the assignment required, and how each requirement is met.
- A developer can clone, build, run, and test with zero configuration steps beyond having Xcode.
- The navigation-flow rationale (an explicit assignment deliverable) is written down.
- AI agents get a terse operational guide: verified commands, hard architectural rules, and gotchas.

Decisions already made with the user:

- **Structure:** `README.md` + separate `docs/ARCHITECTURE.md` (README stays skimmable; architecture gets room to go deep). `CLAUDE.md` at the repo root.
- **Assignment presentation:** English paraphrase of the brief plus a requirements checklist mapping each requirement to its implementation, with file links.
- **CLAUDE.md tone:** tool-agnostic — commands, rules, and pitfalls; it points to `docs/` for background but does not prescribe a workflow.
- **No screenshots** — the repo stays lean; a reviewer runs the app.
- All documents state current reality only: no roadmap or aspirational sections.

---

## 2. README.md

Sections, in order:

1. **Title + pitch.** "Sports Tracker" — a SwiftUI app that records sport performances and stores each record, at the user's choice, in a local database (SwiftData) or on a backend (Firebase Firestore).
2. **The assignment.** A short English paraphrase of the brief: two screens (add a record; list records), user-chosen storage per record, filterable list, and the mandated constraints.
3. **Requirements checklist.** A table or checklist mapping every requirement to how and where it is implemented, with clickable relative file links:
   - Add screen: name input, location input, duration input, storage picker, save → `AddRecordView` / `AddRecordViewModel` / `SaveSportRecordUseCase`.
   - List screen: All | Local | Remote filter, color-coded rows → `RecordsListView` / `RecordsListViewModel` / `StorageType+Style`.
   - No Storyboards/XIBs → pure SwiftUI, `@main` app entry.
   - Portrait + landscape → standard adaptive SwiftUI layout.
   - Unified architecture → MVVM + Clean Architecture everywhere (link to ARCHITECTURE.md).
   - Navigation flow designed and justified → README's own navigation section.
4. **Getting started.** Prerequisites (Xcode version, iOS 18 SDK); clone → open `SportsTracker/SportsTracker.xcodeproj` → run. State explicitly that the repo is deliberately zero-setup: the Firebase configuration plist and `Package.resolved` are committed, so no account setup, no key generation, no dependency step. Include the command(s) to run the test suites; every command must be verified working before it is written into the document.
5. **Navigation flow & rationale.** The assignment asks not only for a flow but for its justification. Content: the records list is the root screen (the user's data is the app's home; the most frequent action is reviewing records); adding a record is a modal sheet (a short, self-contained create task — modality signals "finish or cancel", keeps the list visually underneath as context, and dismisses cleanly in both orientations); the sheet returns via an `onSaved` callback that triggers a list reload (explicit data-flow seam instead of shared mutable state). Mention the router/screen-factory infrastructure in one sentence and defer detail to ARCHITECTURE.md.
6. **Beyond the assignment.** Bullet list of the extras implemented: offline detection with a banner; partial-failure-aware fetch (one store failing never hides the other store's records); partial-failure-aware batch delete with per-store routing; pull-to-refresh; refresh on returning to foreground; local-first progressive loading; edit mode with multi-select batch delete; swipe-to-delete; per-segment empty states; unit-test suite across all layers.
7. **Project structure & further reading.** A short tree of the repo layout; links to `docs/ARCHITECTURE.md` and to `docs/superpowers/` (specs and plans that document the design history of each iteration).

## 3. docs/ARCHITECTURE.md

Sections, in order:

1. **Module overview.** Diagram (mermaid or ASCII) of `App → SportRecord → Core` and each module's contract:
   - `Core` — Apple frameworks only; cross-cutting utilities (network monitoring, design-system primitives, logging).
   - `SportRecord` — the feature package, layered internally; imports Core, SwiftData, FirebaseFirestore.
   - `App` (SportsTracker target) — composition root; the only place concrete types, DI registrations, Firebase bootstrap, and navigation wiring meet.
2. **Layers inside SportRecord.** Domain / Data / Presentation with the dependency rule (Presentation → Domain ← Data; Domain imports neither Firebase nor SwiftData). Key types per layer: entities (`SportRecord`, `StorageType`, `SportRecordsFetchResult`, `SportRecordsDeleteError`), repository protocol + use cases; data sources (SwiftData `@ModelActor` local, Firestore remote) + `DefaultSportRecordRepository`; ViewModels + views. Explain why `storageType` is stamped at the data-source boundary instead of being persisted (origin can never drift from the store the record actually lives in).
3. **Data-flow walkthroughs.**
   - Fetch: both stores queried concurrently, results merged and sorted, failures collected in `failedStores` so a single-store outage still shows the other store's data and drives the banner.
   - Delete: records grouped by storage type, routed to their store, each store commits independently; typed throws (`SportRecordsDeleteError`) names exactly which store(s) failed so the ViewModel keeps only the failed rows.
   - Save: routed to the chosen store by the repository.
4. **Navigation.** `AppRouter` (`Route` push stack — currently uninhabited — and `Sheet` modals), `AppFlowView` owning the `NavigationStack`, `ScreenFactory` as the composition point building View + ViewModel pairs. Screens receive navigation as injected closures and never see the router; the feature package stays navigation-agnostic.
5. **Dependency injection.** FactoryKit registrations and scope choices (singletons for the model container, data sources, repository, network monitor; cached use cases; ViewModels never container-managed — fresh per screen, constructor-injected).
6. **Concurrency.** Swift 6 strict concurrency: `Sendable` domain values, `@ModelActor` isolating SwiftData's non-Sendable `ModelContext`, `@MainActor @Observable` ViewModels, typed throws for the delete failure mode.
7. **Testing.** Swift Testing (not XCTest); protocol fakes for data sources, use cases, and the network monitor; real in-memory `ModelContainer` for local data-source tests; ViewModel tests cover state transitions and the delete partial-failure matrix. How to run the suites (same verified commands as the README).

## 4. CLAUDE.md

Terse and imperative; states current reality. Sections:

1. **Project map.** One paragraph: what the app is; where things live (`SportsTracker/` app target + xcodeproj, `Modules/Core`, `Modules/SportRecord`, `docs/`).
2. **Commands.** Build and test commands, each verified working before being written down (expected shape: `xcodebuild` with a simulator destination for the app; per-package test runs also need an iOS simulator destination because the packages declare `platforms: [.iOS(.v18)]` — plain `swift test` on the macOS host will not work).
3. **Architecture rules.** Dependency direction `App → SportRecord → Core` — never reversed; Domain imports no Firebase/SwiftData; new UI is SwiftUI only (no Storyboards/XIBs); ViewModels are constructor-injected and built only in `ScreenFactory`; screens receive navigation as closures, never the router; DI registrations live in `Container+SportRecord.swift`; domain types stay `Sendable` value types.
4. **Conventions.** Swift Testing for all tests; conventional commits with scope matching existing history (`feat(sportrecord):`, `fix(app):`, `docs:`, …); typed throws pattern for domain errors; Swift 6 strict concurrency must stay warning-free.
5. **Gotchas.** `FirebaseApp.configure()` must run before the DI container is first touched; `Package.resolved` and the Firebase plist are intentionally committed (zero-setup clone) — do not gitignore them; `.swiftpm/` and `xcuserdata/` are ignored; `Route` is an uninhabited enum until the first push destination exists.
6. **Further reading.** Links to `README.md`, `docs/ARCHITECTURE.md`, and `docs/superpowers/` specs/plans.

## 5. Constraints

- Documentation only — no source, project, or configuration changes.
- Every command written into any document must be executed and confirmed working first.
- Every file link must point at a path that exists.
- Facts must be checked against the code as it is now (not against earlier specs — details have evolved across iterations).

## 6. Testing / acceptance

- All commands in the docs run successfully as written.
- All relative links resolve (spot-check via the files' existence).
- README requirements checklist covers every bullet of the assignment brief.
- CLAUDE.md contains no instruction that contradicts the code or the README.
