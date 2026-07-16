public protocol SaveSportRecordUseCase: Sendable {
    func callAsFunction(_ record: SportRecord) async throws
}

public struct DefaultSaveSportRecordUseCase: SaveSportRecordUseCase {
    private let repository: SportRecordRepository

    public init(repository: SportRecordRepository) {
        self.repository = repository
    }

    public func callAsFunction(_ record: SportRecord) async throws {
        try await repository.save(record)
    }
}
