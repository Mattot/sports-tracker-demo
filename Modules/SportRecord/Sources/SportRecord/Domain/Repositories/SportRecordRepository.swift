/// Coordinates the two stores: concurrency + partial-failure policy for fetch,
/// and group-by-storageType routing for delete.
public protocol SportRecordRepository: Sendable {
    func fetch() async -> SportRecordsFetchResult
    /// Local-store records only, for an instant first paint that doesn't wait on
    /// the (possibly slow/offline) remote store. Returns `[]` if the local read fails.
    func localRecords() async -> [SportRecord]
    func save(_ record: SportRecord) async throws
    func delete(_ records: [SportRecord]) async throws(SportRecordsDeleteError)
}
