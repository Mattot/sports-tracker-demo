import Foundation
import FirebaseFirestore

/// Remote store gateway backed by Firestore. Document ID == record UUID.
struct FirestoreSportRecordDataSource: RemoteSportRecordDataSource {
    private let collectionName = "sportRecords"

    private var collection: CollectionReference {
        Firestore.firestore().collection(collectionName)
    }

    func fetch() async throws -> [SportRecord] {
        let snapshot = try await collection
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return try snapshot.documents.compactMap { document in
            guard let id = UUID(uuidString: document.documentID) else { return nil }
            let dto = try document.data(as: SportRecordDTO.self)
            return dto.toDomain(id: id)
        }
    }

    func delete(ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }
        let batch = Firestore.firestore().batch()
        for id in ids {
            batch.deleteDocument(collection.document(id.uuidString))
        }
        try await batch.commit()
    }
}
