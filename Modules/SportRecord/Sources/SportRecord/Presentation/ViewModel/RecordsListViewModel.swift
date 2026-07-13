import Foundation
import Observation
import Core

@MainActor
@Observable
public final class RecordsListViewModel {
    private let fetchUseCase: FetchSportRecordsUseCase
    private let deleteUseCase: DeleteSportRecordsUseCase
    private let networkMonitor: NetworkMonitor

    public private(set) var content: RecordsContentState = .loading
    public var filter: RecordsFilter = .all
    public private(set) var isRefreshing = false
    public private(set) var remoteUnavailable = false
    public private(set) var isOffline = false
    public var isEditing = false
    public var selection: Set<UUID> = []
    public var isDeleteConfirmationPresented = false
    public var deleteError: String?

    // `deinit` on a `@MainActor` class is nonisolated in Swift 6, so it cannot
    // touch a main-actor-isolated stored property directly. This task is only
    // ever written from `init` and read/cancelled from `deinit`/`observeNetwork`,
    // so `nonisolated(unsafe)` is safe here without changing behavior.
    nonisolated(unsafe) private var monitorTask: Task<Void, Never>?

    public init(
        fetch: FetchSportRecordsUseCase,
        delete: DeleteSportRecordsUseCase,
        networkMonitor: NetworkMonitor
    ) {
        self.fetchUseCase = fetch
        self.deleteUseCase = delete
        self.networkMonitor = networkMonitor
        self.isOffline = !networkMonitor.isOnline
        observeNetwork()
    }

    deinit {
        monitorTask?.cancel()
    }

    // MARK: - Derived

    private var loadedRecords: [SportRecord] {
        if case let .loaded(records) = content { records } else { [] }
    }

    public var visibleRecords: [SportRecord] {
        loadedRecords.filter { record in
            switch filter {
            case .all: true
            case .local: record.storageType == .local
            case .remote: record.storageType == .remote
            }
        }
    }

    // MARK: - Loading

    public func load() async {
        if loadedRecords.isEmpty { content = .loading }
        applyContent(await fetchUseCase.execute())
    }

    public func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        let result = await fetchUseCase.execute()
        remoteUnavailable = result.failedStores.contains(.remote)
        // Don't destroy a good list because a refresh couldn't load anything.
        if result.records.isEmpty, !result.failedStores.isEmpty, !loadedRecords.isEmpty {
            return
        }
        applyContent(result)
    }

    public func retry() async {
        await load()
    }

    private func applyContent(_ result: SportRecordsFetchResult) {
        remoteUnavailable = result.failedStores.contains(.remote)
        if result.records.isEmpty {
            content = result.failedStores.isEmpty ? .empty : .failed
        } else {
            content = .loaded(result.records)
        }
    }

    // MARK: - Deletion

    public func delete(_ record: SportRecord) async {
        do {
            try await deleteUseCase.execute([record])
            removeRecords(ids: [record.id])
        } catch {
            deleteError = message(for: error.failedStores)
        }
    }

    public func requestDeleteSelection() {
        isDeleteConfirmationPresented = true
    }

    public func deleteSelected() async {
        let selected = loadedRecords.filter { selection.contains($0.id) }
        guard !selected.isEmpty else { return }
        do {
            try await deleteUseCase.execute(selected)
            removeRecords(ids: selection)
            selection = []
            isEditing = false
        } catch {
            let failed = error.failedStores
            let succeeded = selected.filter { !failed.contains($0.storageType) }
            removeRecords(ids: Set(succeeded.map(\.id)))
            selection = Set(selected.filter { failed.contains($0.storageType) }.map(\.id))
            deleteError = message(for: failed)
        }
    }

    private func removeRecords(ids: Set<UUID>) {
        guard case var .loaded(records) = content else { return }
        records.removeAll { ids.contains($0.id) }
        content = records.isEmpty ? .empty : .loaded(records)
    }

    private func message(for stores: Set<StorageType>) -> String {
        switch (stores.contains(.local), stores.contains(.remote)) {
        case (true, true): "Couldn't delete some records. Check your connection and try again."
        case (false, true): "Couldn't delete remote records. You may be offline."
        case (true, false): "Couldn't delete local records. Please try again."
        case (false, false): "Couldn't delete records."
        }
    }

    // MARK: - Network

    private func observeNetwork() {
        monitorTask = Task { [weak self] in
            guard let self else { return }
            for await online in networkMonitor.updates {
                self.isOffline = !online
            }
        }
    }
}
