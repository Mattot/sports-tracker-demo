public protocol FetchSportRecordsUseCase: Sendable {
    func execute() async -> SportRecordsFetchResult
    /// Fast local-only records for an instant first paint before the combined
    /// (local + remote) result from `execute()` arrives.
    func localSnapshot() async -> [SportRecord]
}

public struct DefaultFetchSportRecordsUseCase: FetchSportRecordsUseCase {
    private let repository: SportRecordRepository

    public init(repository: SportRecordRepository) {
        self.repository = repository
    }

    public func execute() async -> SportRecordsFetchResult {
        await repository.fetch()
    }

    public func localSnapshot() async -> [SportRecord] {
        await repository.localRecords()
    }
}
