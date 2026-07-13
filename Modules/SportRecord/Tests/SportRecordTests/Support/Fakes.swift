import Foundation
import os
import Core
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

final class FakeNetworkMonitor: NetworkMonitor, @unchecked Sendable {
    private let state = OSAllocatedUnfairLock(initialState: (online: true, continuation: AsyncStream<Bool>.Continuation?.none))

    init(isOnline: Bool = true) {
        state.withLock { $0.online = isOnline }
    }

    var isOnline: Bool { state.withLock { $0.online } }

    var updates: AsyncStream<Bool> {
        AsyncStream { continuation in
            let current = state.withLock { current -> Bool in
                current.continuation = continuation
                return current.online
            }
            continuation.yield(current)
        }
    }

    func setOnline(_ online: Bool) {
        state.withLock { current in
            current.online = online
            current.continuation?.yield(online)
        }
    }
}
