import Testing
import Foundation
@testable import SportRecord

private func makeSUT() -> (DefaultSportRecordRepository, local: FakeDataSource, remote: FakeDataSource) {
    let local = FakeDataSource()
    let remote = FakeDataSource()
    return (DefaultSportRecordRepository(local: local, remote: remote), local, remote)
}

// MARK: per-store fetch (coordination lives in the fetch use case, not here)

@Test func fetchLocalReturnsLocalStoreRecords() async throws {
    let (sut, local, remote) = makeSUT()
    local.records = [Sample.record(name: "L", storage: .local)]
    remote.records = [Sample.record(name: "R", storage: .remote)]

    let records = try await sut.fetchLocal()

    #expect(records.map(\.name) == ["L"])
}

@Test func fetchRemoteReturnsRemoteStoreRecords() async throws {
    let (sut, local, remote) = makeSUT()
    local.records = [Sample.record(name: "L", storage: .local)]
    remote.records = [Sample.record(name: "R", storage: .remote)]

    let records = try await sut.fetchRemote()

    #expect(records.map(\.name) == ["R"])
}

@Test func fetchLocalPropagatesError() async {
    let (sut, local, _) = makeSUT()
    local.fetchError = AnyError()

    await #expect(throws: (any Error).self) { try await sut.fetchLocal() }
}

@Test func fetchRemotePropagatesError() async {
    let (sut, _, remote) = makeSUT()
    remote.fetchError = AnyError()

    await #expect(throws: (any Error).self) { try await sut.fetchRemote() }
}

// MARK: delete routing + partial failure matrix

@Test func deleteLocalOnlySuccessRoutesToLocal() async throws {
    let (sut, local, remote) = makeSUT()
    let record = Sample.record(storage: .local)

    try await sut.delete([record])

    #expect(local.deletedIds == [[record.id]])
    #expect(remote.deletedIds.isEmpty)
}

@Test func deleteLocalOnlyFailureThrowsLocal() async {
    let (sut, local, _) = makeSUT()
    local.deleteError = AnyError()

    await #expect(throws: SportRecordsDeleteError(failedStores: [.local])) {
        try await sut.delete([Sample.record(storage: .local)])
    }
}

@Test func deleteRemoteOnlySuccessRoutesToRemote() async throws {
    let (sut, _, remote) = makeSUT()
    let record = Sample.record(storage: .remote)

    try await sut.delete([record])

    #expect(remote.deletedIds == [[record.id]])
}

@Test func deleteRemoteOnlyFailureThrowsRemote() async {
    let (sut, _, remote) = makeSUT()
    remote.deleteError = AnyError()

    await #expect(throws: SportRecordsDeleteError(failedStores: [.remote])) {
        try await sut.delete([Sample.record(storage: .remote)])
    }
}

@Test func deleteMixedBothSucceedRoutesEach() async throws {
    let (sut, local, remote) = makeSUT()
    let l = Sample.record(storage: .local)
    let r = Sample.record(storage: .remote)

    try await sut.delete([l, r])

    #expect(local.deletedIds == [[l.id]])
    #expect(remote.deletedIds == [[r.id]])
}

@Test func deleteMixedRemoteFailsCommitsLocalThrowsRemote() async {
    let (sut, local, remote) = makeSUT()
    remote.deleteError = AnyError()
    let l = Sample.record(storage: .local)
    let r = Sample.record(storage: .remote)

    await #expect(throws: SportRecordsDeleteError(failedStores: [.remote])) {
        try await sut.delete([l, r])
    }
    #expect(local.deletedIds == [[l.id]])   // local still committed
}

@Test func deleteMixedLocalFailsCommitsRemoteThrowsLocal() async {
    let (sut, local, remote) = makeSUT()
    local.deleteError = AnyError()
    let l = Sample.record(storage: .local)
    let r = Sample.record(storage: .remote)

    await #expect(throws: SportRecordsDeleteError(failedStores: [.local])) {
        try await sut.delete([l, r])
    }
    #expect(remote.deletedIds == [[r.id]])   // remote still committed
}

@Test func deleteMixedBothFailThrowsBoth() async {
    let (sut, local, remote) = makeSUT()
    local.deleteError = AnyError()
    remote.deleteError = AnyError()

    await #expect(throws: SportRecordsDeleteError(failedStores: [.local, .remote])) {
        try await sut.delete([Sample.record(storage: .local), Sample.record(storage: .remote)])
    }
}

// MARK: save routing

@Test func saveLocalRecordRoutesToLocalOnly() async throws {
    let (sut, local, remote) = makeSUT()
    let record = Sample.record(storage: .local)
    try await sut.save(record)
    #expect(local.inserted.map(\.id) == [record.id])
    #expect(remote.inserted.isEmpty)
}

@Test func saveRemoteRecordRoutesToRemoteOnly() async throws {
    let (sut, local, remote) = makeSUT()
    let record = Sample.record(storage: .remote)
    try await sut.save(record)
    #expect(remote.inserted.map(\.id) == [record.id])
    #expect(local.inserted.isEmpty)
}

@Test func saveLocalFailurePropagates() async {
    let (sut, local, _) = makeSUT()
    local.insertError = AnyError()
    await #expect(throws: (any Error).self) {
        try await sut.save(Sample.record(storage: .local))
    }
}

@Test func saveRemoteFailurePropagates() async {
    let (sut, _, remote) = makeSUT()
    remote.insertError = AnyError()
    await #expect(throws: (any Error).self) {
        try await sut.save(Sample.record(storage: .remote))
    }
}
