# Sport Record List — Iteration 1 Design

**Date:** 2026-07-13
**Scope:** Iteration 1 of the Sports Tracker iOS app — the **records list** screen only, built bottom-up: Domain → Data → Presentation. The add-record screen is iteration 2 and is out of scope here (only the navigation seam for it is wired).

---

## 1. Context & assignment

Test assignment: a simple app that records sport performances and stores them either locally or on a backend, per the user's choice. Two screens — add and list. Mandated constraints:

- No Storyboards / XIBs.
- Must work in **portrait and landscape**.
- Unified architecture across the project.
- List screen: show items filtered by **All | Local | Remote**, color-coded by storage type.
- Design *and justify* the navigation flow.

Because it is a test task ("further development to show your abilities is welcome"), deliberately demonstrating a clean layered architecture is a positive, not over-engineering.

### Locked platform / architecture decisions

- **Target:** iOS 18.0+, **Swift 6** (strict concurrency).
- **Patterns:** MVVM + FlowRouter navigation + Clean architecture.
- **Storage:** SwiftData (local) + Firestore/Firebase (remote, already set up; `GoogleService-Info.plist` provided in the App target).
- **Modules:** local SPM packages — `Core` and `SportRecord` (feature).
- **Dependency direction:** `App → SportRecord → Core`. The feature is "dumb": navigation is expressed as view callbacks and wired in App.
- **DI:** Factory library, with scopes.
- **View + ViewModel** built in `ScreenFactory`; **ViewModel receives dependencies via its constructor.**
- Navigation infrastructure (`AppRouter`, `Sheet`, `Route`, `AppFlowView`, `ScreenFactory`) follows the provided template; the list presents the add screen as a **sheet**.

---

## 2. Module & layer layout

### `Core` (imports only Apple frameworks — no Firebase/SwiftData)

- `NetworkMonitor` — protocol + `NWPathMonitor`-backed impl exposing observable `isOnline`. Cross-cutting; reusable by any future feature.
- Design-system primitives that are genuinely generic: storage-type color tokens, a reusable `MessageBanner`, and a `ContentStateView` (loading / empty / error-with-retry scaffolding).
- Optional shared `AppError` / error-mapping helpers.

### `SportRecord` (feature — imports `FirebaseFirestore`, `SwiftData`, `Core`)

```
SportRecord/
├── Domain/
│   ├── SportRecord.swift              // entity (Sendable value type)
│   ├── StorageType.swift              // .local / .remote
│   ├── SportRecordRepository.swift    // protocol
│   └── UseCases/
│       ├── FetchSportRecordsUseCase.swift
│       └── DeleteSportRecordsUseCase.swift
├── Data/
│   ├── Local/
│   │   ├── SportRecordModel.swift              // @Model
│   │   ├── SwiftDataSportRecordDataSource.swift// @ModelActor, LocalSportRecordDataSource
│   │   └── SportRecordModel+Mapping.swift
│   ├── Remote/
│   │   ├── SportRecordDTO.swift                // Codable Firestore shape
│   │   ├── FirestoreSportRecordDataSource.swift// RemoteSportRecordDataSource
│   │   └── SportRecordDTO+Mapping.swift
│   └── DefaultSportRecordRepository.swift
└── Presentation/
    ├── RecordsListState.swift
    ├── RecordsListViewModel.swift
    └── RecordsListView.swift (+ SportRecordRow, state/banner subviews)
```

### `App`

- `FirebaseApp.configure()` at launch (before the DI container is first touched).
- Factory registrations, `ScreenFactory`, `AppRouter`, `AppFlowView`.
- Only place that references concrete types.

**Dependency arrows:** `App → SportRecord → Core`; inside the feature `Presentation → Domain ← Data` (Data implements Domain's protocols; Presentation consumes Domain's use cases). Nothing in Domain imports Firebase or SwiftData.

---

## 3. Domain layer

All domain types are `Sendable` value types.

```swift
struct SportRecord: Identifiable, Equatable, Sendable {
    let id: UUID              // stable identity; also the Firestore document ID
    let name: String
    let location: String
    let duration: TimeInterval   // seconds; formatted only in presentation
    let storageType: StorageType
    let createdAt: Date          // sort key — newest first
}

enum StorageType: Sendable { case local, remote }
```

- `id` is a `UUID` generated on save (iteration 2), reused verbatim as the Firestore document ID and stored on the SwiftData model — one stable identity across both stores.
- `storageType` is **not persisted**. Each data source stamps it at the boundary (local source → `.local`), so it can never drift from the record's true origin.
- `All | Local | Remote` is a **filter**, not a storage type; it lives in presentation as `RecordsFilter`.

### Fetch result (partial-failure aware)

```swift
struct SportRecordsFetchResult: Sendable {
    let records: [SportRecord]         // merged, sorted by createdAt desc
    let failedStores: Set<StorageType> // e.g. [.remote] when only remote failed
}
```

Chosen over a throwing fetch so that a single-store failure still returns the other store's records **and** carries the failure signal for banners. The banner therefore reads two orthogonal signals: `NetworkMonitor.isOnline` ("You're offline — showing local records") and `failedStores.contains(.remote)` while online ("Couldn't reach remote — showing local records").

### Repository protocol (coordinating)

```swift
protocol SportRecordRepository: Sendable {
    func fetch() async -> SportRecordsFetchResult        // async-let both stores, merge, sort, collect failedStores
    func delete(_ records: [SportRecord]) async throws   // group by storageType, dispatch to each source
}
```

The repository owns multi-store coordination: concurrency + partial-failure policy for fetch, and group-by-`storageType` routing for delete.

### Use cases (thin domain seams, `execute()`)

```swift
protocol FetchSportRecordsUseCase: Sendable {
    func execute() async -> SportRecordsFetchResult
}
protocol DeleteSportRecordsUseCase: Sendable {
    func execute(_ records: [SportRecord]) async throws
}
```

Use cases pass through to the repository. They carry little logic today but keep the ViewModel off the repository, give Clean its layer, and are where future rules (validation, analytics, permissions) would land. Kept for architectural consistency.

**Filtering stays out of the domain** — because all data is loaded once and filtered in memory, filtering is a pure presentation derivation, not a use case.

---

## 4. Data layer

Swift 6 note: `SwiftData.ModelContext` is not `Sendable`; the local data source is a `@ModelActor` so its context is actor-isolated and local I/O runs off the main actor without data races. Only `Sendable` domain values cross the actor boundary.

### Per-store data sources (both protocols, for fakeability)

```swift
protocol LocalSportRecordDataSource: Sendable {   // impl: SwiftDataSportRecordDataSource (@ModelActor)
    func fetch() async throws -> [SportRecord]
    func delete(ids: [UUID]) async throws
}
protocol RemoteSportRecordDataSource: Sendable {  // impl: FirestoreSportRecordDataSource
    func fetch() async throws -> [SportRecord]
    func delete(ids: [UUID]) async throws
}
```

Local `@Model`:

```swift
@Model final class SportRecordModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var location: String
    var duration: TimeInterval
    var createdAt: Date
    // no storageType — origin is implicit
}
```

Remote DTO:

```swift
struct SportRecordDTO: Codable, Sendable {   // Firestore document shape; doc ID == record UUID
    let name: String
    let location: String
    let duration: TimeInterval
    let createdAt: Date
}
```

- Local source maps `SportRecordModel → SportRecord` stamping `.local`.
- Remote source reads the `sportRecords` collection, decodes each doc, maps `DTO + docID → SportRecord` stamping `.remote`. Firestore's own offline cache may serve reads when disconnected; anything it can't serve throws and is folded into `failedStores`.
- No dedup across stores — a record lives in exactly one store.
- `insert()` is added in iteration 2 (add screen); iteration 1 needs only fetch + delete.

### `DefaultSportRecordRepository`

Holds both data sources.

- `fetch()`: `async let local = local.fetch(); async let remote = remote.fetch();` await each independently; merge successes; sort by `createdAt` descending; populate `failedStores` from whichever threw. Never throws.
- `delete(_:)`: group records by `storageType`, then dispatch `local.delete(ids:)` / `remote.delete(ids:)` for the non-empty groups. Throws if a routed delete fails.

---

## 5. Presentation layer

### State

```swift
enum RecordsContentState: Sendable {
    case loading
    case empty                     // zero records anywhere, fetch succeeded
    case loaded([SportRecord])     // all loaded records (unfiltered)
    case failed                    // nothing loadable (both stores failed)
}
enum RecordsFilter: CaseIterable, Sendable { case all, local, remote }
```

### `RecordsListViewModel` (`@MainActor @Observable`)

Constructor-injected with `FetchSportRecordsUseCase`, `DeleteSportRecordsUseCase`, `NetworkMonitor`.

Observable state: `content`, `filter`, `isRefreshing`, `remoteUnavailable`, `isOffline` (mirrors monitor), `editMode`, `selection: Set<UUID>`, `isDeleteConfirmationPresented`.

Derived:

- **`visibleRecords`** — filters the `.loaded` array by `filter`. Changing `filter` recomputes only; it **never triggers a refetch** (requirement). A filter that matches nothing shows a lightweight inline "No local records" message — distinct from the global `.empty` state.
- Banner message — derived from `isOffline` / `remoteUnavailable`.

Methods:

- `load()` — initial load; enters `.loading` only when no data is present yet; maps `SportRecordsFetchResult` → `content` + `remoteUnavailable`.
- `refresh()` — pull-to-refresh; sets `isRefreshing`; on failure keeps the existing list rather than blowing it away.
- `delete(_:)` — swipe-to-delete; **pessimistic** (await store success, then remove the row; surface an error and keep the row on failure).
- `requestDeleteSelection()` — sets `isDeleteConfirmationPresented` (edit mode only).
- `deleteSelected()` — batch delete of selected ids; on success clears selection and exits edit mode.
- `retry()` — from the `.failed` state.

### `RecordsListView` (thin — binds and delegates, no business logic)

- Switches on `content` → Core `ContentStateView` (loading / empty / error-with-retry) or the `List`.
- Offline / remote-unavailable banner via `.safeAreaInset(.top)` with Core's `MessageBanner`.
- Segmented `Picker` bound to `$viewModel.filter`.
- `.refreshable { await viewModel.refresh() }`.
- `SportRecordRow` (own file): storage-type color accent (Core token), name / location / formatted duration; `.swipeActions` delete. Duration formatting is presentation-only (`Duration.UnitsFormatStyle` → e.g. "1h 23m").
- `.toolbar`: `EditButton`; a "+" button that calls the injected `onAddRecord` closure (wired now so the flow works; add screen is iteration 2); in edit mode, a delete-selected action → `.confirmationDialog` (the batch-delete confirmation; swipe-delete needs none because the swipe gesture is its own confirmation).
- Portrait/landscape: `List` adapts automatically; Dynamic Type respected; no special layout code — verified.

---

## 6. DI wiring (Factory)

- `NetworkMonitor` → `.singleton` (one `NWPathMonitor` for the app's life).
- `ModelContainer` (SwiftData, `SportRecordModel` schema) → `.singleton`; the `@ModelActor` local data source is built from it.
- `LocalSportRecordDataSource`, `RemoteSportRecordDataSource` → `.singleton` (stateless gateways).
- `SportRecordRepository` → `.singleton`.
- `FetchSportRecordsUseCase`, `DeleteSportRecordsUseCase` → `.cached` / `.singleton` (stateless).
- **ViewModel is not a Factory-managed singleton.** `ScreenFactory.recordsList()` resolves the two use cases + monitor from the container and passes them into a fresh `RecordsListViewModel` constructor. New screen → fresh VM; shared dependencies behind it.
- App launch: `FirebaseApp.configure()` before the container is first touched.

---

## 7. Testing (Swift Testing)

- **Repository** — fake `Local`/`Remote` data sources: assert merge + sort; `failedStores` populated when remote throws while local still returns; delete routing by `storageType`.
- **ViewModel** — fake use cases + fake `NetworkMonitor`: state transitions (`loading → loaded / empty / failed`); **filter change does not refetch**; offline / remote-unavailable banner flags; swipe-delete removes-on-success / keeps-on-failure; batch delete clears selection.
- **Local data source** — real in-memory `ModelContainer` (`isStoredInMemoryOnly: true`): round-trip fetch/delete.
- **Remote** — protocol-faked; live Firestore integration is out of scope for unit tests.

---

## 8. Out of scope (later iterations)

- Add-record screen (iteration 2): the add UI, `insert()` on the local data source, remote write, form validation, duration input.
- Navigation flow *justification write-up* for the assignment deliverable.
- Anything beyond fetch + delete for the list.
