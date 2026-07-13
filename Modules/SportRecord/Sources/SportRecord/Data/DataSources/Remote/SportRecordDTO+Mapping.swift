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

extension SportRecordDTO {
    /// Builds the Firestore document body from a domain record. `id` is dropped —
    /// it becomes the document ID.
    init(record: SportRecord) {
        self.init(
            name: record.name,
            location: record.location,
            duration: record.duration,
            createdAt: record.createdAt
        )
    }
}
