import Foundation

public struct DefaultSportRecordRepository: SportRecordRepository {
    private let local: LocalSportRecordDataSource
    private let remote: RemoteSportRecordDataSource

    public init(local: LocalSportRecordDataSource, remote: RemoteSportRecordDataSource) {
        self.local = local
        self.remote = remote
    }

    public func fetch() async -> SportRecordsFetchResult {
        async let localOpt = fetchLocal()
        async let remoteOpt = fetchRemote()
        let localRecords = await localOpt
        let remoteRecords = await remoteOpt

        var records: [SportRecord] = []
        var failed: Set<StorageType> = []

        if let localRecords { records += localRecords } else { failed.insert(.local) }
        if let remoteRecords { records += remoteRecords } else { failed.insert(.remote) }

        records.sort { $0.createdAt > $1.createdAt }
        return SportRecordsFetchResult(records: records, failedStores: failed)
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

    // MARK: - Helpers (swallow per-store errors into optional/bool signals)

    private func fetchLocal() async -> [SportRecord]? {
        try? await local.fetch()
    }

    private func fetchRemote() async -> [SportRecord]? {
        try? await remote.fetch()
    }

    private func deleteLocal(ids: [UUID]) async -> Bool {
        guard !ids.isEmpty else { return true }
        do { try await local.delete(ids: ids); return true } catch { return false }
    }

    private func deleteRemote(ids: [UUID]) async -> Bool {
        guard !ids.isEmpty else { return true }
        do { try await remote.delete(ids: ids); return true } catch { return false }
    }
}
