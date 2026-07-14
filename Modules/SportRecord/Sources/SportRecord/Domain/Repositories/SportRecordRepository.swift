/// Coordinates the two stores: concurrency + partial-failure policy for fetch,
/// and group-by-storageType routing for delete.
/// Per-store gateway. Reads are exposed separately so the fetch use case owns the
/// coordination (first paint, merging, partial-failure policy); writes are routed
/// here by `storageType`.
public protocol SportRecordRepository: Sendable {
    func fetchLocal() async throws -> [SportRecord]
    func fetchRemote() async throws -> [SportRecord]
    func save(_ record: SportRecord) async throws
    func delete(_ records: [SportRecord]) async throws(SportRecordsDeleteError)
}
