import Testing
import Foundation
@testable import SportRecord

// MARK: fetch-local use case — one-shot read of the local store

@Test func fetchLocalReturnsRepositoryRecords() async throws {
    let repo = FakeSportRecordRepository()
    repo.localRecords = [Sample.record(name: "L", storage: .local)]
    let sut = DefaultFetchLocalRecordsUseCase(repository: repo)

    let records = try await sut()

    #expect(records.map(\.name) == ["L"])
}

@Test func fetchLocalUseCasePropagatesError() async {
    let repo = FakeSportRecordRepository()
    repo.localError = AnyError()
    let sut = DefaultFetchLocalRecordsUseCase(repository: repo)

    await #expect(throws: (any Error).self) { try await sut() }
}

// MARK: observe-remote use case — live stream of the remote store

/// Collects every element the stream yields, in order.
private func drain(_ stream: AsyncThrowingStream<[SportRecord], Error>) async throws -> [[SportRecord]] {
    var results: [[SportRecord]] = []
    for try await records in stream { results.append(records) }
    return results
}

@Test func observeRemoteForwardsRepositoryStream() async throws {
    let repo = FakeSportRecordRepository()
    repo.remoteRecords = [Sample.record(name: "R", storage: .remote)]
    let sut = DefaultObserveRemoteRecordsUseCase(repository: repo)

    let results = try await drain(sut())

    #expect(results.map { $0.map(\.name) } == [["R"]])
}

@Test func observeRemotePropagatesStreamFailure() async {
    let repo = FakeSportRecordRepository()
    repo.remoteError = AnyError()
    let sut = DefaultObserveRemoteRecordsUseCase(repository: repo)

    await #expect(throws: (any Error).self) {
        for try await _ in sut() {}
    }
}

// MARK: delete use case

@Test func deleteUseCaseForwardsRecordsToRepository() async throws {
    let repo = FakeSportRecordRepository()
    let records = [Sample.record(), Sample.record(storage: .remote)]
    let sut = DefaultDeleteSportRecordsUseCase(repository: repo)

    try await sut(records)

    #expect(repo.deletedRecords == [records])
}

@Test func deleteUseCasePropagatesTypedError() async {
    let repo = FakeSportRecordRepository()
    repo.deleteError = SportRecordsDeleteError(failedStores: [.local])
    let sut = DefaultDeleteSportRecordsUseCase(repository: repo)

    await #expect(throws: SportRecordsDeleteError(failedStores: [.local])) {
        try await sut([Sample.record()])
    }
}

// MARK: save use case

@Test func saveUseCaseForwardsToRepository() async throws {
    let repo = FakeSportRecordRepository()
    let sut = DefaultSaveSportRecordUseCase(repository: repo)
    let record = Sample.record()
    try await sut(record)
    #expect(repo.savedRecords.map(\.id) == [record.id])
}

@Test func saveUseCasePropagatesError() async {
    let repo = FakeSportRecordRepository()
    repo.saveError = AnyError()
    let sut = DefaultSaveSportRecordUseCase(repository: repo)
    await #expect(throws: (any Error).self) {
        try await sut(Sample.record())
    }
}
