import Core
import Foundation
import SwiftData

/// Local store gateway. `@ModelActor` gives it an actor-isolated `ModelContext`
/// so SwiftData I/O runs off the main actor with no `Sendable` violations.
@ModelActor
actor SwiftDataSportRecordDataSource: LocalSportRecordDataSource {
    func fetch() async throws -> [SportRecord] {
        do {
            let descriptor = FetchDescriptor<SportRecordModel>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            return try modelContext.fetch(descriptor).map { $0.toDomain() }
        } catch {
            Loggers.data.error("SwiftData fetch failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func insert(_ record: SportRecord) async throws {
        do {
            modelContext.insert(SportRecordModel(record: record))
            try modelContext.save()
        } catch {
            Loggers.data.error("SwiftData insert failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func delete(ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }
        do {
            try modelContext.delete(
                model: SportRecordModel.self,
                where: #Predicate { ids.contains($0.id) }
            )
            try modelContext.save()
        } catch {
            Loggers.data.error("SwiftData delete failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}
