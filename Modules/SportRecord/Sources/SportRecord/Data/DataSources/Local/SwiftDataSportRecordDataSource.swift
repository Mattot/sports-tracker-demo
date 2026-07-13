import Foundation
import SwiftData

/// Local store gateway. `@ModelActor` gives it an actor-isolated `ModelContext`
/// so SwiftData I/O runs off the main actor with no `Sendable` violations.
@ModelActor
actor SwiftDataSportRecordDataSource: LocalSportRecordDataSource {
    func fetch() async throws -> [SportRecord] {
        let descriptor = FetchDescriptor<SportRecordModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    func delete(ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }
        try modelContext.delete(
            model: SportRecordModel.self,
            where: #Predicate { ids.contains($0.id) }
        )
        try modelContext.save()
    }
}
