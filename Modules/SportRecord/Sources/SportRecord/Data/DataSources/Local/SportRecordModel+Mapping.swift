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
