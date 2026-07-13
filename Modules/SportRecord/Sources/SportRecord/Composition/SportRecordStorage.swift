import Foundation
import SwiftData

/// Public composition seam for the App. Keeps the data-source concretes internal
/// while exposing exactly what the DI container needs to build them.
public enum SportRecordStorage {
    /// Builds the SwiftData container for this feature's schema.
    public static func makeModelContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([SportRecordModel.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    public static func makeLocalDataSource(container: ModelContainer) -> LocalSportRecordDataSource {
        SwiftDataSportRecordDataSource(modelContainer: container)
    }

    public static func makeRemoteDataSource() -> RemoteSportRecordDataSource {
        FirestoreSportRecordDataSource()
    }
}
