public protocol SportRecordRepository: Sendable {
    func fetchLocal() async throws -> [SportRecord]
    func observeRemote() -> AsyncThrowingStream<[SportRecord], Error>
    func save(_ record: SportRecord) async throws
    func delete(_ records: [SportRecord]) async throws(SportRecordsDeleteError)
}
