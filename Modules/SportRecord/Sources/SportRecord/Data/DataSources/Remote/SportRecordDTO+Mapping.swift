import Foundation

extension SportRecordDTO {
    /// Maps to the domain entity, stamping `.remote` at the boundary.
    func toDomain(id: UUID) -> SportRecord {
        SportRecord(
            id: id,
            name: name,
            location: location,
            duration: duration,
            storageType: .remote,
            createdAt: createdAt
        )
    }
}
