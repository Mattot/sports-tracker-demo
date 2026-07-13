# Add Sport Record — Iteration 2 Design

**Date:** 2026-07-14
**Scope:** Iteration 2 of the Sports Tracker iOS app — the **add-record** screen, presented as a sheet from the records list. Built bottom-up (Domain → Data → Presentation) plus the navigation wiring, mirroring iteration 1. The list screen and everything under it already exist.

---

## 1. Context

Iteration 1 delivered the records **list** (fetch + delete across a SwiftData local store and a Firestore remote store, behind a coordinating repository, with an MVVM presentation layer and FactoryKit DI in the app). The add-record sheet was stubbed as `AddRecordPlaceholderView` and wired through `router.present(.addRecord)`.

This iteration implements the real add screen and the **write path** (`insert`/`save`) down the stack. Assignment fields for the add screen: name, location, duration, choice of local vs backend storage, and save to the chosen store.

### Locked decisions (from brainstorming)

- **Duration** is entered with **wheels** — hours + minutes + seconds.
- **Storage type** is entered with a **menu-style `Picker`** (tap → dropdown), **not** a segmented control (segmented would read like the list screen).
- **Validation:** name, location, and duration are all required — name/location non-empty (trimmed), duration > 0. Save is disabled until all hold.
- **List refresh after save:** **reload on save** — the list re-fetches after a successful add.
- **Reload wiring:** the `onSaved` callback is passed **from the list screen through the `Sheet.addRecord` associated value** to the add screen. The list view supplies a reload bound to its own ViewModel, so `ScreenFactory` needs no shared/long-lived ViewModel.
- **Save failure is surfaced to the user** with a storage-specific message; the form is preserved for retry.
- Architecture, module boundaries, Swift 6, iOS 18.6, and DI conventions are unchanged from iteration 1.

---

## 2. Domain & Data (the write path)

A single record is saved to **one** store (the user's choice), so there is no partial-failure concern — a plain `throws`, not a typed multi-store error like delete.

### Data sources gain `insert`

```swift
public protocol LocalSportRecordDataSource: Sendable {
    func fetch() async throws -> [SportRecord]
    func insert(_ record: SportRecord) async throws
    func delete(ids: [UUID]) async throws
}
public protocol RemoteSportRecordDataSource: Sendable {
    func fetch() async throws -> [SportRecord]
    func insert(_ record: SportRecord) async throws
    func delete(ids: [UUID]) async throws
}
```

- **Local** (`SwiftDataSportRecordDataSource`, `@ModelActor`): map `SportRecord → SportRecordModel`, `modelContext.insert(...)`, `modelContext.save()`, wrapped in the same `do/catch` + `Loggers.data.error(...)` + rethrow pattern as the existing methods.
- **Remote** (`FirestoreSportRecordDataSource`): map `SportRecord → SportRecordDTO`, `collection.document(record.id.uuidString).setData(from: dto)`. A new domain→DTO mapping lives beside the existing DTO→domain one. Same logging/rethrow pattern.

### Repository gains a single-store router

```swift
func save(_ record: SportRecord) async throws   // routes by record.storageType to local OR remote
```

`DefaultSportRecordRepository.save` switches on `record.storageType` and calls the matching data source's `insert`. It rethrows the store's error (no swallowing — the caller needs to inform the user).

### Use case (new file, mirrors the others)

```swift
public protocol SaveSportRecordUseCase: Sendable {
    func execute(_ record: SportRecord) async throws
}
public struct DefaultSaveSportRecordUseCase: SaveSportRecordUseCase {
    private let repository: SportRecordRepository
    public init(repository: SportRecordRepository) { self.repository = repository }
    public func execute(_ record: SportRecord) async throws { try await repository.save(record) }
}
```

The `SportRecord` entity is unchanged — the add screen constructs one with a fresh `id: UUID()`, `createdAt: Date.now`, and the chosen `storageType`.

**Offline-remote caveat (recorded, not specially handled):** a remote save while offline is cached locally by Firestore and synced on reconnect, so `setData` may resolve without a live round-trip. Acceptable for this scope; thrown errors are still surfaced.

---

## 3. Presentation (the add screen)

### `AddRecordViewModel` (`@MainActor @Observable`)

Constructor-injected with `SaveSportRecordUseCase`. Holds no navigation (nav stays in view closures, matching the list's `onAddRecord`).

State:
- `var name: String = ""`
- `var location: String = ""`
- `var hours: Int = 0`, `var minutes: Int = 0`, `var seconds: Int = 0`
- `var storageType: StorageType = .local`
- `private(set) var isSaving = false`
- `var saveError: String?` (drives an alert; `nil` when none)

Derived:
- `var duration: TimeInterval { TimeInterval(hours * 3600 + minutes * 60 + seconds) }`
- `var canSave: Bool { !name.trimmed.isEmpty && !location.trimmed.isEmpty && duration > 0 && !isSaving }` (trimming whitespace)

Methods:
- `func save() async -> Bool`
  - `guard canSave else { return false }`
  - `isSaving = true; defer { isSaving = false }`
  - build `SportRecord(id: UUID(), name: name.trimmed, location: location.trimmed, duration: duration, storageType: storageType, createdAt: .now)`
  - `do { try await saveUseCase.execute(record); return true } catch { saveError = message(for: storageType); return false }`
- `private func message(for storageType: StorageType) -> String`
  - `.remote` → "Couldn't save to the backend. You may be offline — check your connection and try again."
  - `.local` → "Couldn't save locally. Please try again."

Returning `Bool` keeps the VM navigation-free: the view fires `onSaved` only on `true`. On failure the VM sets `saveError`, returns `false`, and — because `onSaved` is not fired — the sheet stays open with all input preserved for retry.

### `AddRecordView` (thin; owns no `NavigationStack` — the App wraps it)

Takes `viewModel`, `onSaved: () -> Void`, `onCancel: () -> Void`.

```
Form {
  Section("Activity") { TextField("Name", text: $vm.name); TextField("Location", text: $vm.location) }
  Section("Duration") { DurationPicker(hours: $vm.hours, minutes: $vm.minutes, seconds: $vm.seconds) }
  Section("Storage")  { Picker("Storage", selection: $vm.storageType) {
                          ForEach(StorageType.allCases) { Text($0.label).tag($0) }
                        }.pickerStyle(.menu) }
}
.navigationTitle("Add Record")
.toolbar {
  .cancellationAction → Button("Cancel") { onCancel() }
  .confirmationAction → Button("Save")   { Task { if await viewModel.save() { onSaved() } } }
                          .disabled(!viewModel.canSave)
}
.alert("Couldn't Save", isPresented: Binding(get: { viewModel.saveError != nil },
                                             set: { if !$0 { viewModel.saveError = nil } })) {
  Button("OK", role: .cancel) {}
} message: { Text(viewModel.saveError ?? "") }
.interactiveDismissDisabled(viewModel.isSaving)
```

Small, focused subviews:
- **`DurationPicker`** — three `.wheel`-style `Picker`s: hours `0..<24`, minutes `0..<60`, seconds `0..<60`, each bound to the VM's Int.
- The storage `Picker(.menu)` reuses `StorageType.label` (from iteration 1's `StorageType+Style.swift`) so Local/Remote naming is consistent across screens.

---

## 4. Composition & wiring (callback through the Sheet case)

### `Sheet` carries the callback

A closure isn't `Hashable`/`Equatable`, so `Sheet` drops those and stays only `Identifiable` (all `.sheet(item:)` needs):

```swift
enum Sheet: Identifiable {
    case addRecord(onSaved: () -> Void)   // typed @MainActor () -> Void if Swift 6 isolation requires it
    enum ID: Hashable { case addRecord }
    var id: ID { switch self { case .addRecord: .addRecord } }
}
```

`AppRouter.present(_ sheet: Sheet)` is unchanged.

### The list view provides `onSaved`, bound to its own ViewModel

`RecordsListView.onAddRecord` changes from `() -> Void` to `(@escaping () -> Void) -> Void`. The "+" button supplies its own reload:

```swift
Button { onAddRecord { Task { await viewModel.load() } } } label: { Label("Add Record", systemImage: "plus") }
```

`viewModel` here is the view's own `@State` instance (always the displayed one), so the reload is always correct without a shared VM.

### Flow, end to end

```
list "+"                → onAddRecord({ reload list })
ScreenFactory.recordsList: onAddRecord = { onSaved in router.present(.addRecord(onSaved: onSaved)) }
AppFlowView sheet:         case .addRecord(let onSaved): factory.addRecord(onSaved: onSaved)
ScreenFactory.addRecord:   NavigationStack { AddRecordView(
                             viewModel: AddRecordViewModel(save: container.saveSportRecordUseCase()),
                             onSaved: { onSaved(); router.dismissSheet() },   // reload list + dismiss
                             onCancel: { router.dismissSheet() }) }
AddRecordView Save:        Task { if await viewModel.save() { onSaved() } }
```

The reload closure reuses the list VM's existing `load()` (re-fetches both stores; no `.loading` flash when data is already present). It fires only on a successful save, then the sheet dismisses. `ScreenFactory` stays stateless.

### DI

Add `saveSportRecordUseCase` to the FactoryKit container (`.cached`, like the other use cases), resolving `DefaultSaveSportRecordUseCase(repository: sportRecordRepository())`.

### Files touched

- **Iteration-1 files:** `AppRouter.swift` (Sheet case), `RecordsListView.swift` (`onAddRecord` signature + the one "+" call site), `ScreenFactory.swift` (recordsList `onAddRecord`, addRecord `onSaved`/`onCancel`), `Container+SportRecord.swift` (new registration), the data-source protocols + both impls + repository (add `insert`/`save`). Remove `AddRecordPlaceholderView.swift`.
- **New feature files:** `Domain/UseCases/SaveSportRecordUseCase.swift`; remote domain→DTO mapping (extend `SportRecordDTO+Mapping.swift`); `Presentation/ViewModel/AddRecordViewModel.swift`; `Presentation/Views/AddRecordView.swift`; `Presentation/Views/DurationPicker.swift`.
- **New app files:** `Navigation/AddRecordScreen` wiring stays in `ScreenFactory`/`AppFlowView` (no new nav file).

---

## 5. Testing (Swift Testing)

New shared fakes: `FakeSaveSportRecordUseCase` (captures the record, configurable throw); `FakeDataSource` gains `insert` capture; `FakeSportRecordRepository` gains `save`.

- **`SaveSportRecordUseCase`** — `execute(record)` forwards to `repository.save(record)`; propagates the thrown error.
- **Repository `save(_:)` routing** — `.local` record → `local.insert` only (remote untouched); `.remote` record → `remote.insert` only; a store failure propagates.
- **Local data source `insert`** — real in-memory `ModelContainer`: insert → `fetch` returns the record with all fields intact (round-trip).
- **Remote mapping** — `SportRecord → SportRecordDTO` drops `id` (it is the document ID) and preserves name/location/duration/createdAt. Live Firestore is out of scope.
- **`AddRecordViewModel`**:
  - `canSave` matrix — empty/whitespace name → false; empty/whitespace location → false; `duration == 0` → false; all valid → true; while `isSaving` → false.
  - duration composition — `hours 1, minutes 2, seconds 3 → duration == 3723`.
  - `save()` success — builds a record with **trimmed** name/location, computed duration, and chosen `storageType`; calls the use case; returns `true`.
  - `save()` failure — use case throws → returns `false`, `saveError` set to the **storage-specific** message (remote vs local).
  - `save()` guard — when `!canSave`, returns `false` and the use case is never called.

`DurationPicker`, the storage `Picker(.menu)`, and `AddRecordView` are SwiftUI views — compile-verified, not unit-tested (as in iteration 1).

---

## 6. Out of scope

- Editing an existing record (only create).
- Any list-screen behavior change beyond calling the existing `load()` on save.
- Pushes / additional navigation destinations.
