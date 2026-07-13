/// Coordinates the two stores: concurrency + partial-failure policy for fetch,
/// and group-by-storageType routing for delete.
public protocol SportRecordRepository: Sendable {
    func fetch() async -> SportRecordsFetchResult
    func save(_ record: SportRecord) async throws
    func delete(_ records: [SportRecord]) async throws(SportRecordsDeleteError)
}
