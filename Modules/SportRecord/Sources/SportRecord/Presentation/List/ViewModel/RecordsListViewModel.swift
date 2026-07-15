import Core
import Foundation
import Observation

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

    public init(
        fetch: FetchSportRecordsUseCase,
        delete: DeleteSportRecordsUseCase,
        networkMonitor: NetworkMonitor
    ) {
        self.fetchUseCase = fetch
        self.deleteUseCase = delete
        self.networkMonitor = networkMonitor
    }

    // MARK: - Derived

    private var loadedRecords: [SportRecord] {
        guard case let .loaded(records) = content else { return [] }
        return records
    }

    /// Whether any records exist at all, regardless of the selected filter — lets
    /// the view tell "nothing yet" apart from "nothing in this segment".
    public var hasRecords: Bool { !loadedRecords.isEmpty }

    public var visibleRecords: [SportRecord] {
        switch filter {
        case .all:
            loadedRecords
        case .local:
            loadedRecords.filter { $0.storageType == .local }
        case .remote:
            loadedRecords.filter { $0.storageType == .remote }
        }
    }

    // MARK: - Loading

    /// The use case yields local records first, then the combined result — apply
    /// each as it lands so the list paints without waiting on the remote store.
    public func load() async {
        if loadedRecords.isEmpty { content = .loading }
        for await result in fetchUseCase.execute() {
            applyContent(result)
        }
    }

    public func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        // Only the final (combined) result matters here: applying the local-first
        // partial would briefly drop the remote rows already on screen.
        var combined: SportRecordsFetchResult?
        for await result in fetchUseCase.execute() { combined = result }
        guard let combined else { return }

        remoteUnavailable = combined.failedStores.contains(.remote)
        // Don't destroy a good list because a refresh couldn't load anything.
        if combined.records.isEmpty, !combined.failedStores.isEmpty, !loadedRecords.isEmpty {
            return
        }
        applyContent(combined)
    }

    public func retry() async {
        await load()
    }

    private func applyContent(_ result: SportRecordsFetchResult) {
        remoteUnavailable = result.failedStores.contains(.remote)
        // Nothing loaded and at least one store failed => genuine failure.
        // Otherwise `loaded` — possibly with an empty array.
        if result.records.isEmpty, !result.failedStores.isEmpty {
            content = .failed
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

    /// Leaves edit mode and drops the selection — used by Done and by Add, since a
    /// pending selection is meaningless once you move on to creating a record.
    public func cancelEditing() {
        isEditing = false
        selection = []
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
        content = .loaded(records)
    }

    private func message(for stores: Set<StorageType>) -> String {
        switch (stores.contains(.local), stores.contains(.remote)) {
        case (true, true): L10n.List.deleteErrorBoth
        case (false, true): L10n.List.deleteErrorRemote
        case (true, false): L10n.List.deleteErrorLocal
        case (false, false): L10n.List.deleteErrorUnknown
        }
    }

    // MARK: - Network

    /// Observes connectivity until the calling task is cancelled. Drive this from
    /// the view's `.task` so SwiftUI ties its lifetime to the view — no stored
    /// task, no `deinit`, no manual cancellation. `isOffline` starts optimistic
    /// (false) and is corrected by the stream's first value.
    public func observeConnectivity() async {
        for await online in networkMonitor.updates {
            isOffline = !online
        }
    }
}
