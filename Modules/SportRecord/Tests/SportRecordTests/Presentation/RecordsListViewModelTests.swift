import Testing
import Foundation
@testable import SportRecord

@MainActor
private func makeSUT(
    localRecords: [SportRecord] = [],
    localError: Error? = nil,
    remoteUpdates: [[SportRecord]] = [],
    remoteFails: Bool = false,
    isOnline: Bool = true
) -> (
    RecordsListViewModel,
    fetchLocal: FakeFetchLocalRecordsUseCase,
    observe: FakeObserveRemoteRecordsUseCase,
    delete: FakeDeleteUseCase,
    monitor: FakeNetworkMonitor
) {
    let fetchLocal = FakeFetchLocalRecordsUseCase()
    fetchLocal.records = localRecords
    fetchLocal.errorToThrow = localError
    let observe = FakeObserveRemoteRecordsUseCase()
    observe.updates = remoteUpdates
    observe.shouldFail = remoteFails
    let delete = FakeDeleteUseCase()
    let monitor = FakeNetworkMonitor(isOnline: isOnline)
    let sut = RecordsListViewModel(observeRemote: observe, fetchLocal: fetchLocal, delete: delete, networkMonitor: monitor)
    return (sut, fetchLocal, observe, delete, monitor)
}

// MARK: load / state mapping

@Test @MainActor func loadWithRecordsBecomesLoaded() async {
    let record = Sample.record()
    let (sut, _, _, _, _) = makeSUT(localRecords: [record])
    await sut.load()
    #expect(sut.content == .loaded([record]))
}

@Test @MainActor func loadWithNoRecordsBecomesLoadedEmpty() async {
    let (sut, _, _, _, _) = makeSUT()
    await sut.load()
    #expect(sut.content == .loaded([]))
    #expect(sut.hasRecords == false)
}

@Test @MainActor func loadFailureBecomesFailed() async {
    let (sut, _, _, _, _) = makeSUT(localError: AnyError())
    await sut.load()
    #expect(sut.content == .failed)
}

@Test @MainActor func retryReloadsLocalAfterFailure() async {
    let (sut, fetchLocal, _, _, _) = makeSUT(localError: AnyError())
    await sut.load()
    #expect(sut.content == .failed)

    fetchLocal.errorToThrow = nil
    fetchLocal.records = [Sample.record()]
    await sut.retry()

    if case .loaded(let records) = sut.content { #expect(records.count == 1) } else { Issue.record("retry should recover to .loaded") }
    #expect(fetchLocal.callCount == 2)
}

// MARK: local + remote merge / filter

@Test @MainActor func visibleRecordsMergeLocalAndRemoteNewestFirst() async {
    let local = Sample.record(name: "L", storage: .local, createdAt: .init(timeIntervalSince1970: 100))
    let remote = Sample.record(name: "R", storage: .remote, createdAt: .init(timeIntervalSince1970: 200))
    let (sut, _, _, _, _) = makeSUT(localRecords: [local], remoteUpdates: [[remote]])
    await sut.load()
    await sut.observeData()

    #expect(sut.visibleRecords.map(\.name) == ["R", "L"])
    #expect(sut.hasRecords)
}

@Test @MainActor func filterShowsOnlyTheSelectedStore() async {
    let local = Sample.record(storage: .local)
    let remote = Sample.record(storage: .remote)
    let (sut, _, _, _, _) = makeSUT(localRecords: [local], remoteUpdates: [[remote]])
    await sut.load()
    await sut.observeData()

    sut.filter = .local
    #expect(sut.visibleRecords == [local])
    sut.filter = .remote
    #expect(sut.visibleRecords == [remote])
    sut.filter = .all
    #expect(sut.visibleRecords.count == 2)
}

@Test @MainActor func filterChangeDoesNotRefetchLocal() async {
    let (sut, fetchLocal, _, _, _) = makeSUT(localRecords: [Sample.record(storage: .local)])
    await sut.load()

    sut.filter = .local
    sut.filter = .remote
    sut.filter = .all

    #expect(fetchLocal.callCount == 1)
}

// MARK: remote observation

@Test @MainActor func observeDataAppliesRemoteRecords() async {
    let remote = Sample.record(storage: .remote)
    let (sut, _, _, _, _) = makeSUT(remoteUpdates: [[remote]])
    await sut.load()
    await sut.observeData()

    sut.filter = .remote
    #expect(sut.visibleRecords == [remote])
    #expect(sut.remoteUnavailable == false)
}

@Test @MainActor func observeDataFailureSetsRemoteUnavailable() async {
    let (sut, _, _, _, _) = makeSUT(remoteFails: true)
    await sut.observeData()
    #expect(sut.remoteUnavailable)
}

@Test @MainActor func retryingObservationClearsRemoteUnavailableAndAppliesRecords() async {
    let remote = Sample.record(storage: .remote)
    let (sut, _, observe, _, _) = makeSUT(remoteFails: true)
    await sut.observeData()
    #expect(sut.remoteUnavailable)

    // The banner's "try again" re-subscribes; the stream now succeeds.
    observe.shouldFail = false
    observe.updates = [[remote]]
    await sut.observeData()

    #expect(sut.remoteUnavailable == false)
    sut.filter = .remote
    #expect(sut.visibleRecords == [remote])
    #expect(observe.callCount == 2)
}

// MARK: offline

@Test @MainActor func observeConnectivityReflectsInitialOfflineState() async {
    let (sut, _, _, _, _) = makeSUT(isOnline: false)
    let task = Task { await sut.observeConnectivity() }
    defer { task.cancel() }
    for _ in 0..<1000 where sut.isOffline == false { await Task.yield() }
    #expect(sut.isOffline)
}

@Test @MainActor func observeConnectivityReflectsGoingOffline() async {
    let (sut, _, _, _, monitor) = makeSUT(isOnline: true)
    let task = Task { await sut.observeConnectivity() }
    defer { task.cancel() }
    monitor.setOnline(false)
    for _ in 0..<1000 where sut.isOffline == false { await Task.yield() }
    #expect(sut.isOffline)
}

// MARK: edit mode

@Test @MainActor func cancelEditingClearsEditModeAndSelection() async {
    let a = Sample.record(storage: .local)
    let (sut, _, _, _, _) = makeSUT(localRecords: [a])
    await sut.load()
    sut.isEditing = true
    sut.selection = [a.id]

    sut.cancelEditing()

    #expect(sut.isEditing == false)
    #expect(sut.selection.isEmpty)
}

// MARK: swipe delete

@Test @MainActor func swipeDeleteLocalSuccessRemovesRow() async {
    let record = Sample.record(storage: .local)
    let (sut, _, _, _, _) = makeSUT(localRecords: [record])
    await sut.load()
    await sut.delete(record)
    #expect(sut.content == .loaded([]))
    #expect(sut.deleteErrors.isEmpty)
}

@Test @MainActor func swipeDeleteRemoteFailureKeepsRowAndSetsError() async {
    let record = Sample.record(storage: .remote)
    let (sut, _, _, delete, _) = makeSUT(remoteUpdates: [[record]])
    await sut.load()
    await sut.observeData()
    delete.errorToThrow = SportRecordsDeleteError(failedStores: [.remote])

    await sut.delete(record)

    #expect(sut.visibleRecords.map(\.id) == [record.id])   // row stays
    #expect(sut.deleteErrors == [.remote])
}

// MARK: batch delete

@Test @MainActor func batchDeleteSuccessRemovesAllAndExitsEdit() async {
    let a = Sample.record(storage: .local)
    let b = Sample.record(storage: .remote)
    let (sut, _, _, _, _) = makeSUT(localRecords: [a], remoteUpdates: [[b]])
    await sut.load()
    await sut.observeData()
    sut.isEditing = true
    sut.selection = [a.id, b.id]

    await sut.deleteSelected()

    #expect(sut.visibleRecords.isEmpty)
    #expect(sut.selection.isEmpty)
    #expect(sut.isEditing == false)
    #expect(sut.deleteErrors.isEmpty)
}

@Test @MainActor func batchDeleteMixedRemoteFailsRemovesLocalKeepsRemote() async {
    let a = Sample.record(storage: .local)
    let b = Sample.record(storage: .remote)
    let (sut, _, _, delete, _) = makeSUT(localRecords: [a], remoteUpdates: [[b]])
    await sut.load()
    await sut.observeData()
    sut.isEditing = true
    sut.selection = [a.id, b.id]
    delete.errorToThrow = SportRecordsDeleteError(failedStores: [.remote])

    await sut.deleteSelected()

    #expect(sut.visibleRecords.map(\.id) == [b.id])   // local committed, remote kept
    #expect(sut.deleteErrors == [.remote])
    #expect(sut.isEditing == false)                   // edit mode exits regardless
    #expect(sut.selection.isEmpty)
}

@Test @MainActor func batchDeleteBothFailKeepsEveryRecord() async {
    let a = Sample.record(storage: .local)
    let b = Sample.record(storage: .remote)
    let (sut, _, _, delete, _) = makeSUT(localRecords: [a], remoteUpdates: [[b]])
    await sut.load()
    await sut.observeData()
    sut.isEditing = true
    sut.selection = [a.id, b.id]
    delete.errorToThrow = SportRecordsDeleteError(failedStores: [.local, .remote])

    await sut.deleteSelected()

    #expect(sut.visibleRecords.count == 2)
    #expect(sut.deleteErrors == [.local, .remote])
    #expect(sut.isEditing == false)
    #expect(sut.selection.isEmpty)
}
