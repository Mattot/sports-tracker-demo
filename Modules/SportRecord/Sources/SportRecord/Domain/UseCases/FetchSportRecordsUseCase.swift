public protocol FetchSportRecordsUseCase: Sendable {
    func execute() async -> SportRecordsFetchResult
}
