import Core

public protocol FetchSportRecordsUseCase: Sendable {
    /// Yields the local records first (when there are any) so the list can paint
    /// without waiting on a possibly slow or offline remote store, then yields the
    /// combined local + remote result. Always ends with the combined result.
    func execute() -> AsyncStream<SportRecordsFetchResult>
}

public struct DefaultFetchSportRecordsUseCase: FetchSportRecordsUseCase {
    private let repository: SportRecordRepository

    public init(repository: SportRecordRepository) {
        self.repository = repository
    }

    public func execute() -> AsyncStream<SportRecordsFetchResult> {
        AsyncStream { continuation in
            let task = Task {
                async let localTask = local()
                async let remoteTask = remote()

                // First paint: show local records as soon as they land.
                let localRecords = await localTask
                if let localRecords, !localRecords.isEmpty {
                    continuation.yield(SportRecordsFetchResult(records: localRecords, failedStores: []))
                }

                let remoteRecords = await remoteTask

                var records: [SportRecord] = []
                var failed: Set<StorageType> = []
                if let localRecords { records += localRecords } else { failed.insert(.local) }
                if let remoteRecords { records += remoteRecords } else { failed.insert(.remote) }
                records.sort { $0.createdAt > $1.createdAt }

                continuation.yield(SportRecordsFetchResult(records: records, failedStores: failed))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Per-store reads (a failing store drops out of the result)

    private func local() async -> [SportRecord]? {
        do {
            return try await repository.fetchLocal()
        } catch {
            Loggers.data.debug("Local fetch failed; excluding local store from results")
            return nil
        }
    }

    private func remote() async -> [SportRecord]? {
        do {
            return try await repository.fetchRemote()
        } catch {
            Loggers.data.debug("Remote fetch failed; excluding remote store from results")
            return nil
        }
    }
}
