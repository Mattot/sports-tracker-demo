import Testing
import Foundation
@testable import SportRecord

// MARK: fetch use case — coordinates the two stores

/// Collects every result the stream yields, in order.
private func drain(_ sut: DefaultFetchSportRecordsUseCase) async -> [SportRecordsFetchResult] {
    var results: [SportRecordsFetchResult] = []
    for await result in sut.execute() { results.append(result) }
    return results
}

@Test func fetchYieldsLocalFirstThenCombined() async {
    let repo = FakeSportRecordRepository()
    repo.localRecords = [Sample.record(name: "L", storage: .local, createdAt: .init(timeIntervalSince1970: 100))]
    repo.remoteRecords = [Sample.record(name: "R", storage: .remote, createdAt: .init(timeIntervalSince1970: 200))]
    let sut = DefaultFetchSportRecordsUseCase(repository: repo)

    let results = await drain(sut)

    #expect(results.count == 2)
    #expect(results.first?.records.map(\.name) == ["L"])          // first paint: local only
    #expect(results.last?.records.map(\.name) == ["R", "L"])      // combined, newest first
    #expect(results.last?.failedStores.isEmpty == true)
}

@Test func fetchSkipsFirstPaintWhenLocalIsEmpty() async {
    let repo = FakeSportRecordRepository()
    repo.remoteRecords = [Sample.record(name: "R", storage: .remote)]
    let sut = DefaultFetchSportRecordsUseCase(repository: repo)

    let results = await drain(sut)

    // Nothing worth painting early, so only the combined result is yielded.
    #expect(results.count == 1)
    #expect(results.last?.records.map(\.name) == ["R"])
}

@Test func fetchKeepsLocalAndFlagsRemoteWhenRemoteFails() async {
    let repo = FakeSportRecordRepository()
    repo.localRecords = [Sample.record(name: "L", storage: .local)]
    repo.remoteError = AnyError()
    let sut = DefaultFetchSportRecordsUseCase(repository: repo)

    let combined = await drain(sut).last

    #expect(combined?.records.map(\.name) == ["L"])
    #expect(combined?.failedStores == [.remote])
}

@Test func fetchFlagsBothWhenBothStoresFail() async {
    let repo = FakeSportRecordRepository()
    repo.localError = AnyError()
    repo.remoteError = AnyError()
    let sut = DefaultFetchSportRecordsUseCase(repository: repo)

    let combined = await drain(sut).last

    #expect(combined?.records.isEmpty == true)
    #expect(combined?.failedStores == [.local, .remote])
}

@Test func deleteUseCaseForwardsRecordsToRepository() async throws {
    let repo = FakeSportRecordRepository()
    let records = [Sample.record(), Sample.record(storage: .remote)]
    let sut = DefaultDeleteSportRecordsUseCase(repository: repo)

    try await sut.execute(records)

    #expect(repo.deletedRecords == [records])
}

@Test func deleteUseCasePropagatesTypedError() async {
    let repo = FakeSportRecordRepository()
    repo.deleteError = SportRecordsDeleteError(failedStores: [.local])
    let sut = DefaultDeleteSportRecordsUseCase(repository: repo)

    await #expect(throws: SportRecordsDeleteError(failedStores: [.local])) {
        try await sut.execute([Sample.record()])
    }
}

@Test func saveUseCaseForwardsToRepository() async throws {
    let repo = FakeSportRecordRepository()
    let sut = DefaultSaveSportRecordUseCase(repository: repo)
    let record = Sample.record()
    try await sut.execute(record)
    #expect(repo.savedRecords.map(\.id) == [record.id])
}

@Test func saveUseCasePropagatesError() async {
    let repo = FakeSportRecordRepository()
    repo.saveError = AnyError()
    let sut = DefaultSaveSportRecordUseCase(repository: repo)
    await #expect(throws: (any Error).self) {
        try await sut.execute(Sample.record())
    }
}
