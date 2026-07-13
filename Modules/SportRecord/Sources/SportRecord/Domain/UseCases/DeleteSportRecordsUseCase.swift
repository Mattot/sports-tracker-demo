public protocol DeleteSportRecordsUseCase: Sendable {
    func execute(_ records: [SportRecord]) async throws(SportRecordsDeleteError)
}
