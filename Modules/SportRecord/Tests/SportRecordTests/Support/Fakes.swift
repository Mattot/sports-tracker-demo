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
