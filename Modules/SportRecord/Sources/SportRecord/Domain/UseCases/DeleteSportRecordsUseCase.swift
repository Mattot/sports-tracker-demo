public protocol DeleteSportRecordsUseCase: Sendable {
    func execute(_ records: [SportRecord]) async throws(SportRecordsDeleteError)
}

public struct DefaultDeleteSportRecordsUseCase: DeleteSportRecordsUseCase {
    private let repository: SportRecordRepository

    public init(repository: SportRecordRepository) {
        self.repository = repository
    }

    public func execute(_ records: [SportRecord]) async throws(SportRecordsDeleteError) {
        try await repository.delete(records)
    }
}
