import Testing
import Foundation
@testable import SportRecord

@Test func storageTypeHasLocalAndRemote() {
    #expect(Set(StorageType.allCases) == [.local, .remote])
}

@Test func observeRemoteErrorHasDistinctCases() {
    let cases: Set<String> = [
        "\(ObserveRemoteRecordsError.noData)",
        "\(ObserveRemoteRecordsError.invalidData)",
        "\(ObserveRemoteRecordsError.unknown)",
    ]
    #expect(cases.count == 3)
}

@Test func deleteErrorCarriesFailedStores() {
    let error = SportRecordsDeleteError(failedStores: [.remote])
    #expect(error.failedStores == [.remote])
}

@Test func sportRecordsAreEquatableByValue() {
    let id = UUID()
    let date = Date(timeIntervalSince1970: 0)
    let a = SportRecord(id: id, name: "Run", location: "Park", duration: 60, storageType: .local, createdAt: date)
    let b = SportRecord(id: id, name: "Run", location: "Park", duration: 60, storageType: .local, createdAt: date)
    #expect(a == b)
}
