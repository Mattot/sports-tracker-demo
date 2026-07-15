import Core
import FirebaseFirestore
import Foundation

/// Remote store gateway backed by Firestore. Document ID == record UUID.
struct FirestoreSportRecordDataSource: RemoteSportRecordDataSource {
    private let collectionName = "sportRecords"

    private var collection: CollectionReference {
        Firestore.firestore().collection(collectionName)
    }

    func fetch() async throws -> [SportRecord] {
        do {
            let snapshot =
                try await collection
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

    func insert(_ record: SportRecord) async throws {
        do {
            try collection.document(record.id.uuidString).setData(from: SportRecordDTO(record: record))
        } catch {
            Loggers.data.error("Firestore insert failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func delete(ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }
        let batch = Firestore.firestore().batch()
        for id in ids {
            batch.deleteDocument(collection.document(id.uuidString))
        }
        // Fire-and-forget: the delete applies to Firestore's local cache
        // immediately and syncs on reconnect, so offline deletes don't block the
        // UI waiting for a server ack (matches how `insert` works). A failure from
        // the eventual server commit is logged rather than surfaced synchronously.
        batch.commit { error in
            if let error {
                Loggers.data.error("Firestore delete failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
