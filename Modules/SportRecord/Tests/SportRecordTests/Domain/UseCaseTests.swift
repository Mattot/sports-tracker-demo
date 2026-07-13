import Testing
import Foundation
@testable import SportRecord

@Test func fetchUseCaseForwardsRepositoryResult() async {
    let repo = FakeSportRecordRepository()
    repo.fetchResult = SportRecordsFetchResult(records: [Sample.record()], failedStores: [.remote])
    let sut = DefaultFetchSportRecordsUseCase(repository: repo)

    let result = await sut.execute()

    #expect(result.records.count == 1)
    #expect(result.failedStores == [.remote])
    #expect(repo.fetchCallCount == 1)
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
