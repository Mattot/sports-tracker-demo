import Foundation

/// Firestore document body. The document ID holds the record's UUID, so the id
/// is not duplicated inside the document.
struct SportRecordDTO: Codable, Sendable {
    let name: String
    let location: String
    let duration: TimeInterval
    let createdAt: Date
}
