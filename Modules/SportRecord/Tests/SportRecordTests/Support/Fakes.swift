import Foundation
import Core
@testable import SportRecord

/// Fake repository whose read/delete behaviour is set per test. Used on the
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

    func observeRemote() -> AsyncThrowingStream<[SportRecord], Error> {
        let records = remoteRecords
        let shouldFail = remoteError != nil
        return AsyncThrowingStream { continuation in
            if shouldFail {
                continuation.finish(throwing: AnyError())
            } else {
                continuation.yield(records)
                continuation.finish()
            }
        }
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
/// `fetch()` backs the local role; `observeRecords()` backs the remote role and
/// yields the current `records` once before finishing (or throws `fetchError`).
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

    func observeRecords() -> AsyncThrowingStream<[SportRecord], Error> {
        let records = self.records
        let shouldFail = fetchError != nil
        return AsyncThrowingStream { continuation in
            if shouldFail {
                continuation.finish(throwing: AnyError())
            } else {
                continuation.yield(records)
                continuation.finish()
            }
        }
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

struct AnyError: Error, Sendable {}

/// One-shot local read use case: returns `records`, or throws `errorToThrow`.
@MainActor
final class FakeFetchLocalRecordsUseCase: FetchLocalRecordsUseCase {
    var records: [SportRecord] = []
    var errorToThrow: (any Error)?
    private(set) var callCount = 0

    func callAsFunction() async throws -> [SportRecord] {
        callCount += 1
        if let errorToThrow { throw errorToThrow }
        return records
    }
}

/// Remote observation use case: yields each element of `updates` in order, then
/// finishes — throwing when `shouldFail` is set (after emitting any updates).
final class FakeObserveRemoteRecordsUseCase: ObserveRemoteRecordsUseCase, @unchecked Sendable {
    var updates: [[SportRecord]] = []
    var shouldFail = false
    private(set) var callCount = 0

    /// Convenience for tests that only need a single emission.
    var records: [SportRecord] {
        get { updates.last ?? [] }
        set { updates = [newValue] }
    }

    func callAsFunction() -> AsyncThrowingStream<[SportRecord], any Error> {
        callCount += 1
        let updates = self.updates
        let shouldFail = self.shouldFail
        return AsyncThrowingStream { continuation in
            for update in updates { continuation.yield(update) }
            continuation.finish(throwing: shouldFail ? AnyError() : nil)
        }
    }
}

@MainActor
final class FakeDeleteUseCase: DeleteSportRecordsUseCase {
    var errorToThrow: SportRecordsDeleteError?
    private(set) var deletedBatches: [[SportRecord]] = []

    func callAsFunction(_ records: [SportRecord]) async throws(SportRecordsDeleteError) {
        deletedBatches.append(records)
        if let errorToThrow { throw errorToThrow }
    }
}

@MainActor
final class FakeSaveSportRecordUseCase: SaveSportRecordUseCase {
    var errorToThrow: (any Error)?
    private(set) var saved: [SportRecord] = []

    func callAsFunction(_ record: SportRecord) async throws {
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
