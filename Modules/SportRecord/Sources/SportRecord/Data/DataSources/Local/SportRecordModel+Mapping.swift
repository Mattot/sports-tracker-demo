extension SportRecordModel {
    /// Maps to the domain entity, stamping `.local` at the boundary.
    func toDomain() -> SportRecord {
        SportRecord(
            id: id,
            name: name,
            location: location,
            duration: duration,
            storageType: .local,
            createdAt: createdAt
        )
    }
}

extension SportRecordModel {
    /// Builds a persistence model from a domain record (storageType is implicit).
    convenience init(record: SportRecord) {
        self.init(
            id: record.id,
            name: record.name,
            location: record.location,
            duration: record.duration,
            createdAt: record.createdAt
        )
    }
}
