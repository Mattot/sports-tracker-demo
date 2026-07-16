public protocol FetchLocalRecordsUseCase: Sendable {
    func callAsFunction() async throws -> [SportRecord]
}

public struct DefaultFetchLocalRecordsUseCase: FetchLocalRecordsUseCase {
    private let repository: SportRecordRepository

    public init(repository: SportRecordRepository) {
        self.repository = repository
    }

    public func callAsFunction() async throws -> [SportRecord] {
        try await repository.fetchLocal()
    }
}
