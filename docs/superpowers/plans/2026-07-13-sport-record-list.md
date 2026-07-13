# Sport Record List — Iteration 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the sport-record **list** screen end to end (Domain → Data → Presentation) as two local Swift packages, plus the App composition root, following the approved spec.

**Architecture:** Clean architecture in a `SportRecord` feature package (Domain entities + use cases, Data with SwiftData local + Firestore remote behind a coordinating repository, Presentation MVVM), on top of a `Core` package (reachability + generic UI). Navigation via FlowRouter and DI via Factory live in the App target. iOS 18+, Swift 6 strict concurrency.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, FirebaseFirestore, Factory, Swift Testing, SPM local packages.

> **Post-Phase-A revisions (committed code is source-of-truth):** after Phase A was implemented, a few refinements landed that this doc reflects inline: the `NetworkMonitor` is a lockless stream-only protocol; connectivity is observed from the view's `.task` via `observeConnectivity()` (no stored task/`deinit` in the VM); `RecordsListView` does not own a `NavigationStack` (the App's `AppFlowView` does); the data sources and repository log via `Loggers.data`; the scaffolding placeholders (`Core.swift`, `SportRecord.swift`) were removed once real sources existed; and `.gitignore` commits the Xcode project, `GoogleService-Info.plist`, and `Package.resolved` for a zero-setup clone. The data-source code blocks in Tasks 8/12 and the repository helpers in Task 9 additionally gained `Loggers.data` error logging not re-transcribed here.

---

## Conventions & assumptions

- **Repo root:** `/Users/matusselecky/Documents/Work/Etnetera/sports-tracker`
- **Packages live under** `Modules/Core` and `Modules/SportRecord`. Paths below are relative to the repo root.
- **Test runner (packages):** run from inside the package directory:
  ```bash
  xcodebuild test -scheme <PackageName> -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'
  ```
  Build-only check: `xcodebuild build -scheme <PackageName> -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'`.
  **Environment notes (verified):** in this environment the plain `iPhone 16` device exists only on the **iOS 18.5** runtime, so pin `,OS=18.5` (this also matches the packages' iOS 18 floor). Xcode 26.6's `-quiet` fully *suppresses* the `** TEST SUCCEEDED **` / `** BUILD SUCCEEDED **` banner, so **treat exit code 0 as success** (`echo "EXIT=$?"`); drop `-quiet` (optionally `| tail -30`) if you want to see the banner/test summary. A non-zero exit means failure — inspect the output.
- **Swift Testing** (`import Testing`, `@Test`, `#expect`) — matches the provided navigation template; not XCTest.
- **TDD applies to logic** (entities, use cases, repository, view model, mappers, local data source). **Infrastructure and SwiftUI views** (NWPathMonitor concrete, `MessageBanner`, `ContentStateView`, `RecordsListView`, `SportRecordRow`, the Firestore concrete) are **not** unit-tested — they are verified by compiling/building for the simulator, because they either wrap OS singletons or are view code with no logic to assert without snapshot infra. This is called out per task.
- **Commits:** one per task step as indicated. End each commit message body with the Co-Authored-By trailer already used in this repo.
- **Phase A (Tasks 1–12)** is fully executable now. **Phase B (Tasks 13–15)** requires the Xcode app project the user creates afterward; provide the code and verify in Xcode.

---

## File structure (what each file owns)

```
Modules/
├── Core/
│   ├── Package.swift
│   ├── Sources/Core/
│   │   ├── Networking/NetworkMonitor.swift        // stream-only protocol + lockless PathNetworkMonitor
│   │   ├── Logging/Loggers.swift                  // os.Logger namespace (connectivity)
│   │   └── DesignSystem/
│   │       ├── MessageBanner.swift                // generic banner view
│   │       └── ContentStateView.swift             // loading/empty/failed scaffolding
│   └── Tests/CoreTests/
│       └── SmokeTests.swift                       // verifies the test scheme runs
└── SportRecord/
    ├── Package.swift
    ├── Sources/SportRecord/
    │   ├── Domain/
    │   │   ├── Entities/{SportRecord,StorageType,SportRecordsFetchResult,SportRecordsDeleteError}.swift
    │   │   ├── Repositories/SportRecordRepository.swift
    │   │   └── UseCases/{FetchSportRecordsUseCase,DeleteSportRecordsUseCase}.swift  // protocol + Default impl each
    │   ├── Data/
    │   │   ├── DataSources/
    │   │   │   ├── SportRecordDataSources.swift    // Local/Remote protocols
    │   │   │   ├── Local/{SportRecordModel,SportRecordModel+Mapping,SwiftDataSportRecordDataSource}.swift
    │   │   │   └── Remote/{SportRecordDTO,SportRecordDTO+Mapping,FirestoreSportRecordDataSource}.swift
    │   │   └── Repositories/DefaultSportRecordRepository.swift
    │   ├── Presentation/
    │   │   ├── ViewModel/{RecordsListState,RecordsListViewModel}.swift
    │   │   └── Views/{RecordsListView,SportRecordRow,StorageType+Style}.swift
    │   └── Composition/SportRecordStorage.swift    // public factory helpers hiding data-source concretes
    └── Tests/SportRecordTests/
        ├── Support/{Fakes}.swift
        ├── Domain/UseCaseTests.swift
        ├── Data/{LocalDataSourceTests,RepositoryTests,RemoteMappingTests}.swift
        └── Presentation/RecordsListViewModelTests.swift
```

App target files (Phase B) are listed in Tasks 13–14.

---

# Phase A — Packages

## Task 1: Scaffold the `Core` package

**Files:**
- Create: `Modules/Core/Package.swift`
- Create: `Modules/Core/Sources/Core/Core.swift`
- Test: `Modules/Core/Tests/CoreTests/SmokeTests.swift`

- [ ] **Step 1: Create the package manifest**

`Modules/Core/Package.swift`:
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Core",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "Core", targets: ["Core"]),
    ],
    targets: [
        .target(name: "Core"),
        .testTarget(name: "CoreTests", dependencies: ["Core"]),
    ]
)
```

- [ ] **Step 2: Add a placeholder source so the target compiles**

`Modules/Core/Sources/Core/Core.swift`:
```swift
// Core module. Cross-cutting infrastructure and generic UI shared by features.
```

- [ ] **Step 3: Write a smoke test**

`Modules/Core/Tests/CoreTests/SmokeTests.swift`:
```swift
import Testing
@testable import Core

@Test func coreTestSchemeRuns() {
    #expect(Bool(true))
}
```

- [ ] **Step 4: Run tests to verify the scheme works**

Run:
```bash
cd Modules/Core && xcodebuild test -scheme Core -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
cd /Users/matusselecky/Documents/Work/Etnetera/sports-tracker
git add Modules/Core
git commit -m "chore(core): scaffold Core Swift package"
```

---

## Task 2: `Core` — NetworkMonitor (protocol + NWPathMonitor impl) + Loggers

Infrastructure wrapping an OS singleton — **not unit-tested**; verified by build. A fake for consumers is created later in the feature's test target (Task 10).

**Files:**
- Create: `Modules/Core/Sources/Core/Networking/NetworkMonitor.swift`
- Create: `Modules/Core/Sources/Core/Logging/Loggers.swift`

- [ ] **Step 1: Write the Loggers namespace**

`Modules/Core/Sources/Core/Logging/Loggers.swift`:
```swift
import os

/// Central `os.Logger` namespace for the app's subsystems.
public enum Loggers {
    private static let subsystem = "com.matusselecky.sportstracker"

    public static let connectivity = Logger(subsystem: subsystem, category: "connectivity")
    public static let data = Logger(subsystem: subsystem, category: "data")
}
```

The data layer logs through `Loggers.data`: the SwiftData and Firestore data sources log the raw error before rethrowing; `DefaultSportRecordRepository` logs the coordinated degradation decision at its error-swallowing sites (where errors would otherwise vanish).

- [ ] **Step 2: Write the protocol + concrete monitor (lockless)**

`Modules/Core/Sources/Core/Networking/NetworkMonitor.swift`:
```swift
import Foundation
import Network

/// Observes device connectivity as a stream of "is online" values. Each
/// subscription to `updates` starts its own `NWPathMonitor`, yields the current
/// reachability, then every change, until the consuming task ends.
public protocol NetworkMonitor: Sendable {
    var updates: AsyncStream<Bool> { get }
}

/// `NWPathMonitor`-backed implementation. Lockless: the monitor lives entirely
/// inside the `AsyncStream` closure and is cancelled when the stream terminates
/// (i.e. when the observing task is cancelled), so there is no shared mutable
/// state to synchronize and nothing to reconcile with Swift 6 isolation.
public struct PathNetworkMonitor: NetworkMonitor {
    public init() {}

    public var updates: AsyncStream<Bool> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "com.matusselecky.sportstracker.connectivity")
            monitor.pathUpdateHandler = { path in
                continuation.yield(path.status == .satisfied)
            }
            continuation.onTermination = { _ in
                monitor.cancel()
                Loggers.connectivity.debug("Path monitor cancelled")
            }
            monitor.start(queue: queue)
            Loggers.connectivity.debug("Path monitor started")
        }
    }
}
```

- [ ] **Step 3: Build to verify it compiles**

Run (see the Conventions section for the destination/exit-code note):
```bash
cd Modules/Core && xcodebuild build -scheme Core -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5'
```
Expected: EXIT 0.

- [ ] **Step 4: Commit**

```bash
git add Modules/Core/Sources/Core/Networking Modules/Core/Sources/Core/Logging
git commit -m "feat(core): add NetworkMonitor protocol and NWPathMonitor impl"
```

---

## Task 3: `Core` — generic UI (MessageBanner, ContentStateView)

SwiftUI views with no logic — **not unit-tested**; verified by build.

**Files:**
- Create: `Modules/Core/Sources/Core/DesignSystem/MessageBanner.swift`
- Create: `Modules/Core/Sources/Core/DesignSystem/ContentStateView.swift`

- [ ] **Step 1: Write MessageBanner**

`Modules/Core/Sources/Core/DesignSystem/MessageBanner.swift`:
```swift
import SwiftUI

/// A full-width inline banner for non-blocking status messages (e.g. offline).
public struct MessageBanner: View {
    public enum Style: Sendable {
        case info, warning, error

        var systemImage: String {
            switch self {
            case .info: "info.circle.fill"
            case .warning: "wifi.slash"
            case .error: "exclamationmark.triangle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .info: .blue
            case .warning: .orange
            case .error: .red
            }
        }
    }

    private let text: String
    private let style: Style

    public init(_ text: String, style: Style = .warning) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: style.systemImage)
            Text(text)
                .font(.footnote.weight(.medium))
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.tint.opacity(0.15))
        .foregroundStyle(style.tint)
    }
}
```

- [ ] **Step 2: Write ContentStateView**

`Modules/Core/Sources/Core/DesignSystem/ContentStateView.swift`:
```swift
import SwiftUI

/// Full-screen scaffolding for loading / empty / failed states.
public struct ContentStateView: View {
    public enum State: Sendable {
        case loading
        case empty(title: String, message: String)
        case failed(title: String, message: String)
    }

    private let state: State
    private let onRetry: (() -> Void)?

    public init(state: State, onRetry: (() -> Void)? = nil) {
        self.state = state
        self.onRetry = onRetry
    }

    public var body: some View {
        switch state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .empty(title, message):
            ContentUnavailableView(title, systemImage: "tray", description: Text(message))
        case let .failed(title, message):
            ContentUnavailableView {
                Label(title, systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                if let onRetry {
                    Button("Try Again", action: onRetry)
                }
            }
        }
    }
}
```

- [ ] **Step 3: Build to verify it compiles**

Run:
```bash
cd Modules/Core && xcodebuild build -scheme Core -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Modules/Core/Sources/Core/DesignSystem
git commit -m "feat(core): add MessageBanner and ContentStateView"
```

---

## Task 4: Scaffold the `SportRecord` package

Firebase is **not** added yet — it arrives in Task 12 so earlier tasks build fast and Firebase-free.

**Files:**
- Create: `Modules/SportRecord/Package.swift`
- Create: `Modules/SportRecord/Sources/SportRecord/SportRecord.swift`
- Test: `Modules/SportRecord/Tests/SportRecordTests/SmokeTests.swift`

- [ ] **Step 1: Create the package manifest**

`Modules/SportRecord/Package.swift`:
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SportRecord",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "SportRecord", targets: ["SportRecord"]),
    ],
    dependencies: [
        .package(path: "../Core"),
    ],
    targets: [
        .target(
            name: "SportRecord",
            dependencies: [.product(name: "Core", package: "Core")]
        ),
        .testTarget(
            name: "SportRecordTests",
            dependencies: ["SportRecord"]
        ),
    ]
)
```

- [ ] **Step 2: Add a placeholder source**

`Modules/SportRecord/Sources/SportRecord/SportRecord.swift`:
```swift
// SportRecord feature module: Domain, Data, Presentation for sport records.
```

- [ ] **Step 3: Write a smoke test**

`Modules/SportRecord/Tests/SportRecordTests/SmokeTests.swift`:
```swift
import Testing
@testable import SportRecord

@Test func sportRecordTestSchemeRuns() {
    #expect(Bool(true))
}
```

- [ ] **Step 4: Run tests (also resolves the Core path dependency)**

Run:
```bash
cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Modules/SportRecord
git commit -m "chore(sportrecord): scaffold SportRecord Swift package"
```

---

## Task 5: Domain entities

**Files:**
- Create: `Modules/SportRecord/Sources/SportRecord/Domain/Entities/SportRecord.swift`
- Create: `Modules/SportRecord/Sources/SportRecord/Domain/Entities/StorageType.swift`
- Create: `Modules/SportRecord/Sources/SportRecord/Domain/Entities/SportRecordsFetchResult.swift`
- Create: `Modules/SportRecord/Sources/SportRecord/Domain/Entities/SportRecordsDeleteError.swift`
- Test: `Modules/SportRecord/Tests/SportRecordTests/Domain/EntitiesTests.swift`

- [ ] **Step 1: Write the failing test**

`Modules/SportRecord/Tests/SportRecordTests/Domain/EntitiesTests.swift`:
```swift
import Testing
import Foundation
@testable import SportRecord

@Test func storageTypeHasLocalAndRemote() {
    #expect(Set(StorageType.allCases) == [.local, .remote])
}

@Test func fetchResultDefaultsToNoFailures() {
    let result = SportRecordsFetchResult(records: [], failedStores: [])
    #expect(result.records.isEmpty)
    #expect(result.failedStores.isEmpty)
}

@Test func deleteErrorCarriesFailedStores() {
    let error = SportRecordsDeleteError(failedStores: [.remote])
    #expect(error.failedStores == [.remote])
}

@Test func sportRecordsAreEquatableByValue() {
    let id = UUID()
    let date = Date(timeIntervalSince1970: 0)
    let a = SportRecord(id: id, name: "Run", location: "Park", duration: 60, storageType: .local, createdAt: date)
    let b = SportRecord(id: id, name: "Run", location: "Park", duration: 60, storageType: .local, createdAt: date)
    #expect(a == b)
}
```

- [ ] **Step 2: Run to verify it fails**

Run:
```bash
cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```
Expected: FAIL — `cannot find 'StorageType' in scope` (and the other types).

- [ ] **Step 3: Write the entities**

`Domain/Entities/StorageType.swift`:
```swift
/// Which store a record physically lives in. `All` is a *filter*, not a
/// storage type, so it is intentionally absent here.
public enum StorageType: String, CaseIterable, Sendable {
    case local
    case remote
}
```

`Domain/Entities/SportRecord.swift`:
```swift
import Foundation

/// Domain entity. `storageType` is stamped by whichever data source produced
/// the record and is never persisted, so it can't drift from the record's origin.
public struct SportRecord: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let location: String
    public let duration: TimeInterval   // seconds
    public let storageType: StorageType
    public let createdAt: Date

    public init(
        id: UUID,
        name: String,
        location: String,
        duration: TimeInterval,
        storageType: StorageType,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.duration = duration
        self.storageType = storageType
        self.createdAt = createdAt
    }
}
```

`Domain/Entities/SportRecordsFetchResult.swift`:
```swift
/// Result of a combined fetch across both stores. A single-store failure still
/// returns the other store's records and records which store(s) failed.
public struct SportRecordsFetchResult: Sendable {
    public let records: [SportRecord]         // merged, sorted by createdAt desc
    public let failedStores: Set<StorageType>

    public init(records: [SportRecord], failedStores: Set<StorageType>) {
        self.records = records
        self.failedStores = failedStores
    }
}
```

`Domain/Entities/SportRecordsDeleteError.swift`:
```swift
/// Thrown when one or both stores fail during a delete. Names exactly which
/// store(s) failed; the succeeded store's deletes are already committed.
public struct SportRecordsDeleteError: Error, Equatable, Sendable {
    public let failedStores: Set<StorageType>

    public init(failedStores: Set<StorageType>) {
        self.failedStores = failedStores
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run:
```bash
cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Modules/SportRecord/Sources/SportRecord/Domain/Entities Modules/SportRecord/Tests/SportRecordTests/Domain/EntitiesTests.swift
git commit -m "feat(sportrecord): add domain entities and result/error types"
```

---

## Task 6: Domain protocols (repository, use cases, data sources)

Protocols only — no unit tests (nothing to assert). Verified by build.

**Files:**
- Create: `Modules/SportRecord/Sources/SportRecord/Domain/Repositories/SportRecordRepository.swift`
- Create: `Modules/SportRecord/Sources/SportRecord/Domain/UseCases/FetchSportRecordsUseCase.swift`
- Create: `Modules/SportRecord/Sources/SportRecord/Domain/UseCases/DeleteSportRecordsUseCase.swift`
- Create: `Modules/SportRecord/Sources/SportRecord/Data/DataSources/SportRecordDataSources.swift`

- [ ] **Step 1: Write the repository protocol**

`Domain/Repositories/SportRecordRepository.swift`:
```swift
/// Coordinates the two stores: concurrency + partial-failure policy for fetch,
/// and group-by-storageType routing for delete.
public protocol SportRecordRepository: Sendable {
    func fetch() async -> SportRecordsFetchResult
    func delete(_ records: [SportRecord]) async throws(SportRecordsDeleteError)
}
```

- [ ] **Step 2: Write the use case protocols**

`Domain/UseCases/FetchSportRecordsUseCase.swift`:
```swift
public protocol FetchSportRecordsUseCase: Sendable {
    func execute() async -> SportRecordsFetchResult
}
```

`Domain/UseCases/DeleteSportRecordsUseCase.swift`:
```swift
public protocol DeleteSportRecordsUseCase: Sendable {
    func execute(_ records: [SportRecord]) async throws(SportRecordsDeleteError)
}
```

- [ ] **Step 3: Write the data-source protocols**

`Data/DataSources/SportRecordDataSources.swift`:
```swift
import Foundation

/// Single-store gateway for the local database.
public protocol LocalSportRecordDataSource: Sendable {
    func fetch() async throws -> [SportRecord]
    func delete(ids: [UUID]) async throws
}

/// Single-store gateway for the remote backend.
public protocol RemoteSportRecordDataSource: Sendable {
    func fetch() async throws -> [SportRecord]
    func delete(ids: [UUID]) async throws
}
```

- [ ] **Step 4: Build to verify it compiles**

Run:
```bash
cd Modules/SportRecord && xcodebuild build -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Modules/SportRecord/Sources/SportRecord/Domain/Repositories Modules/SportRecord/Sources/SportRecord/Domain/UseCases Modules/SportRecord/Sources/SportRecord/Data/DataSources/SportRecordDataSources.swift
git commit -m "feat(sportrecord): add repository, use case, and data-source protocols"
```

---

## Task 7: Use case implementations

**Files:**
- Modify: `Modules/SportRecord/Sources/SportRecord/Domain/UseCases/FetchSportRecordsUseCase.swift`
- Modify: `Modules/SportRecord/Sources/SportRecord/Domain/UseCases/DeleteSportRecordsUseCase.swift`
- Create: `Modules/SportRecord/Tests/SportRecordTests/Support/Fakes.swift`
- Test: `Modules/SportRecord/Tests/SportRecordTests/Domain/UseCaseTests.swift`

- [ ] **Step 1: Add a fake repository to the shared test support**

`Tests/SportRecordTests/Support/Fakes.swift`:
```swift
import Foundation
@testable import SportRecord

/// Fake repository whose fetch/delete behaviour is set per test. Used on the
/// main actor in tests; mutable state is therefore not synchronized.
final class FakeSportRecordRepository: SportRecordRepository, @unchecked Sendable {
    var fetchResult = SportRecordsFetchResult(records: [], failedStores: [])
    var deleteError: SportRecordsDeleteError?
    private(set) var fetchCallCount = 0
    private(set) var deletedRecords: [[SportRecord]] = []

    func fetch() async -> SportRecordsFetchResult {
        fetchCallCount += 1
        return fetchResult
    }

    func delete(_ records: [SportRecord]) async throws(SportRecordsDeleteError) {
        deletedRecords.append(records)
        if let deleteError { throw deleteError }
    }
}

/// Deterministic sample records.
enum Sample {
    static func record(
        id: UUID = UUID(),
        name: String = "Run",
        location: String = "Park",
        duration: TimeInterval = 60,
        storage: StorageType = .local,
        createdAt: Date = Date(timeIntervalSince1970: 0)
    ) -> SportRecord {
        SportRecord(id: id, name: name, location: location, duration: duration, storageType: storage, createdAt: createdAt)
    }
}
```

- [ ] **Step 2: Write the failing use case tests**

`Tests/SportRecordTests/Domain/UseCaseTests.swift`:
```swift
import Testing
import Foundation
@testable import SportRecord

@Test func fetchUseCaseForwardsRepositoryResult() async {
    let repo = FakeSportRecordRepository()
    repo.fetchResult = SportRecordsFetchResult(records: [Sample.record()], failedStores: [.remote])
    let sut = DefaultFetchSportRecordsUseCase(repository: repo)

    let result = await sut.execute()

    #expect(result.records.count == 1)
    #expect(result.failedStores == [.remote])
    #expect(repo.fetchCallCount == 1)
}

@Test func deleteUseCaseForwardsRecordsToRepository() async throws {
    let repo = FakeSportRecordRepository()
    let records = [Sample.record(), Sample.record(storage: .remote)]
    let sut = DefaultDeleteSportRecordsUseCase(repository: repo)

    try await sut.execute(records)

    #expect(repo.deletedRecords == [records])
}

@Test func deleteUseCasePropagatesTypedError() async {
    let repo = FakeSportRecordRepository()
    repo.deleteError = SportRecordsDeleteError(failedStores: [.local])
    let sut = DefaultDeleteSportRecordsUseCase(repository: repo)

    await #expect(throws: SportRecordsDeleteError(failedStores: [.local])) {
        try await sut.execute([Sample.record()])
    }
}
```

- [ ] **Step 3: Run to verify it fails**

Run:
```bash
cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```
Expected: FAIL — `cannot find 'DefaultFetchSportRecordsUseCase' in scope`.

- [ ] **Step 4: Add the implementations**

Append to `Domain/UseCases/FetchSportRecordsUseCase.swift`:
```swift

public struct DefaultFetchSportRecordsUseCase: FetchSportRecordsUseCase {
    private let repository: SportRecordRepository

    public init(repository: SportRecordRepository) {
        self.repository = repository
    }

    public func execute() async -> SportRecordsFetchResult {
        await repository.fetch()
    }
}
```

Append to `Domain/UseCases/DeleteSportRecordsUseCase.swift`:
```swift

public struct DefaultDeleteSportRecordsUseCase: DeleteSportRecordsUseCase {
    private let repository: SportRecordRepository

    public init(repository: SportRecordRepository) {
        self.repository = repository
    }

    public func execute(_ records: [SportRecord]) async throws(SportRecordsDeleteError) {
        try await repository.delete(records)
    }
}
```

- [ ] **Step 5: Run to verify it passes**

Run:
```bash
cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Modules/SportRecord/Sources/SportRecord/Domain/UseCases Modules/SportRecord/Tests/SportRecordTests/Support Modules/SportRecord/Tests/SportRecordTests/Domain/UseCaseTests.swift
git commit -m "feat(sportrecord): implement fetch and delete use cases"
```

---

## Task 8: Local data source (SwiftData `@ModelActor`)

**Files:**
- Create: `Modules/SportRecord/Sources/SportRecord/Data/DataSources/Local/SportRecordModel.swift`
- Create: `Modules/SportRecord/Sources/SportRecord/Data/DataSources/Local/SportRecordModel+Mapping.swift`
- Create: `Modules/SportRecord/Sources/SportRecord/Data/DataSources/Local/SwiftDataSportRecordDataSource.swift`
- Test: `Modules/SportRecord/Tests/SportRecordTests/Data/LocalDataSourceTests.swift`

- [ ] **Step 1: Write the failing test**

`Tests/SportRecordTests/Data/LocalDataSourceTests.swift`:
```swift
import Testing
import Foundation
import SwiftData
@testable import SportRecord

@MainActor
private func makeInMemoryContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: SportRecordModel.self, configurations: config)
}

@MainActor
private func seed(_ container: ModelContainer, _ models: [SportRecordModel]) throws {
    let context = ModelContext(container)
    for model in models { context.insert(model) }
    try context.save()
}

@Test @MainActor func fetchReturnsRecordsNewestFirstStampedLocal() async throws {
    let container = try makeInMemoryContainer()
    let older = SportRecordModel(id: UUID(), name: "Old", location: "A", duration: 30, createdAt: Date(timeIntervalSince1970: 100))
    let newer = SportRecordModel(id: UUID(), name: "New", location: "B", duration: 60, createdAt: Date(timeIntervalSince1970: 200))
    try seed(container, [older, newer])
    let sut = SwiftDataSportRecordDataSource(modelContainer: container)

    let records = try await sut.fetch()

    #expect(records.map(\.name) == ["New", "Old"])
    #expect(records.allSatisfy { $0.storageType == .local })
}

@Test @MainActor func deleteRemovesOnlyGivenIds() async throws {
    let container = try makeInMemoryContainer()
    let keep = SportRecordModel(id: UUID(), name: "Keep", location: "A", duration: 30, createdAt: .init(timeIntervalSince1970: 1))
    let drop = SportRecordModel(id: UUID(), name: "Drop", location: "B", duration: 60, createdAt: .init(timeIntervalSince1970: 2))
    try seed(container, [keep, drop])
    let sut = SwiftDataSportRecordDataSource(modelContainer: container)

    try await sut.delete(ids: [drop.id])
    let remaining = try await sut.fetch()

    #expect(remaining.map(\.name) == ["Keep"])
}

@Test @MainActor func deleteMissingIdIsNoOp() async throws {
    let container = try makeInMemoryContainer()
    try seed(container, [SportRecordModel(id: UUID(), name: "Keep", location: "A", duration: 30, createdAt: .init(timeIntervalSince1970: 1))])
    let sut = SwiftDataSportRecordDataSource(modelContainer: container)

    try await sut.delete(ids: [UUID()])
    let remaining = try await sut.fetch()

    #expect(remaining.count == 1)
}
```

- [ ] **Step 2: Run to verify it fails**

Run:
```bash
cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```
Expected: FAIL — `cannot find 'SportRecordModel' in scope`.

- [ ] **Step 3: Write the model**

`Data/DataSources/Local/SportRecordModel.swift`:
```swift
import Foundation
import SwiftData

@Model
final class SportRecordModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var location: String
    var duration: TimeInterval
    var createdAt: Date

    init(id: UUID, name: String, location: String, duration: TimeInterval, createdAt: Date) {
        self.id = id
        self.name = name
        self.location = location
        self.duration = duration
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 4: Write the mapping**

`Data/DataSources/Local/SportRecordModel+Mapping.swift`:
```swift
extension SportRecordModel {
    /// Maps to the domain entity, stamping `.local` at the boundary.
    func toDomain() -> SportRecord {
        SportRecord(
            id: id,
            name: name,
            location: location,
            duration: duration,
            storageType: .local,
            createdAt: createdAt
        )
    }
}
```

- [ ] **Step 5: Write the `@ModelActor` data source**

`Data/DataSources/Local/SwiftDataSportRecordDataSource.swift`:
```swift
import Foundation
import SwiftData

/// Local store gateway. `@ModelActor` gives it an actor-isolated `ModelContext`
/// so SwiftData I/O runs off the main actor with no `Sendable` violations.
@ModelActor
actor SwiftDataSportRecordDataSource: LocalSportRecordDataSource {
    func fetch() async throws -> [SportRecord] {
        let descriptor = FetchDescriptor<SportRecordModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    func delete(ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }
        try modelContext.delete(
            model: SportRecordModel.self,
            where: #Predicate { ids.contains($0.id) }
        )
        try modelContext.save()
    }
}
```

- [ ] **Step 6: Run to verify it passes**

Run:
```bash
cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add Modules/SportRecord/Sources/SportRecord/Data/DataSources/Local Modules/SportRecord/Tests/SportRecordTests/Data/LocalDataSourceTests.swift
git commit -m "feat(sportrecord): add SwiftData local data source"
```

---

## Task 9: Coordinating repository (fetch merge + delete matrix)

**Files:**
- Create: `Modules/SportRecord/Sources/SportRecord/Data/Repositories/DefaultSportRecordRepository.swift`
- Modify: `Modules/SportRecord/Tests/SportRecordTests/Support/Fakes.swift` (add fake data sources)
- Test: `Modules/SportRecord/Tests/SportRecordTests/Data/RepositoryTests.swift`

- [ ] **Step 1: Add fake data sources to the shared support file**

Append to `Tests/SportRecordTests/Support/Fakes.swift`:
```swift

/// Configurable fake data source usable for both local and remote roles.
final class FakeDataSource: LocalSportRecordDataSource, RemoteSportRecordDataSource, @unchecked Sendable {
    var records: [SportRecord] = []
    var fetchError: Error?
    var deleteError: Error?
    private(set) var deletedIds: [[UUID]] = []

    func fetch() async throws -> [SportRecord] {
        if let fetchError { throw fetchError }
        return records
    }

    func delete(ids: [UUID]) async throws {
        deletedIds.append(ids)
        if let deleteError { throw deleteError }
    }
}

struct AnyError: Error {}
```

- [ ] **Step 2: Write the failing repository tests**

`Tests/SportRecordTests/Data/RepositoryTests.swift`:
```swift
import Testing
import Foundation
@testable import SportRecord

private func makeSUT() -> (DefaultSportRecordRepository, local: FakeDataSource, remote: FakeDataSource) {
    let local = FakeDataSource()
    let remote = FakeDataSource()
    return (DefaultSportRecordRepository(local: local, remote: remote), local, remote)
}

// MARK: fetch

@Test func fetchMergesAndSortsByCreatedAtDescending() async {
    let (sut, local, remote) = makeSUT()
    local.records = [Sample.record(name: "L", storage: .local, createdAt: .init(timeIntervalSince1970: 100))]
    remote.records = [Sample.record(name: "R", storage: .remote, createdAt: .init(timeIntervalSince1970: 200))]

    let result = await sut.fetch()

    #expect(result.records.map(\.name) == ["R", "L"])
    #expect(result.failedStores.isEmpty)
}

@Test func fetchReturnsLocalAndFlagsRemoteWhenRemoteFails() async {
    let (sut, local, remote) = makeSUT()
    local.records = [Sample.record(name: "L", storage: .local)]
    remote.fetchError = AnyError()

    let result = await sut.fetch()

    #expect(result.records.map(\.name) == ["L"])
    #expect(result.failedStores == [.remote])
}

@Test func fetchFlagsBothWhenBothFail() async {
    let (sut, local, remote) = makeSUT()
    local.fetchError = AnyError()
    remote.fetchError = AnyError()

    let result = await sut.fetch()

    #expect(result.records.isEmpty)
    #expect(result.failedStores == [.local, .remote])
}

// MARK: delete routing + partial failure matrix

@Test func deleteLocalOnlySuccessRoutesToLocal() async throws {
    let (sut, local, remote) = makeSUT()
    let record = Sample.record(storage: .local)

    try await sut.delete([record])

    #expect(local.deletedIds == [[record.id]])
    #expect(remote.deletedIds.isEmpty)
}

@Test func deleteLocalOnlyFailureThrowsLocal() async {
    let (sut, local, _) = makeSUT()
    local.deleteError = AnyError()

    await #expect(throws: SportRecordsDeleteError(failedStores: [.local])) {
        try await sut.delete([Sample.record(storage: .local)])
    }
}

@Test func deleteRemoteOnlySuccessRoutesToRemote() async throws {
    let (sut, _, remote) = makeSUT()
    let record = Sample.record(storage: .remote)

    try await sut.delete([record])

    #expect(remote.deletedIds == [[record.id]])
}

@Test func deleteRemoteOnlyFailureThrowsRemote() async {
    let (sut, _, remote) = makeSUT()
    remote.deleteError = AnyError()

    await #expect(throws: SportRecordsDeleteError(failedStores: [.remote])) {
        try await sut.delete([Sample.record(storage: .remote)])
    }
}

@Test func deleteMixedBothSucceedRoutesEach() async throws {
    let (sut, local, remote) = makeSUT()
    let l = Sample.record(storage: .local)
    let r = Sample.record(storage: .remote)

    try await sut.delete([l, r])

    #expect(local.deletedIds == [[l.id]])
    #expect(remote.deletedIds == [[r.id]])
}

@Test func deleteMixedRemoteFailsCommitsLocalThrowsRemote() async {
    let (sut, local, remote) = makeSUT()
    remote.deleteError = AnyError()
    let l = Sample.record(storage: .local)
    let r = Sample.record(storage: .remote)

    await #expect(throws: SportRecordsDeleteError(failedStores: [.remote])) {
        try await sut.delete([l, r])
    }
    #expect(local.deletedIds == [[l.id]])   // local still committed
}

@Test func deleteMixedLocalFailsCommitsRemoteThrowsLocal() async {
    let (sut, local, remote) = makeSUT()
    local.deleteError = AnyError()
    let l = Sample.record(storage: .local)
    let r = Sample.record(storage: .remote)

    await #expect(throws: SportRecordsDeleteError(failedStores: [.local])) {
        try await sut.delete([l, r])
    }
    #expect(remote.deletedIds == [[r.id]])   // remote still committed
}

@Test func deleteMixedBothFailThrowsBoth() async {
    let (sut, local, remote) = makeSUT()
    local.deleteError = AnyError()
    remote.deleteError = AnyError()

    await #expect(throws: SportRecordsDeleteError(failedStores: [.local, .remote])) {
        try await sut.delete([Sample.record(storage: .local), Sample.record(storage: .remote)])
    }
}
```

- [ ] **Step 3: Run to verify it fails**

Run:
```bash
cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```
Expected: FAIL — `cannot find 'DefaultSportRecordRepository' in scope`.

- [ ] **Step 4: Write the repository**

`Data/Repositories/DefaultSportRecordRepository.swift`:
```swift
import Foundation

public struct DefaultSportRecordRepository: SportRecordRepository {
    private let local: LocalSportRecordDataSource
    private let remote: RemoteSportRecordDataSource

    public init(local: LocalSportRecordDataSource, remote: RemoteSportRecordDataSource) {
        self.local = local
        self.remote = remote
    }

    public func fetch() async -> SportRecordsFetchResult {
        async let localOpt = fetchLocal()
        async let remoteOpt = fetchRemote()
        let localRecords = await localOpt
        let remoteRecords = await remoteOpt

        var records: [SportRecord] = []
        var failed: Set<StorageType> = []

        if let localRecords { records += localRecords } else { failed.insert(.local) }
        if let remoteRecords { records += remoteRecords } else { failed.insert(.remote) }

        records.sort { $0.createdAt > $1.createdAt }
        return SportRecordsFetchResult(records: records, failedStores: failed)
    }

    public func delete(_ records: [SportRecord]) async throws(SportRecordsDeleteError) {
        let localIDs = records.filter { $0.storageType == .local }.map(\.id)
        let remoteIDs = records.filter { $0.storageType == .remote }.map(\.id)

        async let localOK = deleteLocal(ids: localIDs)
        async let remoteOK = deleteRemote(ids: remoteIDs)
        let (localSucceeded, remoteSucceeded) = await (localOK, remoteOK)

        var failed: Set<StorageType> = []
        if !localSucceeded { failed.insert(.local) }
        if !remoteSucceeded { failed.insert(.remote) }
        if !failed.isEmpty { throw SportRecordsDeleteError(failedStores: failed) }
    }

    // MARK: - Helpers (swallow per-store errors into optional/bool signals)

    private func fetchLocal() async -> [SportRecord]? {
        try? await local.fetch()
    }

    private func fetchRemote() async -> [SportRecord]? {
        try? await remote.fetch()
    }

    private func deleteLocal(ids: [UUID]) async -> Bool {
        guard !ids.isEmpty else { return true }
        do { try await local.delete(ids: ids); return true } catch { return false }
    }

    private func deleteRemote(ids: [UUID]) async -> Bool {
        guard !ids.isEmpty else { return true }
        do { try await remote.delete(ids: ids); return true } catch { return false }
    }
}
```

- [ ] **Step 5: Run to verify it passes**

Run:
```bash
cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Modules/SportRecord/Sources/SportRecord/Data/Repositories Modules/SportRecord/Tests/SportRecordTests/Support/Fakes.swift Modules/SportRecord/Tests/SportRecordTests/Data/RepositoryTests.swift
git commit -m "feat(sportrecord): add coordinating repository with partial-failure policy"
```

---

## Task 10: Presentation state + ViewModel (full VM matrix)

**Files:**
- Create: `Modules/SportRecord/Sources/SportRecord/Presentation/ViewModel/RecordsListState.swift`
- Create: `Modules/SportRecord/Sources/SportRecord/Presentation/ViewModel/RecordsListViewModel.swift`
- Modify: `Modules/SportRecord/Tests/SportRecordTests/Support/Fakes.swift` (add fake use cases + monitor)
- Test: `Modules/SportRecord/Tests/SportRecordTests/Presentation/RecordsListViewModelTests.swift`

- [ ] **Step 1: Add fake use cases + network monitor to support**

Append to `Tests/SportRecordTests/Support/Fakes.swift`:
```swift
import Core

@MainActor
final class FakeFetchUseCase: FetchSportRecordsUseCase {
    var result = SportRecordsFetchResult(records: [], failedStores: [])
    private(set) var callCount = 0

    func execute() async -> SportRecordsFetchResult {
        callCount += 1
        return result
    }
}

@MainActor
final class FakeDeleteUseCase: DeleteSportRecordsUseCase {
    var errorToThrow: SportRecordsDeleteError?
    private(set) var deletedBatches: [[SportRecord]] = []

    func execute(_ records: [SportRecord]) async throws(SportRecordsDeleteError) {
        deletedBatches.append(records)
        if let errorToThrow { throw errorToThrow }
    }
}

final class FakeNetworkMonitor: NetworkMonitor {
    private let stream: AsyncStream<Bool>
    private let continuation: AsyncStream<Bool>.Continuation

    init(isOnline: Bool = true) {
        (stream, continuation) = AsyncStream<Bool>.makeStream()
        continuation.yield(isOnline)
    }

    var updates: AsyncStream<Bool> { stream }

    func setOnline(_ online: Bool) {
        continuation.yield(online)
    }
}
```
(`import Core` is required at the top of `Fakes.swift` for `NetworkMonitor`.)

- [ ] **Step 2: Write the failing state + view-model tests**

`Tests/SportRecordTests/Presentation/RecordsListViewModelTests.swift`:
```swift
import Testing
import Foundation
@testable import SportRecord

@MainActor
private func makeSUT(
    fetchResult: SportRecordsFetchResult = .init(records: [], failedStores: []),
    isOnline: Bool = true
) -> (RecordsListViewModel, fetch: FakeFetchUseCase, delete: FakeDeleteUseCase, monitor: FakeNetworkMonitor) {
    let fetch = FakeFetchUseCase(); fetch.result = fetchResult
    let delete = FakeDeleteUseCase()
    let monitor = FakeNetworkMonitor(isOnline: isOnline)
    let sut = RecordsListViewModel(fetch: fetch, delete: delete, networkMonitor: monitor)
    return (sut, fetch, delete, monitor)
}

// MARK: load / state mapping

@Test @MainActor func loadWithRecordsBecomesLoaded() async {
    let record = Sample.record()
    let (sut, _, _, _) = makeSUT(fetchResult: .init(records: [record], failedStores: []))
    await sut.load()
    #expect(sut.content == .loaded([record]))
}

@Test @MainActor func loadWithNoRecordsAndNoFailureBecomesEmpty() async {
    let (sut, _, _, _) = makeSUT(fetchResult: .init(records: [], failedStores: []))
    await sut.load()
    #expect(sut.content == .empty)
}

@Test @MainActor func loadWithNoRecordsAndBothFailedBecomesFailed() async {
    let (sut, _, _, _) = makeSUT(fetchResult: .init(records: [], failedStores: [.local, .remote]))
    await sut.load()
    #expect(sut.content == .failed)
}

@Test @MainActor func remoteFailureWithLocalRecordsSetsRemoteUnavailable() async {
    let (sut, _, _, _) = makeSUT(fetchResult: .init(records: [Sample.record()], failedStores: [.remote]))
    await sut.load()
    #expect(sut.remoteUnavailable)
}

// MARK: filter

@Test @MainActor func filterChangeDoesNotRefetch() async {
    let local = Sample.record(storage: .local)
    let remote = Sample.record(storage: .remote)
    let (sut, fetch, _, _) = makeSUT(fetchResult: .init(records: [local, remote], failedStores: []))
    await sut.load()

    sut.filter = .local
    #expect(sut.visibleRecords == [local])
    sut.filter = .remote
    #expect(sut.visibleRecords == [remote])
    sut.filter = .all
    #expect(sut.visibleRecords.count == 2)

    #expect(fetch.callCount == 1)   // never refetched on filter switch
}

@Test @MainActor func filterWithNoMatchesKeepsLoadedContent() async {
    let (sut, _, _, _) = makeSUT(fetchResult: .init(records: [Sample.record(storage: .local)], failedStores: []))
    await sut.load()
    sut.filter = .remote
    #expect(sut.visibleRecords.isEmpty)
    if case .loaded = sut.content {} else { Issue.record("content should stay .loaded") }
}

// MARK: offline

@Test @MainActor func observeConnectivityReflectsInitialOfflineState() async {
    let (sut, _, _, _) = makeSUT(isOnline: false)
    let task = Task { await sut.observeConnectivity() }
    defer { task.cancel() }
    // Initial reachability arrives via the monitor stream, so poll for it.
    for _ in 0..<1000 where sut.isOffline == false { await Task.yield() }
    #expect(sut.isOffline)
}

@Test @MainActor func observeConnectivityReflectsGoingOffline() async {
    let (sut, _, _, monitor) = makeSUT(isOnline: true)
    let task = Task { await sut.observeConnectivity() }
    defer { task.cancel() }
    monitor.setOnline(false)
    // Both the initial online and the offline value are buffered; poll until offline.
    for _ in 0..<1000 where sut.isOffline == false { await Task.yield() }
    #expect(sut.isOffline)
}

// MARK: refresh

@Test @MainActor func refreshFailureKeepsExistingList() async {
    let (sut, fetch, _, _) = makeSUT(fetchResult: .init(records: [Sample.record()], failedStores: []))
    await sut.load()
    // Next fetch: total failure.
    fetch.result = .init(records: [], failedStores: [.local, .remote])
    await sut.refresh()
    if case .loaded(let r) = sut.content { #expect(r.count == 1) } else { Issue.record("list was blown away") }
}

// MARK: swipe delete

@Test @MainActor func swipeDeleteLocalSuccessRemovesRow() async {
    let record = Sample.record(storage: .local)
    let (sut, _, _, _) = makeSUT(fetchResult: .init(records: [record], failedStores: []))
    await sut.load()
    await sut.delete(record)
    #expect(sut.content == .empty)
    #expect(sut.deleteError == nil)
}

@Test @MainActor func swipeDeleteRemoteFailureKeepsRowAndSetsError() async {
    let record = Sample.record(storage: .remote)
    let (sut, _, delete, _) = makeSUT(fetchResult: .init(records: [record], failedStores: []))
    await sut.load()
    delete.errorToThrow = SportRecordsDeleteError(failedStores: [.remote])
    await sut.delete(record)
    if case .loaded(let r) = sut.content { #expect(r.count == 1) } else { Issue.record("row removed on failure") }
    #expect(sut.deleteError != nil)
}

// MARK: batch delete

@Test @MainActor func batchDeleteSuccessClearsSelectionAndExitsEdit() async {
    let a = Sample.record(storage: .local)
    let b = Sample.record(storage: .remote)
    let (sut, _, _, _) = makeSUT(fetchResult: .init(records: [a, b], failedStores: []))
    await sut.load()
    sut.isEditing = true
    sut.selection = [a.id, b.id]
    await sut.deleteSelected()
    #expect(sut.content == .empty)
    #expect(sut.selection.isEmpty)
    #expect(sut.isEditing == false)
}

@Test @MainActor func batchDeleteMixedRemoteFailsRemovesLocalKeepsRemote() async {
    let a = Sample.record(storage: .local)
    let b = Sample.record(storage: .remote)
    let (sut, _, delete, _) = makeSUT(fetchResult: .init(records: [a, b], failedStores: []))
    await sut.load()
    sut.isEditing = true
    sut.selection = [a.id, b.id]
    delete.errorToThrow = SportRecordsDeleteError(failedStores: [.remote])
    await sut.deleteSelected()

    if case .loaded(let r) = sut.content { #expect(r.map(\.id) == [b.id]) } else { Issue.record("unexpected content") }
    #expect(sut.selection == [b.id])   // reduced to failed rows
    #expect(sut.isEditing)             // stays in edit mode
    #expect(sut.deleteError != nil)
}

@Test @MainActor func batchDeleteBothFailKeepsEverythingSelected() async {
    let a = Sample.record(storage: .local)
    let b = Sample.record(storage: .remote)
    let (sut, _, delete, _) = makeSUT(fetchResult: .init(records: [a, b], failedStores: []))
    await sut.load()
    sut.isEditing = true
    sut.selection = [a.id, b.id]
    delete.errorToThrow = SportRecordsDeleteError(failedStores: [.local, .remote])
    await sut.deleteSelected()

    if case .loaded(let r) = sut.content { #expect(r.count == 2) } else { Issue.record("rows removed") }
    #expect(sut.selection == [a.id, b.id])
    #expect(sut.isEditing)
}
```

- [ ] **Step 3: Run to verify it fails**

Run:
```bash
cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```
Expected: FAIL — `cannot find 'RecordsListViewModel' in scope`.

- [ ] **Step 4: Write the state types**

`Presentation/ViewModel/RecordsListState.swift`:
```swift
/// Primary content state of the list, independent of the offline banner.
public enum RecordsContentState: Sendable, Equatable {
    case loading
    case empty
    case loaded([SportRecord])
    case failed
}

/// Segmented-control filter. `all` shows both stores.
public enum RecordsFilter: String, CaseIterable, Sendable, Identifiable {
    case all
    case local
    case remote

    public var id: Self { self }

    public var title: String {
        switch self {
        case .all: "All"
        case .local: "Local"
        case .remote: "Remote"
        }
    }
}
```

- [ ] **Step 5: Write the ViewModel**

`Presentation/ViewModel/RecordsListViewModel.swift`:
```swift
import Foundation
import Observation
import Core

@MainActor
@Observable
public final class RecordsListViewModel {
    private let fetchUseCase: FetchSportRecordsUseCase
    private let deleteUseCase: DeleteSportRecordsUseCase
    private let networkMonitor: NetworkMonitor

    public private(set) var content: RecordsContentState = .loading
    public var filter: RecordsFilter = .all
    public private(set) var isRefreshing = false
    public private(set) var remoteUnavailable = false
    public private(set) var isOffline = false
    public var isEditing = false
    public var selection: Set<UUID> = []
    public var isDeleteConfirmationPresented = false
    public var deleteError: String?

    public init(
        fetch: FetchSportRecordsUseCase,
        delete: DeleteSportRecordsUseCase,
        networkMonitor: NetworkMonitor
    ) {
        self.fetchUseCase = fetch
        self.deleteUseCase = delete
        self.networkMonitor = networkMonitor
    }

    deinit {
        monitorTask?.cancel()
    }

    // MARK: - Derived

    private var loadedRecords: [SportRecord] {
        if case let .loaded(records) = content { records } else { [] }
    }

    public var visibleRecords: [SportRecord] {
        loadedRecords.filter { record in
            switch filter {
            case .all: true
            case .local: record.storageType == .local
            case .remote: record.storageType == .remote
            }
        }
    }

    // MARK: - Loading

    public func load() async {
        if loadedRecords.isEmpty { content = .loading }
        applyContent(await fetchUseCase.execute())
    }

    public func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        let result = await fetchUseCase.execute()
        remoteUnavailable = result.failedStores.contains(.remote)
        // Don't destroy a good list because a refresh couldn't load anything.
        if result.records.isEmpty, !result.failedStores.isEmpty, !loadedRecords.isEmpty {
            return
        }
        applyContent(result)
    }

    public func retry() async {
        await load()
    }

    private func applyContent(_ result: SportRecordsFetchResult) {
        remoteUnavailable = result.failedStores.contains(.remote)
        if result.records.isEmpty {
            content = result.failedStores.isEmpty ? .empty : .failed
        } else {
            content = .loaded(result.records)
        }
    }

    // MARK: - Deletion

    public func delete(_ record: SportRecord) async {
        do {
            try await deleteUseCase.execute([record])
            removeRecords(ids: [record.id])
        } catch {
            deleteError = message(for: error.failedStores)
        }
    }

    public func requestDeleteSelection() {
        isDeleteConfirmationPresented = true
    }

    public func deleteSelected() async {
        let selected = loadedRecords.filter { selection.contains($0.id) }
        guard !selected.isEmpty else { return }
        do {
            try await deleteUseCase.execute(selected)
            removeRecords(ids: selection)
            selection = []
            isEditing = false
        } catch {
            let failed = error.failedStores
            let succeeded = selected.filter { !failed.contains($0.storageType) }
            removeRecords(ids: Set(succeeded.map(\.id)))
            selection = Set(selected.filter { failed.contains($0.storageType) }.map(\.id))
            deleteError = message(for: failed)
        }
    }

    private func removeRecords(ids: Set<UUID>) {
        guard case var .loaded(records) = content else { return }
        records.removeAll { ids.contains($0.id) }
        content = records.isEmpty ? .empty : .loaded(records)
    }

    private func message(for stores: Set<StorageType>) -> String {
        switch (stores.contains(.local), stores.contains(.remote)) {
        case (true, true): "Couldn't delete some records. Check your connection and try again."
        case (false, true): "Couldn't delete remote records. You may be offline."
        case (true, false): "Couldn't delete local records. Please try again."
        case (false, false): "Couldn't delete records."
        }
    }

    // MARK: - Network

    /// Observes connectivity until the calling task is cancelled. Drive this from
    /// the view's `.task` so SwiftUI ties its lifetime to the view — no stored
    /// task, no `deinit`, no manual cancellation. `isOffline` starts optimistic
    /// (false) and is corrected by the stream's first value.
    public func observeConnectivity() async {
        for await online in networkMonitor.updates {
            isOffline = !online
        }
    }
}
```

- [ ] **Step 6: Run to verify it passes**

Run:
```bash
cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add Modules/SportRecord/Sources/SportRecord/Presentation/ViewModel Modules/SportRecord/Tests/SportRecordTests/Support/Fakes.swift Modules/SportRecord/Tests/SportRecordTests/Presentation
git commit -m "feat(sportrecord): add RecordsListViewModel with full state + delete handling"
```

---

## Task 11: Presentation views (RecordsListView, SportRecordRow, storage style)

SwiftUI view code — **not unit-tested**; verified by building the package for the simulator.

**Files:**
- Create: `Modules/SportRecord/Sources/SportRecord/Presentation/Views/StorageType+Style.swift`
- Create: `Modules/SportRecord/Sources/SportRecord/Presentation/Views/SportRecordRow.swift`
- Create: `Modules/SportRecord/Sources/SportRecord/Presentation/Views/RecordsListView.swift`

- [ ] **Step 1: Write the storage-type style helper**

`Presentation/Views/StorageType+Style.swift`:
```swift
import SwiftUI

extension StorageType {
    /// Colour used to visually distinguish records by store (assignment requirement).
    var accentColor: Color {
        switch self {
        case .local: .blue
        case .remote: .purple
        }
    }

    var label: String {
        switch self {
        case .local: "Local"
        case .remote: "Remote"
        }
    }
}
```

- [ ] **Step 2: Write the row**

`Presentation/Views/SportRecordRow.swift`:
```swift
import SwiftUI

struct SportRecordRow: View {
    let record: SportRecord

    private var formattedDuration: String {
        Duration.seconds(record.duration)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(record.storageType.accentColor)
                .frame(width: 4)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.name)
                    .font(.headline)
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                    Text(record.location)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedDuration)
                    .font(.callout.monospacedDigit())
                Text(record.storageType.label)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(record.storageType.accentColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(record.storageType.accentColor)
            }
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 3: Write the screen**

`Presentation/Views/RecordsListView.swift`:
```swift
import SwiftUI
import Core

public struct RecordsListView: View {
    @State private var viewModel: RecordsListViewModel
    private let onAddRecord: () -> Void

    public init(viewModel: RecordsListViewModel, onAddRecord: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onAddRecord = onAddRecord
    }

    // Root view of the App-owned NavigationStack — it must NOT introduce its own
    // stack, so navigation state (path, title, toolbar) stays composed in App.
    public var body: some View {
        content
            .navigationTitle("Sport Records")
            .safeAreaInset(edge: .top, spacing: 0) { banner }
            .toolbar { toolbarContent }
            .confirmationDialog(
                "Delete \(viewModel.selection.count) record(s)?",
                isPresented: $viewModel.isDeleteConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task { await viewModel.deleteSelected() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert(
                "Delete failed",
                isPresented: Binding(
                    get: { viewModel.deleteError != nil },
                    set: { if !$0 { viewModel.deleteError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.deleteError ?? "")
            }
            .task { await viewModel.load() }
            .task { await viewModel.observeConnectivity() }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.content {
        case .loading:
            ContentStateView(state: .loading)
        case .empty:
            ContentStateView(state: .empty(title: "No Sport Records", message: "Add your first activity to see it here."))
        case .failed:
            ContentStateView(
                state: .failed(title: "Couldn't Load Records", message: "Something went wrong reaching your data."),
                onRetry: { Task { await viewModel.retry() } }
            )
        case .loaded:
            list
        }
    }

    private var list: some View {
        List(selection: $viewModel.selection) {
            Section {
                if viewModel.visibleRecords.isEmpty {
                    Text("No \(viewModel.filter.title.lowercased()) records")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.visibleRecords) { record in
                        SportRecordRow(record: record)
                            .tag(record.id)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await viewModel.delete(record) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            } header: {
                Picker("Filter", selection: $viewModel.filter) {
                    ForEach(RecordsFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .textCase(nil)
                .listRowInsets(EdgeInsets())
                .padding(.bottom, 8)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(viewModel.isEditing ? .active : .inactive))
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Banner

    @ViewBuilder
    private var banner: some View {
        if viewModel.isOffline {
            MessageBanner("You're offline — showing local records.", style: .warning)
        } else if viewModel.remoteUnavailable {
            MessageBanner("Couldn't reach remote — showing local records.", style: .info)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(viewModel.isEditing ? "Done" : "Select") {
                viewModel.isEditing.toggle()
                if !viewModel.isEditing { viewModel.selection = [] }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if viewModel.isEditing {
                Button("Delete", role: .destructive) {
                    viewModel.requestDeleteSelection()
                }
                .disabled(viewModel.selection.isEmpty)
            } else {
                Button {
                    onAddRecord()
                } label: {
                    Label("Add Record", systemImage: "plus")
                }
            }
        }
    }
}
```

- [ ] **Step 4: Build to verify it compiles**

Run:
```bash
cd Modules/SportRecord && xcodebuild build -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Modules/SportRecord/Sources/SportRecord/Presentation/Views
git commit -m "feat(sportrecord): add records list view, row, and storage styling"
```

---

## Task 12: Remote data source (Firestore) + composition helpers

Adds the Firebase dependency. The DTO + mapping are pure and **unit-tested**; the Firestore query code is **compile-only** (live Firestore is out of scope per the spec). Also adds the public composition helpers the App needs so data-source concretes stay internal.

**Files:**
- Modify: `Modules/SportRecord/Package.swift` (add Firebase)
- Create: `Modules/SportRecord/Sources/SportRecord/Data/DataSources/Remote/SportRecordDTO.swift`
- Create: `Modules/SportRecord/Sources/SportRecord/Data/DataSources/Remote/SportRecordDTO+Mapping.swift`
- Create: `Modules/SportRecord/Sources/SportRecord/Data/DataSources/Remote/FirestoreSportRecordDataSource.swift`
- Create: `Modules/SportRecord/Sources/SportRecord/Composition/SportRecordStorage.swift`
- Test: `Modules/SportRecord/Tests/SportRecordTests/Data/RemoteMappingTests.swift`

- [ ] **Step 1: Add Firebase to the manifest**

Replace `Modules/SportRecord/Package.swift` with:
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SportRecord",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "SportRecord", targets: ["SportRecord"]),
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.0.0"),
    ],
    targets: [
        .target(
            name: "SportRecord",
            dependencies: [
                .product(name: "Core", package: "Core"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
            ]
        ),
        .testTarget(
            name: "SportRecordTests",
            dependencies: ["SportRecord"]
        ),
    ]
)
```

- [ ] **Step 2: Write the failing mapping test**

`Tests/SportRecordTests/Data/RemoteMappingTests.swift`:
```swift
import Testing
import Foundation
@testable import SportRecord

@Test func dtoMapsToDomainStampedRemote() {
    let id = UUID()
    let dto = SportRecordDTO(name: "Swim", location: "Pool", duration: 1800, createdAt: Date(timeIntervalSince1970: 42))

    let record = dto.toDomain(id: id)

    #expect(record.id == id)
    #expect(record.name == "Swim")
    #expect(record.location == "Pool")
    #expect(record.duration == 1800)
    #expect(record.createdAt == Date(timeIntervalSince1970: 42))
    #expect(record.storageType == .remote)
}
```

- [ ] **Step 3: Run to verify it fails**

Run:
```bash
cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```
Expected: FAIL — `cannot find 'SportRecordDTO' in scope`. (First run also resolves the Firebase package — this is slow the first time.)

- [ ] **Step 4: Write the DTO + mapping**

`Data/DataSources/Remote/SportRecordDTO.swift`:
```swift
import Foundation

/// Firestore document body. The document ID holds the record's UUID, so the id
/// is not duplicated inside the document.
struct SportRecordDTO: Codable, Sendable {
    let name: String
    let location: String
    let duration: TimeInterval
    let createdAt: Date
}
```

`Data/DataSources/Remote/SportRecordDTO+Mapping.swift`:
```swift
import Foundation

extension SportRecordDTO {
    /// Maps to the domain entity, stamping `.remote` at the boundary.
    func toDomain(id: UUID) -> SportRecord {
        SportRecord(
            id: id,
            name: name,
            location: location,
            duration: duration,
            storageType: .remote,
            createdAt: createdAt
        )
    }
}
```

- [ ] **Step 5: Write the Firestore data source**

`Data/DataSources/Remote/FirestoreSportRecordDataSource.swift`:
```swift
import Foundation
import FirebaseFirestore

/// Remote store gateway backed by Firestore. Document ID == record UUID.
struct FirestoreSportRecordDataSource: RemoteSportRecordDataSource {
    private let collectionName = "sportRecords"

    private var collection: CollectionReference {
        Firestore.firestore().collection(collectionName)
    }

    func fetch() async throws -> [SportRecord] {
        let snapshot = try await collection
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return try snapshot.documents.compactMap { document in
            guard let id = UUID(uuidString: document.documentID) else { return nil }
            let dto = try document.data(as: SportRecordDTO.self)
            return dto.toDomain(id: id)
        }
    }

    func delete(ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }
        let batch = Firestore.firestore().batch()
        for id in ids {
            batch.deleteDocument(collection.document(id.uuidString))
        }
        try await batch.commit()
    }
}
```

- [ ] **Step 6: Write the composition helpers**

`Composition/SportRecordStorage.swift`:
```swift
import Foundation
import SwiftData

/// Public composition seam for the App. Keeps the data-source concretes internal
/// while exposing exactly what the DI container needs to build them.
public enum SportRecordStorage {
    /// Builds the SwiftData container for this feature's schema.
    public static func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([SportRecordModel.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    public static func makeLocalDataSource(container: ModelContainer) -> LocalSportRecordDataSource {
        SwiftDataSportRecordDataSource(modelContainer: container)
    }

    public static func makeRemoteDataSource() -> RemoteSportRecordDataSource {
        FirestoreSportRecordDataSource()
    }
}
```

- [ ] **Step 7: Run to verify it passes**

Run:
```bash
cd Modules/SportRecord && xcodebuild test -scheme SportRecord -destination 'platform=iOS Simulator,name=iPhone 16' -quiet
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git add Modules/SportRecord/Package.swift Modules/SportRecord/Sources/SportRecord/Data/DataSources/Remote Modules/SportRecord/Sources/SportRecord/Composition Modules/SportRecord/Tests/SportRecordTests/Data/RemoteMappingTests.swift
git commit -m "feat(sportrecord): add Firestore remote data source and composition helpers"
```

---

# Phase B — App integration (after you create the Xcode project)

> These tasks assume the Xcode app project exists at the repo root, with the `Core` and `SportRecord` local packages added, the **Factory** package added (`https://github.com/hmlongco/Factory`, from 2.4.0), the **firebase-ios-sdk** package added with the **FirebaseFirestore** product linked to the app target, and `GoogleService-Info.plist` in the app target. Verification is by **building and running in Xcode** (`⌘R`) — there are no package tests for the app target.

## Task 13: DI container registrations

**Files:**
- Create: `<App>/DI/Container+SportRecord.swift`

- [ ] **Step 1: Write the Factory registrations**

`<App>/DI/Container+SportRecord.swift`:
```swift
import Factory
import SwiftData
import Core
import SportRecord

extension Container {
    var networkMonitor: Factory<NetworkMonitor> {
        self { PathNetworkMonitor() }.singleton
    }

    var modelContainer: Factory<ModelContainer> {
        self {
            do {
                return try SportRecordStorage.makeModelContainer()
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }.singleton
    }

    var localSportRecordDataSource: Factory<LocalSportRecordDataSource> {
        self { SportRecordStorage.makeLocalDataSource(container: self.modelContainer()) }.singleton
    }

    var remoteSportRecordDataSource: Factory<RemoteSportRecordDataSource> {
        self { SportRecordStorage.makeRemoteDataSource() }.singleton
    }

    var sportRecordRepository: Factory<SportRecordRepository> {
        self {
            DefaultSportRecordRepository(
                local: self.localSportRecordDataSource(),
                remote: self.remoteSportRecordDataSource()
            )
        }.singleton
    }

    var fetchSportRecordsUseCase: Factory<FetchSportRecordsUseCase> {
        self { DefaultFetchSportRecordsUseCase(repository: self.sportRecordRepository()) }.cached
    }

    var deleteSportRecordsUseCase: Factory<DeleteSportRecordsUseCase> {
        self { DefaultDeleteSportRecordsUseCase(repository: self.sportRecordRepository()) }.cached
    }
}
```

- [ ] **Step 2: Verify it compiles in Xcode**

Build the app target (`⌘B`). Expected: build succeeds. (No run needed yet.)

- [ ] **Step 3: Commit**

```bash
git add "<App>/DI/Container+SportRecord.swift"
git commit -m "feat(app): register SportRecord dependencies in Factory container"
```

---

## Task 14: Navigation + composition root

Adapts the provided `SportAppNavigation.swift` template: the `ScreenFactory` resolves use cases + monitor from the container and constructs the `RecordsListViewModel`; the add-record sheet renders an iteration-1 placeholder.

**Files:**
- Create: `<App>/Navigation/AppRouter.swift`
- Create: `<App>/Navigation/ScreenFactory.swift`
- Create: `<App>/Navigation/AppFlowView.swift`
- Create: `<App>/Navigation/AddRecordPlaceholderView.swift`
- Create/Modify: `<App>/SportApp.swift`

- [ ] **Step 1: Router (from template)**

`<App>/Navigation/AppRouter.swift`:
```swift
import SwiftUI
import Observation

enum Route: Hashable, Codable, Sendable {}

enum Sheet: Identifiable, Hashable {
    case addRecord
    var id: Self { self }
}

@Observable
@MainActor
final class AppRouter {
    var path: [Route] = []
    var sheet: Sheet?

    func push(_ route: Route) { path.append(route) }
    func pop() { guard !path.isEmpty else { return }; path.removeLast() }
    func popToRoot() { path.removeAll() }

    func presentAddRecord() { sheet = .addRecord }
    func dismissSheet() { sheet = nil }
}
```

- [ ] **Step 2: Add-record placeholder (iteration 2 replaces this)**

`<App>/Navigation/AddRecordPlaceholderView.swift`:
```swift
import SwiftUI

struct AddRecordPlaceholderView: View {
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Add Record",
                systemImage: "plus.circle",
                description: Text("Coming in iteration 2.")
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }
            }
        }
    }
}
```

- [ ] **Step 3: Screen factory (composition root)**

`<App>/Navigation/ScreenFactory.swift`:
```swift
import SwiftUI
import Factory
import SportRecord

@MainActor
struct ScreenFactory {
    let container: Container
    let router: AppRouter

    func recordsList() -> some View {
        RecordsListView(
            viewModel: RecordsListViewModel(
                fetch: container.fetchSportRecordsUseCase(),
                delete: container.deleteSportRecordsUseCase(),
                networkMonitor: container.networkMonitor()
            ),
            onAddRecord: { router.presentAddRecord() }
        )
    }

    func addRecord() -> some View {
        AddRecordPlaceholderView(onClose: { router.dismissSheet() })
    }
}
```

- [ ] **Step 4: Flow view**

`<App>/Navigation/AppFlowView.swift`:
```swift
import SwiftUI

struct AppFlowView: View {
    @Bindable var router: AppRouter
    let factory: ScreenFactory

    var body: some View {
        NavigationStack(path: $router.path) {
            factory.recordsList()
                .navigationDestination(for: Route.self) { route in
                    switch route {}   // exhaustive over the uninhabited Route enum
                }
        }
        .sheet(item: $router.sheet) { sheet in
            switch sheet {
            case .addRecord:
                factory.addRecord()
            }
        }
    }
}
```
(Note: the App owns the `NavigationStack` here; `RecordsListView` is only its root view and must not introduce its own stack. The first push is one `Route` case + one `navigationDestination` branch — nothing structural changes.)

- [ ] **Step 5: App entry**

`<App>/SportApp.swift`:
```swift
import SwiftUI
import Factory
import FirebaseCore

@main
struct SportApp: App {
    @State private var router = AppRouter()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            AppFlowView(
                router: router,
                factory: ScreenFactory(container: .shared, router: router)
            )
        }
    }
}
```

- [ ] **Step 6: Verify in Xcode**

Build and run (`⌘R`) on an iOS 18 simulator. Expected: the app launches to the Sport Records list (empty state, since no data yet), no crash, Firebase configured in the console log.

- [ ] **Step 7: Commit**

```bash
git add "<App>/Navigation" "<App>/SportApp.swift"
git commit -m "feat(app): wire navigation, composition root, and Firebase configure"
```

---

## Task 15: Manual verification in the running app

No code — a checklist confirming the assignment's list requirements against the running app. Seed a few records directly in Firestore and via a temporary local insert (or defer local records to iteration 2's add screen) to exercise the states.

- [ ] Launch on a simulator → **empty state** shows ("No Sport Records").
- [ ] With records present → list renders, **rows colour-coded** by storage type (blue local / purple remote), duration formatted ("30m", "1h 23m").
- [ ] **Segmented filter** All / Local / Remote filters in place; switching does **not** re-hit the network (observe: no loading spinner between switches).
- [ ] **Pull to refresh** reloads.
- [ ] **Swipe to delete** removes a row; deleting a remote record while offline surfaces the **delete-failed alert** and keeps the row.
- [ ] **Select** (edit mode) → multi-select → **Delete** → **confirmation dialog** → deletes selected; on partial failure the failed rows stay selected with an alert.
- [ ] **Airplane mode** → **offline banner** appears; local records still listed.
- [ ] **Rotate** device → layout works in **portrait and landscape**.
- [ ] Verify no purple-triangle runtime warnings for main-actor/publishing-changes in the console.

---

## Self-review notes (verification against the spec)

- **§2 module/layer layout** → Tasks 1–4 scaffold `Core`/`SportRecord`; file structure matches the spec's folder tree (Entities/Repositories/UseCases, DataSources/Repositories, ViewModel/Views).
- **§3 domain** (entities, fetch result, typed delete error, repository + use case protocols, filter-out-of-domain) → Tasks 5–7.
- **§4 data** (`@ModelActor` local, DTO/mapping, coordinating repository with `async let` + partial failure, group-by-type delete) → Tasks 8, 9, 12.
- **§5 presentation** (state enum, VM with all fields/methods, thin view with banner/segmented/refresh/swipe/edit-multi-delete/confirmation/alert, duration formatting, colour coding) → Tasks 10, 11.
- **§6 DI** (Factory scopes, ViewModel built in ScreenFactory via constructor injection, Firebase configure) → Tasks 13, 14.
- **§7 testing** — fetch/state tests (Task 10), repository fetch + **full delete matrix** (Task 9), **VM swipe + batch delete matrix** (Task 10), local data source in-memory round-trip (Task 8), remote mapping + protocol-faked remote (Tasks 9, 12).
- **Assignment constraints** — no Storyboards/XIBs (SwiftUI only); portrait + landscape (Task 15 check); unified architecture (Clean across all tasks); All/Local/Remote filter + colour coding (Tasks 10, 11).
- **Out of scope (§8)** — add-record screen deferred; only the sheet seam + placeholder wired (Task 14).
```
