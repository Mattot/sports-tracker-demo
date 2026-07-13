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
│   ├── Entities/
│   │   ├── SportRecord.swift               // entity (Sendable value type)
│   │   ├── StorageType.swift               // .local / .remote
│   │   ├── SportRecordsFetchResult.swift   // merged records + failedStores
│   │   └── SportRecordsDeleteError.swift   // typed delete error carrying failedStores
│   ├── Repositories/
│   │   └── SportRecordRepository.swift     // protocol
│   └── UseCases/
│       ├── FetchSportRecordsUseCase.swift
│       └── DeleteSportRecordsUseCase.swift
├── Data/
│   ├── DataSources/
│   │   ├── Local/
│   │   │   ├── SportRecordModel.swift               // @Model
│   │   │   ├── SwiftDataSportRecordDataSource.swift // @ModelActor, LocalSportRecordDataSource
│   │   │   └── SportRecordModel+Mapping.swift
│   │   └── Remote/
│   │       ├── SportRecordDTO.swift                 // Codable Firestore shape
│   │       ├── FirestoreSportRecordDataSource.swift // RemoteSportRecordDataSource
│   │       └── SportRecordDTO+Mapping.swift
│   └── Repositories/
│       └── DefaultSportRecordRepository.swift
└── Presentation/
    ├── ViewModel/
    │   ├── RecordsListViewModel.swift
    │   └── RecordsListState.swift
    └── Views/
        ├── RecordsListView.swift
        └── SportRecordRow.swift            // loading/empty/error via Core ContentStateView; banner via Core MessageBanner
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

### Delete error (partial-failure aware)

```swift
struct SportRecordsDeleteError: Error, Sendable {
    let failedStores: Set<StorageType> // exactly the store(s) whose delete threw
}
```

Symmetric with the fetch result: each store commits its deletes independently, so a mixed multi-select delete can partially fail. The error names precisely which store(s) failed, so the ViewModel can drop the rows that were actually deleted and keep only the failed ones. Swift 6 **typed throws** (`throws(SportRecordsDeleteError)`) makes the single failure mode explicit and the handled states exhaustive.

### Repository protocol (coordinating)

```swift
protocol SportRecordRepository: Sendable {
    func fetch() async -> SportRecordsFetchResult                               // async-let both stores, merge, sort, collect failedStores
    func delete(_ records: [SportRecord]) async throws(SportRecordsDeleteError) // group by storageType; succeeded stores commit even if the other fails
}
```

The repository owns multi-store coordination: concurrency + partial-failure policy for fetch, and group-by-`storageType` routing for delete.

### Use cases (thin domain seams, `execute()`)

```swift
protocol FetchSportRecordsUseCase: Sendable {
    func execute() async -> SportRecordsFetchResult
}
protocol DeleteSportRecordsUseCase: Sendable {
    func execute(_ records: [SportRecord]) async throws(SportRecordsDeleteError)
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
- `delete(_:)`: group records by `storageType`; run the non-empty groups' deletes concurrently (`async let`). Each store commits independently — a failure in one store does **not** roll back the other. If any group throws, catch it and throw `SportRecordsDeleteError(failedStores:)` listing exactly the store(s) that failed (records in a succeeded store are already gone). Returns normally only when every routed delete succeeds.

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

Observable state: `content`, `filter`, `isRefreshing`, `remoteUnavailable`, `isOffline` (mirrors monitor), `editMode`, `selection: Set<UUID>`, `isDeleteConfirmationPresented`, `deleteError: String?` (drives an alert; `nil` when there's no error).

Derived:

- **`visibleRecords`** — filters the `.loaded` array by `filter`. Changing `filter` recomputes only; it **never triggers a refetch** (requirement). A filter that matches nothing shows a lightweight inline "No local records" message — distinct from the global `.empty` state.
- Banner message — derived from `isOffline` / `remoteUnavailable`.

Methods:

- `load()` — initial load; enters `.loading` only when no data is present yet; maps `SportRecordsFetchResult` → `content` + `remoteUnavailable`.
- `refresh()` — pull-to-refresh; sets `isRefreshing`; on failure keeps the existing list rather than blowing it away.
- `delete(_:)` — swipe-to-delete of a single record; **pessimistic**. Await the use case; on success drop the row. On `SportRecordsDeleteError` the failed store necessarily equals the record's own store, so keep the row and set `deleteError` to a store-specific message.
- `requestDeleteSelection()` — sets `isDeleteConfirmationPresented` (edit mode only).
- `deleteSelected()` — batch delete of the selected records (may span both stores). Await the use case; on success remove all selected rows, clear `selection`, exit edit mode. On `SportRecordsDeleteError`: remove only the rows whose `storageType` is **not** in `failedStores` (those stores committed), keep the rows in `failedStores`, reduce `selection` to just the failed rows, stay in edit mode, and set `deleteError` to a message naming the failed store(s).
- `retry()` — from the `.failed` state.

### `RecordsListView` (thin — binds and delegates, no business logic)

- Switches on `content` → Core `ContentStateView` (loading / empty / error-with-retry) or the `List`.
- Offline / remote-unavailable banner via `.safeAreaInset(.top)` with Core's `MessageBanner`.
- Segmented `Picker` bound to `$viewModel.filter`.
- `.refreshable { await viewModel.refresh() }`.
- `SportRecordRow` (own file): storage-type color accent (Core token), name / location / formatted duration; `.swipeActions` delete. Duration formatting is presentation-only (`Duration.UnitsFormatStyle` → e.g. "1h 23m").
- `.toolbar`: `EditButton`; a "+" button that calls the injected `onAddRecord` closure (wired now so the flow works; add screen is iteration 2); in edit mode, a delete-selected action → `.confirmationDialog` (the batch-delete confirmation; swipe-delete needs none because the swipe gesture is its own confirmation).
- `.alert` bound to `$viewModel.deleteError` — surfaces per-store delete failures (offline remote delete, etc.).
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

Fakes: `Local`/`Remote` data sources whose `fetch`/`delete` can be told to succeed or throw per call; a fake `NetworkMonitor`; fake use cases for the ViewModel.

### Fetch & list-state tests

- **Repository fetch** — merge + sort by `createdAt` desc; `failedStores == []` when both succeed; `failedStores == [.remote]` when remote throws while local returns; `failedStores == [.local, .remote]` when both throw (records empty).
- **ViewModel** — state transitions (`loading → loaded / empty / failed`); `.failed` only when records empty **and** both stores failed; `.empty` when fetch succeeds with zero records; **filter change does not refetch** (assert the fetch use case is called exactly once across filter switches); a filter with no matches yields empty `visibleRecords` but keeps `content == .loaded`; `isOffline` / `remoteUnavailable` banner flags; `refresh()` keeps the existing list when the refetch fails.

### Delete tests — full local/remote combination matrix

**Repository `delete(_:)`** — assert routing (correct ids to each source) and the thrown `failedStores`:

| Selection    | Local delete | Remote delete | Expected outcome                                              |
|--------------|--------------|---------------|--------------------------------------------------------------|
| local-only   | success      | —             | returns; `local.delete(ids:)` called with those ids          |
| local-only   | throws       | —             | throws `failedStores == [.local]`                            |
| remote-only  | —            | success       | returns; `remote.delete(ids:)` called with those ids         |
| remote-only  | —            | throws        | throws `failedStores == [.remote]`                          |
| mixed        | success      | success       | returns; both sources called with their respective ids       |
| mixed        | success      | throws        | throws `failedStores == [.remote]`; `local.delete` still called (committed) |
| mixed        | throws       | success       | throws `failedStores == [.local]`; `remote.delete` still called (committed) |
| mixed        | throws       | throws        | throws `failedStores == [.local, .remote]`                  |

**ViewModel delete handling** — fake `DeleteSportRecordsUseCase` returns success or throws a chosen `SportRecordsDeleteError`:

*Swipe (single record):*

| Record  | Outcome            | Expected                                              |
|---------|--------------------|------------------------------------------------------|
| local   | success            | row removed; `deleteError == nil`                    |
| local   | throws `[.local]`  | row kept; `deleteError` set (local message)          |
| remote  | success            | row removed; `deleteError == nil`                    |
| remote  | throws `[.remote]` | row kept; `deleteError` set (remote message)         |

*Batch (`deleteSelected`):*

| Selection   | Outcome                   | Expected                                                                                 |
|-------------|---------------------------|------------------------------------------------------------------------------------------|
| local-only  | success                   | all removed; `selection` cleared; `editMode` inactive; `deleteError == nil`               |
| local-only  | throws `[.local]`         | none removed; `selection` retained; `editMode` active; `deleteError` set                  |
| remote-only | success                   | all removed; cleared; inactive                                                            |
| remote-only | throws `[.remote]`        | none removed; retained; active; error set                                                |
| mixed       | success                   | all removed; cleared; inactive                                                           |
| mixed       | throws `[.remote]`        | local rows removed; remote rows kept; `selection` reduced to remote ids; active; error   |
| mixed       | throws `[.local]`         | remote rows removed; local rows kept; `selection` reduced to local ids; active; error    |
| mixed       | throws `[.local,.remote]` | none removed; `selection` retained; active; error                                        |

### Data source tests

- **Local data source** — real in-memory `ModelContainer` (`isStoredInMemoryOnly: true`): round-trip fetch, delete by ids (including deleting a subset), delete of a missing id is a no-op.
- **Remote** — protocol-faked; live Firestore integration is out of scope for unit tests.

---

## 8. Out of scope (later iterations)

- Add-record screen (iteration 2): the add UI, `insert()` on the local data source, remote write, form validation, duration input.
- Navigation flow *justification write-up* for the assignment deliverable.
- Anything beyond fetch + delete for the list.
