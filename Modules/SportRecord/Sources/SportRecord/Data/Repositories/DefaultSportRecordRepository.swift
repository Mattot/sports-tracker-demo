import Foundation
import Core

public struct DefaultSportRecordRepository: SportRecordRepository {
    private let local: LocalSportRecordDataSource
    private let remote: RemoteSportRecordDataSource

    public init(local: LocalSportRecordDataSource, remote: RemoteSportRecordDataSource) {
        self.local = local
        self.remote = remote
    }

    public func fetchLocal() async throws -> [SportRecord] {
        try await local.fetch()
    }

    public func fetchRemote() async throws -> [SportRecord] {
        try await remote.fetch()
    }

    public func save(_ record: SportRecord) async throws {
        switch record.storageType {
        case .local:  try await local.insert(record)
        case .remote: try await remote.insert(record)
        }
    }

    public func delete(_ records: [SportRecord]) async throws(SportRecordsDeleteError) {
        let localIDs = records.filter { $0.storageType == .local }.map(\.id)
        let remoteIDs = records.filter { $0.storageType == .remote }.map(\.id)

        async let localOK = deleteLocal(ids: localIDs)
        async let remoteOK = deleteRemote(ids: remoteIDs)
        let (localSucceeded, remoteSucceeded) = await (localOK, remoteOK)

        var failed: Set<StorageType> = []
        if !localSucceeded { failed.insert(.local) }
        if !remoteSucceeded { failed.insert(.remote) }
        if !failed.isEmpty { throw SportRecordsDeleteError(failedStores: failed) }
    }

    // MARK: - Delete helpers (swallow per-store errors into bool signals)
    //
    // The data sources log the underlying error; here we log the coordinated
    // degradation decision (which store failed to delete).

    private func deleteLocal(ids: [UUID]) async -> Bool {
        guard !ids.isEmpty else { return true }
        do {
            try await local.delete(ids: ids)
            return true
        } catch {
            Loggers.data.debug("Local delete failed for \(ids.count) record(s)")
            return false
        }
    }

    private func deleteRemote(ids: [UUID]) async -> Bool {
        guard !ids.isEmpty else { return true }
        do {
            try await remote.delete(ids: ids)
            return true
        } catch {
            Loggers.data.debug("Remote delete failed for \(ids.count) record(s)")
            return false
        }
    }
}
