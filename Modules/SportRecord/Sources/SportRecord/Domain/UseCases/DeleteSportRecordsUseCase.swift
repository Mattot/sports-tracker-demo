public protocol DeleteSportRecordsUseCase: Sendable {
    func callAsFunction(_ records: [SportRecord]) async throws(SportRecordsDeleteError)
}

public struct DefaultDeleteSportRecordsUseCase: DeleteSportRecordsUseCase {
    private let repository: SportRecordRepository

    public init(repository: SportRecordRepository) {
        self.repository = repository
    }

    public func callAsFunction(_ records: [SportRecord]) async throws(SportRecordsDeleteError) {
        try await repository.delete(records)
    }
}
