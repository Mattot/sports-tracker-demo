import Testing
import Foundation
import SwiftData
@testable import SportRecord

@MainActor
private func makeInMemoryContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: SportRecordModel.self, configurations: config)
}

@MainActor
private func seed(_ container: ModelContainer, _ models: [SportRecordModel]) throws {
    let context = ModelContext(container)
    for model in models { context.insert(model) }
    try context.save()
}

@Test @MainActor func fetchReturnsRecordsNewestFirstStampedLocal() async throws {
    let container = try makeInMemoryContainer()
    let older = SportRecordModel(id: UUID(), name: "Old", location: "A", duration: 30, createdAt: Date(timeIntervalSince1970: 100))
    let newer = SportRecordModel(id: UUID(), name: "New", location: "B", duration: 60, createdAt: Date(timeIntervalSince1970: 200))
    try seed(container, [older, newer])
    let sut = SwiftDataSportRecordDataSource(modelContainer: container)

    let records = try await sut.fetch()

    #expect(records.map(\.name) == ["New", "Old"])
    #expect(records.allSatisfy { $0.storageType == .local })
}

@Test @MainActor func deleteRemovesOnlyGivenIds() async throws {
    let container = try makeInMemoryContainer()
    let keep = SportRecordModel(id: UUID(), name: "Keep", location: "A", duration: 30, createdAt: .init(timeIntervalSince1970: 1))
    let drop = SportRecordModel(id: UUID(), name: "Drop", location: "B", duration: 60, createdAt: .init(timeIntervalSince1970: 2))
    try seed(container, [keep, drop])
    let sut = SwiftDataSportRecordDataSource(modelContainer: container)

    try await sut.delete(ids: [drop.id])
    let remaining = try await sut.fetch()

    #expect(remaining.map(\.name) == ["Keep"])
}

@Test @MainActor func deleteMissingIdIsNoOp() async throws {
    let container = try makeInMemoryContainer()
    try seed(container, [SportRecordModel(id: UUID(), name: "Keep", location: "A", duration: 30, createdAt: .init(timeIntervalSince1970: 1))])
    let sut = SwiftDataSportRecordDataSource(modelContainer: container)

    try await sut.delete(ids: [UUID()])
    let remaining = try await sut.fetch()

    #expect(remaining.count == 1)
}

@Test @MainActor func insertThenFetchReturnsRecord() async throws {
    let container = try makeInMemoryContainer()
    let sut = SwiftDataSportRecordDataSource(modelContainer: container)
    let record = Sample.record(name: "Swim", location: "Pool", duration: 1800, storage: .local, createdAt: .init(timeIntervalSince1970: 5))

    try await sut.insert(record)
    let fetched = try await sut.fetch()

    #expect(fetched.count == 1)
    #expect(fetched.first?.id == record.id)
    #expect(fetched.first?.name == "Swim")
    #expect(fetched.first?.location == "Pool")
    #expect(fetched.first?.duration == 1800)
    #expect(fetched.first?.storageType == .local)
}
