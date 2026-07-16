import Core
import FirebaseFirestore
import Foundation

/// Remote store gateway backed by Firestore. Document ID == record UUID.
struct FirestoreSportRecordDataSource: RemoteSportRecordDataSource {
    private let collectionName = "sportRecords"

    private var collection: CollectionReference {
        Firestore.firestore().collection(collectionName)
    }

    func observeRecords() -> AsyncThrowingStream<[SportRecord], Error> {
        AsyncThrowingStream([SportRecord].self) { continuation in
            let orderedCollection = collection.order(by: "createdAt", descending: true)
            // Due to Objective-C protocol under the hood - Swift 6 compiler won't allow access to listener
            // due to missing Sendable conformance.
            // Since available resources states that ListenerRegistration object is thread-safe
            // we make an exception to mark it as nonisolate(unsafe) to properly remove listener on termination.
            nonisolated(unsafe) let listener = orderedCollection.addSnapshotListener { snapshot, error in
                if let error {
                    Loggers.data.error("Firestore fetch failed: \(error.localizedDescription, privacy: .public)")
                    continuation.finish(throwing: ObserveRemoteRecordsError.unknown)
                    return
                }
                guard let snapshot else {
                    Loggers.data.error("Firestore fetch failed: no snapshot")
                    continuation.finish(throwing: ObserveRemoteRecordsError.noData)
                    return
                }
                do {
                    let records: [SportRecord] = try snapshot.documents.compactMap { document in
                        guard let id = UUID(uuidString: document.documentID) else { return nil }
                        let dto = try document.data(as: SportRecordDTO.self)
                        return dto.toDomain(id: id)
                    }
                    continuation.yield(records)
                } catch {
                    Loggers.data.error("Firestore fetch failed: \(error.localizedDescription, privacy: .public)")
                    continuation.finish(throwing: ObserveRemoteRecordsError.invalidData)
                }
            }
            Loggers.connectivity.debug("Firestore listener attached")
            continuation.onTermination = { _ in
                listener.remove()
                Loggers.connectivity.debug("Firestore listener cancelled")
            }
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
