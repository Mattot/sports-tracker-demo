import Foundation
import SwiftData

@Model
final class SportRecordModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var location: String
    var duration: TimeInterval
    var createdAt: Date

    init(id: UUID, name: String, location: String, duration: TimeInterval, createdAt: Date) {
        self.id = id
        self.name = name
        self.location = location
        self.duration = duration
        self.createdAt = createdAt
    }
}
