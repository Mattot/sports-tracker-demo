import Testing
import Foundation
@testable import SportRecord

@MainActor
private func makeSUT(
    fetchResult: SportRecordsFetchResult = .init(records: [], failedStores: []),
    isOnline: Bool = true
) -> (RecordsListViewModel, fetch: FakeFetchUseCase, delete: FakeDeleteUseCase, monitor: FakeNetworkMonitor) {
    let fetch = FakeFetchUseCase(); fetch.result = fetchResult
    let delete = FakeDeleteUseCase()
    let monitor = FakeNetworkMonitor(isOnline: isOnline)
    let sut = RecordsListViewModel(fetch: fetch, delete: delete, networkMonitor: monitor)
    return (sut, fetch, delete, monitor)
}

// MARK: load / state mapping

@Test @MainActor func loadWithRecordsBecomesLoaded() async {
    let record = Sample.record()
    let (sut, _, _, _) = makeSUT(fetchResult: .init(records: [record], failedStores: []))
    await sut.load()
    #expect(sut.content == .loaded([record]))
}

@Test @MainActor func loadWithNoRecordsAndNoFailureBecomesEmpty() async {
    let (sut, _, _, _) = makeSUT(fetchResult: .init(records: [], failedStores: []))
    await sut.load()
    #expect(sut.content == .empty)
}

@Test @MainActor func loadWithNoRecordsAndBothFailedBecomesFailed() async {
    let (sut, _, _, _) = makeSUT(fetchResult: .init(records: [], failedStores: [.local, .remote]))
    await sut.load()
    #expect(sut.content == .failed)
}

@Test @MainActor func remoteFailureWithLocalRecordsSetsRemoteUnavailable() async {
    let (sut, _, _, _) = makeSUT(fetchResult: .init(records: [Sample.record()], failedStores: [.remote]))
    await sut.load()
    #expect(sut.remoteUnavailable)
}

// MARK: filter

@Test @MainActor func filterChangeDoesNotRefetch() async {
    let local = Sample.record(storage: .local)
    let remote = Sample.record(storage: .remote)
    let (sut, fetch, _, _) = makeSUT(fetchResult: .init(records: [local, remote], failedStores: []))
    await sut.load()

    sut.filter = .local
    #expect(sut.visibleRecords == [local])
    sut.filter = .remote
    #expect(sut.visibleRecords == [remote])
    sut.filter = .all
    #expect(sut.visibleRecords.count == 2)

    #expect(fetch.callCount == 1)   // never refetched on filter switch
}

@Test @MainActor func filterWithNoMatchesKeepsLoadedContent() async {
    let (sut, _, _, _) = makeSUT(fetchResult: .init(records: [Sample.record(storage: .local)], failedStores: []))
    await sut.load()
    sut.filter = .remote
    #expect(sut.visibleRecords.isEmpty)
    if case .loaded = sut.content {} else { Issue.record("content should stay .loaded") }
}

// MARK: offline

@Test @MainActor func offlineMonitorSetsIsOffline() async {
    let (sut, _, _, _) = makeSUT(isOnline: false)
    #expect(sut.isOffline)
}

// MARK: refresh

@Test @MainActor func refreshFailureKeepsExistingList() async {
    let (sut, fetch, _, _) = makeSUT(fetchResult: .init(records: [Sample.record()], failedStores: []))
    await sut.load()
    // Next fetch: total failure.
    fetch.result = .init(records: [], failedStores: [.local, .remote])
    await sut.refresh()
    if case .loaded(let r) = sut.content { #expect(r.count == 1) } else { Issue.record("list was blown away") }
}

// MARK: swipe delete

@Test @MainActor func swipeDeleteLocalSuccessRemovesRow() async {
    let record = Sample.record(storage: .local)
    let (sut, _, _, _) = makeSUT(fetchResult: .init(records: [record], failedStores: []))
    await sut.load()
    await sut.delete(record)
    #expect(sut.content == .empty)
    #expect(sut.deleteError == nil)
}

@Test @MainActor func swipeDeleteRemoteFailureKeepsRowAndSetsError() async {
    let record = Sample.record(storage: .remote)
    let (sut, _, delete, _) = makeSUT(fetchResult: .init(records: [record], failedStores: []))
    await sut.load()
    delete.errorToThrow = SportRecordsDeleteError(failedStores: [.remote])
    await sut.delete(record)
    if case .loaded(let r) = sut.content { #expect(r.count == 1) } else { Issue.record("row removed on failure") }
    #expect(sut.deleteError != nil)
}

// MARK: batch delete

@Test @MainActor func batchDeleteSuccessClearsSelectionAndExitsEdit() async {
    let a = Sample.record(storage: .local)
    let b = Sample.record(storage: .remote)
    let (sut, _, _, _) = makeSUT(fetchResult: .init(records: [a, b], failedStores: []))
    await sut.load()
    sut.isEditing = true
    sut.selection = [a.id, b.id]
    await sut.deleteSelected()
    #expect(sut.content == .empty)
    #expect(sut.selection.isEmpty)
    #expect(sut.isEditing == false)
}

@Test @MainActor func batchDeleteMixedRemoteFailsRemovesLocalKeepsRemote() async {
    let a = Sample.record(storage: .local)
    let b = Sample.record(storage: .remote)
    let (sut, _, delete, _) = makeSUT(fetchResult: .init(records: [a, b], failedStores: []))
    await sut.load()
    sut.isEditing = true
    sut.selection = [a.id, b.id]
    delete.errorToThrow = SportRecordsDeleteError(failedStores: [.remote])
    await sut.deleteSelected()

    if case .loaded(let r) = sut.content { #expect(r.map(\.id) == [b.id]) } else { Issue.record("unexpected content") }
    #expect(sut.selection == [b.id])   // reduced to failed rows
    #expect(sut.isEditing)             // stays in edit mode
    #expect(sut.deleteError != nil)
}

@Test @MainActor func batchDeleteBothFailKeepsEverythingSelected() async {
    let a = Sample.record(storage: .local)
    let b = Sample.record(storage: .remote)
    let (sut, _, delete, _) = makeSUT(fetchResult: .init(records: [a, b], failedStores: []))
    await sut.load()
    sut.isEditing = true
    sut.selection = [a.id, b.id]
    delete.errorToThrow = SportRecordsDeleteError(failedStores: [.local, .remote])
    await sut.deleteSelected()

    if case .loaded(let r) = sut.content { #expect(r.count == 2) } else { Issue.record("rows removed") }
    #expect(sut.selection == [a.id, b.id])
    #expect(sut.isEditing)
}
