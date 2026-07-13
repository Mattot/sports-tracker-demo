import Foundation

/// Domain entity. `storageType` is stamped by whichever data source produced
/// the record and is never persisted, so it can't drift from the record's origin.
public struct SportRecord: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let location: String
    public let duration: TimeInterval   // seconds
    public let storageType: StorageType
    public let createdAt: Date

    public init(
        id: UUID,
        name: String,
        location: String,
        duration: TimeInterval,
        storageType: StorageType,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.duration = duration
        self.storageType = storageType
        self.createdAt = createdAt
    }
}
