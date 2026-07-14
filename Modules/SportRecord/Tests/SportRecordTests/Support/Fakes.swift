import Foundation
import Core
@testable import SportRecord

/// Fake repository whose fetch/delete behaviour is set per test. Used on the
/// main actor in tests; mutable state is therefore not synchronized.
final class FakeSportRecordRepository: SportRecordRepository, @unchecked Sendable {
    var localRecords: [SportRecord] = []
    var remoteRecords: [SportRecord] = []
    var localError: Error?
    var remoteError: Error?
    var deleteError: SportRecordsDeleteError?
    var saveError: Error?
    private(set) var deletedRecords: [[SportRecord]] = []
    private(set) var savedRecords: [SportRecord] = []

    func fetchLocal() async throws -> [SportRecord] {
        if let localError { throw localError }
        return localRecords
    }

    func fetchRemote() async throws -> [SportRecord] {
        if let remoteError { throw remoteError }
        return remoteRecords
    }

    func save(_ record: SportRecord) async throws {
        savedRecords.append(record)
        if let saveError { throw saveError }
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

/// Configurable fake data source usable for both local and remote roles.
final class FakeDataSource: LocalSportRecordDataSource, RemoteSportRecordDataSource, @unchecked Sendable {
    var records: [SportRecord] = []
    var fetchError: Error?
    var deleteError: Error?
    private(set) var deletedIds: [[UUID]] = []
    private(set) var inserted: [SportRecord] = []
    var insertError: Error?

    func fetch() async throws -> [SportRecord] {
        if let fetchError { throw fetchError }
        return records
    }

    func insert(_ record: SportRecord) async throws {
        inserted.append(record)
        if let insertError { throw insertError }
    }

    func delete(ids: [UUID]) async throws {
        deletedIds.append(ids)
        if let deleteError { throw deleteError }
    }
}

struct AnyError: Error {}

/// The stream yields `results` in order; the last one is the combined result.
final class FakeFetchUseCase: FetchSportRecordsUseCase, @unchecked Sendable {
    var results: [SportRecordsFetchResult] = []
    /// Optional gate awaited just before the final yield, so a test can observe
    /// the intermediate (local-first) state.
    var beforeFinalYield: (@Sendable () async -> Void)?
    private(set) var callCount = 0

    /// Convenience for tests that only care about the combined result.
    var result: SportRecordsFetchResult {
        get { results.last ?? SportRecordsFetchResult(records: [], failedStores: []) }
        set { results = [newValue] }
    }

    func execute() -> AsyncStream<SportRecordsFetchResult> {
        callCount += 1
        let results = self.results
        let gate = self.beforeFinalYield
        return AsyncStream { continuation in
            Task {
                for (index, result) in results.enumerated() {
                    if index == results.count - 1, let gate { await gate() }
                    continuation.yield(result)
                }
                continuation.finish()
            }
        }
    }
}

/// A one-shot gate for tests: `wait()` suspends until `release()` is called.
@MainActor
final class MainActorGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var released = false

    func wait() async {
        if released { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func release() {
        released = true
        continuation?.resume()
        continuation = nil
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

@MainActor
final class FakeSaveSportRecordUseCase: SaveSportRecordUseCase {
    var errorToThrow: (any Error)?
    private(set) var saved: [SportRecord] = []

    func execute(_ record: SportRecord) async throws {
        saved.append(record)
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
