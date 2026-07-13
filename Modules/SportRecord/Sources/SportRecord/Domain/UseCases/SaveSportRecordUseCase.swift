public protocol SaveSportRecordUseCase: Sendable {
    func execute(_ record: SportRecord) async throws
}

public struct DefaultSaveSportRecordUseCase: SaveSportRecordUseCase {
    private let repository: SportRecordRepository

    public init(repository: SportRecordRepository) {
        self.repository = repository
    }

    public func execute(_ record: SportRecord) async throws {
        try await repository.save(record)
    }
}
