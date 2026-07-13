import Foundation
import FirebaseFirestore
import Core

/// Remote store gateway backed by Firestore. Document ID == record UUID.
struct FirestoreSportRecordDataSource: RemoteSportRecordDataSource {
    private let collectionName = "sportRecords"

    private var collection: CollectionReference {
        Firestore.firestore().collection(collectionName)
    }

    func fetch() async throws -> [SportRecord] {
        do {
            let snapshot = try await collection
                .order(by: "createdAt", descending: true)
                .getDocuments()
            return try snapshot.documents.compactMap { document in
                guard let id = UUID(uuidString: document.documentID) else { return nil }
                let dto = try document.data(as: SportRecordDTO.self)
                return dto.toDomain(id: id)
            }
        } catch {
            Loggers.data.error("Firestore fetch failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func delete(ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }
        do {
            let batch = Firestore.firestore().batch()
            for id in ids {
                batch.deleteDocument(collection.document(id.uuidString))
            }
            try await batch.commit()
        } catch {
            Loggers.data.error("Firestore delete failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}
