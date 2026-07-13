import Testing
import Foundation
@testable import SportRecord

@Test func dtoMapsToDomainStampedRemote() {
    let id = UUID()
    let dto = SportRecordDTO(name: "Swim", location: "Pool", duration: 1800, createdAt: Date(timeIntervalSince1970: 42))

    let record = dto.toDomain(id: id)

    #expect(record.id == id)
    #expect(record.name == "Swim")
    #expect(record.location == "Pool")
    #expect(record.duration == 1800)
    #expect(record.createdAt == Date(timeIntervalSince1970: 42))
    #expect(record.storageType == .remote)
}

@Test func recordMapsToDTODroppingId() {
    let record = Sample.record(name: "Row", location: "Lake", duration: 900, storage: .remote, createdAt: .init(timeIntervalSince1970: 7))
    let dto = SportRecordDTO(record: record)

    #expect(dto.name == "Row")
    #expect(dto.location == "Lake")
    #expect(dto.duration == 900)
    #expect(dto.createdAt == Date(timeIntervalSince1970: 7))
    // (DTO has no id field — the record's UUID is the Firestore document ID.)
}
