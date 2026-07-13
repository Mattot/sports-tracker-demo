# Add Sport Record — Iteration 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the create/save path (`insert`/`save`) down the stack and the add-record sheet screen, wired to reload the list on a successful save.

**Architecture:** Extends the existing Clean layering. New `SaveSportRecordUseCase`; repository `save(_:)` routes a single record to one store; data sources gain `insert`. New `AddRecordViewModel` + `AddRecordView` (duration wheels, menu storage picker). The `onSaved` reload callback travels from the list view through the `Sheet.addRecord` associated value. iOS 18.6, Swift 6.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, FirebaseFirestore, FactoryKit, Swift Testing.

---

## Conventions

- **Repo root:** `/Users/matusselecky/Documents/Work/Etnetera/sports-tracker`.
- **Package tests:** from `Modules/SportRecord`:
  ```bash
  xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'
  ```
  Capture the exit code directly (`echo "EXIT=$?"`, not through a pipe); Xcode 26.6 suppresses the banner, so **EXIT 0 = success**. Build-only: `xcodebuild build ...`.
- **App build:** from repo root:
  ```bash
  xcodebuild build -project SportsTracker/SportsTracker.xcodeproj -scheme SportsTracker -destination 'generic/platform=iOS Simulator'
  ```
- **Swift Testing** (`import Testing`, `@Test`, `#expect`), not XCTest.
- **TDD** for logic (data sources, repository, use case, view model); SwiftUI views are compile-verified. Commit per task; end commit messages with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`, committing with `git -c user.name='Matus Selecky' -c user.email='matus.selecky@gmail.com'` (identity is set locally, so plain `git commit` also works).
- The shared test-support file is `Modules/SportRecord/Tests/SportRecordTests/Support/Fakes.swift` — **append** to it, don't overwrite.

---

## File map

- **Modify:** `Data/DataSources/SportRecordDataSources.swift` (protocols), `Data/DataSources/Local/SwiftDataSportRecordDataSource.swift`, `Data/DataSources/Local/SportRecordModel+Mapping.swift`, `Data/DataSources/Remote/FirestoreSportRecordDataSource.swift`, `Data/DataSources/Remote/SportRecordDTO+Mapping.swift`, `Data/Repositories/DefaultSportRecordRepository.swift`, `Domain/Repositories/SportRecordRepository.swift`, `Presentation/Views/RecordsListView.swift`, `Tests/SportRecordTests/Support/Fakes.swift`, `Tests/SportRecordTests/Data/LocalDataSourceTests.swift`, `Tests/SportRecordTests/Data/RepositoryTests.swift`.
- **Create (feature):** `Domain/UseCases/SaveSportRecordUseCase.swift`, `Presentation/ViewModel/AddRecordViewModel.swift`, `Presentation/Views/AddRecordView.swift`, `Presentation/Views/DurationPicker.swift`, `Tests/SportRecordTests/Data/RemoteMappingTests.swift` (extend if present) + `Tests/SportRecordTests/Domain/UseCaseTests.swift` (extend), `Tests/SportRecordTests/Presentation/AddRecordViewModelTests.swift`.
- **Modify (app):** `SportsTracker/SportsTracker/Navigation/AppRouter.swift`, `Navigation/ScreenFactory.swift`, `Navigation/AppFlowView.swift`, `DI/Container+SportRecord.swift`.
- **Delete (app):** `SportsTracker/SportsTracker/Navigation/AddRecordPlaceholderView.swift`.

---

## Task 1: Data sources — `insert`

**Files:** the two data-source protocols, both impls, both domain→persistence mappings, `Fakes.swift`, `LocalDataSourceTests.swift`, and a new `RemoteMappingTests.swift`.

- [ ] **Step 1: Write the failing tests**

Append to `Tests/SportRecordTests/Data/LocalDataSourceTests.swift` (the `makeInMemoryContainer` helper already exists in this file):
```swift
@Test @MainActor func insertThenFetchReturnsRecord() async throws {
    let container = try makeInMemoryContainer()
    let sut = SwiftDataSportRecordDataSource(modelContainer: container)
    let record = Sample.record(name: "Swim", location: "Pool", duration: 1800, storage: .local, createdAt: .init(timeIntervalSince1970: 5))

    try await sut.insert(record)
    let fetched = try await sut.fetch()

    #expect(fetched.count == 1)
    #expect(fetched.first?.id == record.id)
    #expect(fetched.first?.name == "Swim")
    #expect(fetched.first?.location == "Pool")
    #expect(fetched.first?.duration == 1800)
    #expect(fetched.first?.storageType == .local)
}
```

Create `Tests/SportRecordTests/Data/RemoteMappingTests.swift` (add the domain→DTO test; if the file already exists with the DTO→domain test, append this one instead):
```swift
import Testing
import Foundation
@testable import SportRecord

@Test func recordMapsToDTODroppingId() {
    let record = Sample.record(name: "Row", location: "Lake", duration: 900, storage: .remote, createdAt: .init(timeIntervalSince1970: 7))
    let dto = SportRecordDTO(record: record)

    #expect(dto.name == "Row")
    #expect(dto.location == "Lake")
    #expect(dto.duration == 900)
    #expect(dto.createdAt == Date(timeIntervalSince1970: 7))
    // (DTO has no id field — the record's UUID is the Firestore document ID.)
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'; echo "EXIT=$?"
```
Expected: FAIL — `value of type 'SwiftDataSportRecordDataSource' has no member 'insert'` and `SportRecordDTO` has no `init(record:)`.

- [ ] **Step 3: Add `insert` to both protocols**

`Data/DataSources/SportRecordDataSources.swift` — add the method to each protocol:
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

- [ ] **Step 4: Add the domain→persistence mappings**

Append to `Data/DataSources/Local/SportRecordModel+Mapping.swift`:
```swift
extension SportRecordModel {
    /// Builds a persistence model from a domain record (storageType is implicit).
    convenience init(record: SportRecord) {
        self.init(
            id: record.id,
            name: record.name,
            location: record.location,
            duration: record.duration,
            createdAt: record.createdAt
        )
    }
}
```

Append to `Data/DataSources/Remote/SportRecordDTO+Mapping.swift`:
```swift
extension SportRecordDTO {
    /// Builds the Firestore document body from a domain record. `id` is dropped —
    /// it becomes the document ID.
    init(record: SportRecord) {
        self.init(
            name: record.name,
            location: record.location,
            duration: record.duration,
            createdAt: record.createdAt
        )
    }
}
```

- [ ] **Step 5: Implement `insert` in both data sources**

`Data/DataSources/Local/SwiftDataSportRecordDataSource.swift` — add inside the actor:
```swift
    func insert(_ record: SportRecord) async throws {
        do {
            modelContext.insert(SportRecordModel(record: record))
            try modelContext.save()
        } catch {
            Loggers.data.error("SwiftData insert failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
```

`Data/DataSources/Remote/FirestoreSportRecordDataSource.swift` — add inside the struct:
```swift
    func insert(_ record: SportRecord) async throws {
        do {
            try collection.document(record.id.uuidString).setData(from: SportRecordDTO(record: record))
        } catch {
            Loggers.data.error("Firestore insert failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
```
(`setData(from:)` uses Firestore's Codable encoder; it is a synchronous throwing call that queues the write — no `await`.)

- [ ] **Step 6: Add `insert` capture to the fake data source**

In `Tests/SportRecordTests/Support/Fakes.swift`, extend `FakeDataSource` (it conforms to both protocols, so this is required for the test target to compile):
```swift
    private(set) var inserted: [SportRecord] = []
    var insertError: Error?

    func insert(_ record: SportRecord) async throws {
        inserted.append(record)
        if let insertError { throw insertError }
    }
```

- [ ] **Step 7: Run to verify it passes**

```bash
cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'; echo "EXIT=$?"
```
Expected: EXIT 0.

- [ ] **Step 8: Commit**

```bash
git add Modules/SportRecord/Sources/SportRecord/Data Modules/SportRecord/Tests/SportRecordTests
git commit -m "feat(sportrecord): add insert to local and remote data sources"
```

---

## Task 2: Repository — `save(_:)` routing

**Files:** `Domain/Repositories/SportRecordRepository.swift`, `Data/Repositories/DefaultSportRecordRepository.swift`, `Fakes.swift` (repository fake), `RepositoryTests.swift`.

- [ ] **Step 1: Write the failing tests**

Append to `Tests/SportRecordTests/Data/RepositoryTests.swift` (the `makeSUT()` helper already exists and returns `(sut, local, remote)`):
```swift
// MARK: save routing

@Test func saveLocalRecordRoutesToLocalOnly() async throws {
    let (sut, local, remote) = makeSUT()
    let record = Sample.record(storage: .local)
    try await sut.save(record)
    #expect(local.inserted.map(\.id) == [record.id])
    #expect(remote.inserted.isEmpty)
}

@Test func saveRemoteRecordRoutesToRemoteOnly() async throws {
    let (sut, local, remote) = makeSUT()
    let record = Sample.record(storage: .remote)
    try await sut.save(record)
    #expect(remote.inserted.map(\.id) == [record.id])
    #expect(local.inserted.isEmpty)
}

@Test func saveLocalFailurePropagates() async {
    let (sut, local, _) = makeSUT()
    local.insertError = AnyError()
    await #expect(throws: (any Error).self) {
        try await sut.save(Sample.record(storage: .local))
    }
}

@Test func saveRemoteFailurePropagates() async {
    let (sut, _, remote) = makeSUT()
    remote.insertError = AnyError()
    await #expect(throws: (any Error).self) {
        try await sut.save(Sample.record(storage: .remote))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'; echo "EXIT=$?"
```
Expected: FAIL — `SportRecordRepository` / `DefaultSportRecordRepository` has no member `save`, and `FakeSportRecordRepository` won't conform once the protocol gains `save` (added next).

- [ ] **Step 3: Add `save` to the repository protocol**

`Domain/Repositories/SportRecordRepository.swift`:
```swift
public protocol SportRecordRepository: Sendable {
    func fetch() async -> SportRecordsFetchResult
    func save(_ record: SportRecord) async throws
    func delete(_ records: [SportRecord]) async throws(SportRecordsDeleteError)
}
```

- [ ] **Step 4: Implement `save` in the repository**

`Data/Repositories/DefaultSportRecordRepository.swift` — add after `fetch()`:
```swift
    public func save(_ record: SportRecord) async throws {
        switch record.storageType {
        case .local:  try await local.insert(record)
        case .remote: try await remote.insert(record)
        }
    }
```
(No error-swallowing: the data source logs the underlying error and this rethrows so the caller can inform the user.)

- [ ] **Step 5: Add `save` to the fake repository**

In `Fakes.swift`, extend `FakeSportRecordRepository`:
```swift
    var saveError: Error?
    private(set) var savedRecords: [SportRecord] = []

    func save(_ record: SportRecord) async throws {
        savedRecords.append(record)
        if let saveError { throw saveError }
    }
```

- [ ] **Step 6: Run to verify it passes**

```bash
cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'; echo "EXIT=$?"
```
Expected: EXIT 0.

- [ ] **Step 7: Commit**

```bash
git add Modules/SportRecord/Sources/SportRecord/Domain/Repositories Modules/SportRecord/Sources/SportRecord/Data/Repositories Modules/SportRecord/Tests/SportRecordTests
git commit -m "feat(sportrecord): route single-record save by storage type"
```

---

## Task 3: `SaveSportRecordUseCase`

**Files:** `Domain/UseCases/SaveSportRecordUseCase.swift` (new), `Fakes.swift`, `Domain/UseCaseTests.swift`.

- [ ] **Step 1: Write the failing tests**

Append to `Tests/SportRecordTests/Domain/UseCaseTests.swift`:
```swift
@Test func saveUseCaseForwardsToRepository() async throws {
    let repo = FakeSportRecordRepository()
    let sut = DefaultSaveSportRecordUseCase(repository: repo)
    let record = Sample.record()
    try await sut.execute(record)
    #expect(repo.savedRecords.map(\.id) == [record.id])
}

@Test func saveUseCasePropagatesError() async {
    let repo = FakeSportRecordRepository()
    repo.saveError = AnyError()
    let sut = DefaultSaveSportRecordUseCase(repository: repo)
    await #expect(throws: (any Error).self) {
        try await sut.execute(Sample.record())
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'; echo "EXIT=$?"
```
Expected: FAIL — `cannot find 'DefaultSaveSportRecordUseCase' in scope`.

- [ ] **Step 3: Create the use case**

`Domain/UseCases/SaveSportRecordUseCase.swift`:
```swift
public protocol SaveSportRecordUseCase: Sendable {
    func execute(_ record: SportRecord) async throws
}

public struct DefaultSaveSportRecordUseCase: SaveSportRecordUseCase {
    private let repository: SportRecordRepository

    public init(repository: SportRecordRepository) {
        self.repository = repository
    }

    public func execute(_ record: SportRecord) async throws {
        try await repository.save(record)
    }
}
```

- [ ] **Step 4: Add the fake use case for later VM tests**

Append to `Fakes.swift`:
```swift
@MainActor
final class FakeSaveSportRecordUseCase: SaveSportRecordUseCase {
    var errorToThrow: (any Error)?
    private(set) var saved: [SportRecord] = []

    func execute(_ record: SportRecord) async throws {
        saved.append(record)
        if let errorToThrow { throw errorToThrow }
    }
}
```

- [ ] **Step 5: Run to verify it passes**

```bash
cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'; echo "EXIT=$?"
```
Expected: EXIT 0.

- [ ] **Step 6: Commit**

```bash
git add Modules/SportRecord/Sources/SportRecord/Domain/UseCases Modules/SportRecord/Tests/SportRecordTests
git commit -m "feat(sportrecord): add SaveSportRecordUseCase"
```

---

## Task 4: `AddRecordViewModel`

**Files:** `Presentation/ViewModel/AddRecordViewModel.swift` (new), `Tests/SportRecordTests/Presentation/AddRecordViewModelTests.swift` (new).

- [ ] **Step 1: Write the failing tests**

`Tests/SportRecordTests/Presentation/AddRecordViewModelTests.swift`:
```swift
import Testing
import Foundation
@testable import SportRecord

@MainActor
private func makeSUT() -> (AddRecordViewModel, FakeSaveSportRecordUseCase) {
    let save = FakeSaveSportRecordUseCase()
    return (AddRecordViewModel(save: save), save)
}

@Test @MainActor func canSaveRequiresNameLocationAndPositiveDuration() {
    let (sut, _) = makeSUT()
    #expect(!sut.canSave)
    sut.name = "Run";      #expect(!sut.canSave)
    sut.location = "Park"; #expect(!sut.canSave)   // duration still 0
    sut.minutes = 30;      #expect(sut.canSave)
}

@Test @MainActor func canSaveRejectsWhitespaceOnlyFields() {
    let (sut, _) = makeSUT()
    sut.name = "   "; sut.location = "   "; sut.minutes = 5
    #expect(!sut.canSave)
}

@Test @MainActor func durationComposesHoursMinutesSeconds() {
    let (sut, _) = makeSUT()
    sut.hours = 1; sut.minutes = 2; sut.seconds = 3
    #expect(sut.duration == 3723)
}

@Test @MainActor func saveSuccessBuildsTrimmedRecordAndReturnsTrue() async {
    let (sut, save) = makeSUT()
    sut.name = "  Swim  "; sut.location = "  Pool "; sut.hours = 1; sut.storageType = .remote

    let ok = await sut.save()

    #expect(ok)
    #expect(save.saved.count == 1)
    let record = save.saved.first
    #expect(record?.name == "Swim")
    #expect(record?.location == "Pool")
    #expect(record?.duration == 3600)
    #expect(record?.storageType == .remote)
    #expect(sut.saveError == nil)
}

@Test @MainActor func saveFailureSetsStorageSpecificMessageAndReturnsFalse() async {
    let (sut, save) = makeSUT()
    save.errorToThrow = AnyError()
    sut.name = "Run"; sut.location = "Park"; sut.minutes = 10; sut.storageType = .remote

    let ok = await sut.save()

    #expect(!ok)
    #expect(sut.saveError?.contains("backend") == true)   // remote-specific message
}

@Test @MainActor func saveDoesNothingWhenInvalid() async {
    let (sut, save) = makeSUT()
    let ok = await sut.save()
    #expect(!ok)
    #expect(save.saved.isEmpty)
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'; echo "EXIT=$?"
```
Expected: FAIL — `cannot find 'AddRecordViewModel' in scope`.

- [ ] **Step 3: Create the view model**

`Presentation/ViewModel/AddRecordViewModel.swift`:
```swift
import Foundation
import Observation

@MainActor
@Observable
public final class AddRecordViewModel {
    private let saveUseCase: SaveSportRecordUseCase

    public var name = ""
    public var location = ""
    public var hours = 0
    public var minutes = 0
    public var seconds = 0
    public var storageType: StorageType = .local
    public private(set) var isSaving = false
    public var saveError: String?

    public init(save: SaveSportRecordUseCase) {
        self.saveUseCase = save
    }

    public var duration: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60 + seconds)
    }

    public var canSave: Bool {
        !name.trimmed.isEmpty && !location.trimmed.isEmpty && duration > 0 && !isSaving
    }

    /// Returns `true` on success so the view can fire its `onSaved` navigation
    /// closure; on failure sets `saveError` and returns `false`, leaving the
    /// form intact for retry.
    public func save() async -> Bool {
        guard canSave else { return false }
        isSaving = true
        defer { isSaving = false }

        let record = SportRecord(
            id: UUID(),
            name: name.trimmed,
            location: location.trimmed,
            duration: duration,
            storageType: storageType,
            createdAt: Date()
        )
        do {
            try await saveUseCase.execute(record)
            return true
        } catch {
            saveError = message(for: storageType)
            return false
        }
    }

    private func message(for storageType: StorageType) -> String {
        switch storageType {
        case .remote: "Couldn't save to the backend. You may be offline — check your connection and try again."
        case .local:  "Couldn't save locally. Please try again."
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
```

- [ ] **Step 4: Run to verify it passes**

```bash
cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'; echo "EXIT=$?"
```
Expected: EXIT 0.

- [ ] **Step 5: Commit**

```bash
git add Modules/SportRecord/Sources/SportRecord/Presentation/ViewModel Modules/SportRecord/Tests/SportRecordTests/Presentation/AddRecordViewModelTests.swift
git commit -m "feat(sportrecord): add AddRecordViewModel with validation and save"
```

---

## Task 5: `AddRecordView` + `DurationPicker` (build-only)

SwiftUI views — verified by building the package.

**Files:** `Presentation/Views/DurationPicker.swift` (new), `Presentation/Views/AddRecordView.swift` (new).

- [ ] **Step 1: Write `DurationPicker`**

`Presentation/Views/DurationPicker.swift`:
```swift
import SwiftUI

/// Three wheel pickers — hours / minutes / seconds — bound to Int components.
struct DurationPicker: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var seconds: Int

    var body: some View {
        HStack(spacing: 0) {
            wheel($hours, range: 0..<24, unit: "h")
            wheel($minutes, range: 0..<60, unit: "m")
            wheel($seconds, range: 0..<60, unit: "s")
        }
        .frame(maxWidth: .infinity)
    }

    private func wheel(_ value: Binding<Int>, range: Range<Int>, unit: String) -> some View {
        Picker(unit, selection: value) {
            ForEach(range, id: \.self) { Text("\($0) \(unit)").tag($0) }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}
```

- [ ] **Step 2: Write `AddRecordView`**

`Presentation/Views/AddRecordView.swift`:
```swift
import SwiftUI

public struct AddRecordView: View {
    @State private var viewModel: AddRecordViewModel
    private let onSaved: () -> Void
    private let onCancel: () -> Void

    public init(
        viewModel: AddRecordViewModel,
        onSaved: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
        self.onCancel = onCancel
    }

    public var body: some View {
        Form {
            Section("Activity") {
                TextField("Name", text: $viewModel.name)
                TextField("Location", text: $viewModel.location)
            }
            Section("Duration") {
                DurationPicker(
                    hours: $viewModel.hours,
                    minutes: $viewModel.minutes,
                    seconds: $viewModel.seconds
                )
            }
            Section("Storage") {
                Picker("Storage", selection: $viewModel.storageType) {
                    ForEach(StorageType.allCases, id: \.self) { type in
                        Text(type.label).tag(type)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .navigationTitle("Add Record")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onCancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { if await viewModel.save() { onSaved() } }
                }
                .disabled(!viewModel.canSave)
            }
        }
        .alert(
            "Couldn't Save",
            isPresented: Binding(
                get: { viewModel.saveError != nil },
                set: { if !$0 { viewModel.saveError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.saveError ?? "")
        }
        .interactiveDismissDisabled(viewModel.isSaving)
    }
}
```

- [ ] **Step 3: Build to verify it compiles**

```bash
cd Modules/SportRecord && xcodebuild build -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'; echo "EXIT=$?"
```
Expected: EXIT 0.

- [ ] **Step 4: Commit**

```bash
git add Modules/SportRecord/Sources/SportRecord/Presentation/Views
git commit -m "feat(sportrecord): add AddRecordView and DurationPicker"
```

---

## Task 6: List view — carry the `onSaved` reload callback

`RecordsListView.onAddRecord` changes from `() -> Void` to `(@escaping () -> Void) -> Void` so the "+" button supplies its own reload. Build-only (the view isn't unit-tested); this keeps the package compiling before the app wiring in Task 7.

**Files:** `Presentation/Views/RecordsListView.swift`.

- [ ] **Step 1: Change the `onAddRecord` property + init**

In `RecordsListView.swift`, replace:
```swift
    private let onAddRecord: () -> Void

    public init(viewModel: RecordsListViewModel, onAddRecord: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onAddRecord = onAddRecord
    }
```
with:
```swift
    // The list supplies its own reload as the add screen's `onSaved`, so the
    // callback carries it: (onSaved) -> Void.
    private let onAddRecord: (@escaping () -> Void) -> Void

    public init(viewModel: RecordsListViewModel, onAddRecord: @escaping (@escaping () -> Void) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onAddRecord = onAddRecord
    }
```

- [ ] **Step 2: Update the "+" button call site**

In `toolbarContent`, replace the add button:
```swift
                Button {
                    onAddRecord()
                } label: {
                    Label("Add Record", systemImage: "plus")
                }
```
with:
```swift
                Button {
                    onAddRecord { Task { await viewModel.load() } }
                } label: {
                    Label("Add Record", systemImage: "plus")
                }
```

- [ ] **Step 3: Build to verify it compiles**

```bash
cd Modules/SportRecord && xcodebuild build -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'; echo "EXIT=$?"
```
Expected: EXIT 0.

- [ ] **Step 4: Commit**

```bash
git add Modules/SportRecord/Sources/SportRecord/Presentation/Views/RecordsListView.swift
git commit -m "feat(sportrecord): carry add-record onSaved reload through onAddRecord"
```

---

## Task 7: App wiring + verification

Wire the callback through the `Sheet` case, build the add screen in `ScreenFactory`, register the use case, remove the placeholder. Verified by app build + a launch smoke test.

**Files:** `Navigation/AppRouter.swift`, `Navigation/ScreenFactory.swift`, `Navigation/AppFlowView.swift`, `DI/Container+SportRecord.swift`; delete `Navigation/AddRecordPlaceholderView.swift`.

- [ ] **Step 1: `Sheet` carries `onSaved`**

In `AppRouter.swift`, replace the `Sheet` enum:
```swift
enum Sheet: Identifiable, Hashable {
    case addRecord
    var id: Self { self }
}
```
with:
```swift
/// Modal surfaces. The add-record sheet carries the list's reload callback, so
/// `Sheet` can't be Hashable/Equatable (a closure isn't) — `.sheet(item:)` only
/// needs Identifiable.
enum Sheet: Identifiable {
    case addRecord(onSaved: () -> Void)

    enum ID: Hashable { case addRecord }
    var id: ID { switch self { case .addRecord: .addRecord } }
}
```
(If Swift 6 strict concurrency flags the stored closure, type it `case addRecord(onSaved: @MainActor () -> Void)` — everything here is main-actor.)

- [ ] **Step 2: Register the use case in the container**

In `DI/Container+SportRecord.swift`, add after `deleteSportRecordsUseCase`:
```swift
    var saveSportRecordUseCase: Factory<SaveSportRecordUseCase> {
        self { DefaultSaveSportRecordUseCase(repository: self.sportRecordRepository()) }.cached
    }
```

- [ ] **Step 3: Build the add screen in `ScreenFactory`**

In `ScreenFactory.swift`, replace `recordsList()` and `addRecord()`:
```swift
    func recordsList() -> some View {
        RecordsListView(
            viewModel: RecordsListViewModel(
                fetch: container.fetchSportRecordsUseCase(),
                delete: container.deleteSportRecordsUseCase(),
                networkMonitor: container.networkMonitor()
            ),
            onAddRecord: { onSaved in router.present(.addRecord(onSaved: onSaved)) }
        )
    }

    func addRecord(onSaved: @escaping () -> Void) -> some View {
        NavigationStack {
            AddRecordView(
                viewModel: AddRecordViewModel(save: container.saveSportRecordUseCase()),
                onSaved: { onSaved(); router.dismissSheet() },
                onCancel: { router.dismissSheet() }
            )
        }
    }
```

- [ ] **Step 4: Present the sheet with its callback**

In `AppFlowView.swift`, replace the sheet switch:
```swift
        .sheet(item: $router.sheet) { sheet in
            switch sheet {
            case .addRecord(let onSaved):
                factory.addRecord(onSaved: onSaved)
            }
        }
```

- [ ] **Step 5: Remove the placeholder**

```bash
git rm SportsTracker/SportsTracker/Navigation/AddRecordPlaceholderView.swift
```

- [ ] **Step 6: Build the app**

```bash
xcodebuild build -project SportsTracker/SportsTracker.xcodeproj -scheme SportsTracker -destination 'generic/platform=iOS Simulator'; echo "EXIT=$?"
```
Expected: EXIT 0, no warnings in app/feature files.

- [ ] **Step 7: Launch smoke test**

Boot a simulator, build for it, install, launch, and confirm no crash (reuse the iteration-1 approach):
```bash
UDID=$(xcrun simctl list devices available -j | python3 -c "import sys,json;d=json.load(sys.stdin);print(next(dev['udid'] for rt,ds in d['devices'].items() if 'iOS-' in rt for dev in ds if dev['isAvailable'] and dev['name'].startswith('iPhone 16')))")
xcrun simctl boot "$UDID" 2>/dev/null; sleep 5
xcodebuild build -project SportsTracker/SportsTracker.xcodeproj -scheme SportsTracker -destination "id=$UDID" -derivedDataPath /tmp/dd-add >/dev/null 2>&1; echo "BUILD EXIT=$?"
APP=$(find /tmp/dd-add/Build/Products -name "SportsTracker.app" -type d | head -1)
xcrun simctl install "$UDID" "$APP" && xcrun simctl launch "$UDID" com.matusselecky.sportstracker
sleep 3; xcrun simctl spawn "$UDID" launchctl list | grep -i sportstracker && echo "alive"
xcrun simctl io "$UDID" screenshot /tmp/add-smoke.png
```
Expected: app launches, process alive. (Driving the form itself — tap +, fill fields, Save, see the row appear and the sheet dismiss — is manual QA / a future XCUITest; the save logic is covered by the Task 1–4 unit tests.)

- [ ] **Step 8: Commit**

```bash
git add SportsTracker/SportsTracker
git commit -m "feat(app): wire add-record sheet with reload-on-save callback"
```

---

## Self-review (against the spec)

- **§2 write path** — data-source `insert` (Task 1), repository `save` routing (Task 2), `SaveSportRecordUseCase` (Task 3), domain→model/DTO mappings (Task 1).
- **§3 add screen** — `AddRecordViewModel` validation/duration/save/failure-message (Task 4); `AddRecordView` + `DurationPicker` + menu storage picker + failure alert (Task 5).
- **§4 wiring** — `Sheet.addRecord(onSaved:)` (Task 7), list carries the reload (Task 6), `ScreenFactory`/`AppFlowView`/DI (Task 7), placeholder removed (Task 7).
- **§5 testing** — use-case forwarding (Task 3), repository routing (Task 2), local insert round-trip (Task 1), remote domain→DTO mapping (Task 1), `AddRecordViewModel` matrix (Task 4).
- **Save failure surfaced** — storage-specific message + preserved form + alert (Tasks 4, 5).
