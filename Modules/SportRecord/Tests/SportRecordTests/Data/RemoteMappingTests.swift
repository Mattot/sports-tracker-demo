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
