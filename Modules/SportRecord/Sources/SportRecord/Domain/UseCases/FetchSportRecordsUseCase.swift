public protocol FetchSportRecordsUseCase: Sendable {
    func execute() async -> SportRecordsFetchResult
}

public struct DefaultFetchSportRecordsUseCase: FetchSportRecordsUseCase {
    private let repository: SportRecordRepository

    public init(repository: SportRecordRepository) {
        self.repository = repository
    }

    public func execute() async -> SportRecordsFetchResult {
        await repository.fetch()
    }
}
