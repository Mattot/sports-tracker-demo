import Core
import Foundation
import Observation

@MainActor
@Observable
public final class RecordsListViewModel {
    private let observeRemoteRecordsUseCase: ObserveRemoteRecordsUseCase
    private let fetchLocalRecordsUseCase: FetchLocalRecordsUseCase
    private let deleteUseCase: DeleteSportRecordsUseCase
    private let networkMonitor: NetworkMonitor

    public private(set) var content: RecordsContentState = .loading
    private var remoteRecords = [SportRecord]()
    public var remoteUnavailable = false

    public var filter: RecordsFilter = .all
    public private(set) var isOffline = false
    public var isEditing = false
    public var selection: Set<UUID> = []
    private var pendingDeletes: Set<UUID> = []
    public var isDeleteConfirmationPresented = false
    public var deleteErrors: Set<StorageType> = []

    public init(
        observeRemote: ObserveRemoteRecordsUseCase,
        fetchLocal: FetchLocalRecordsUseCase,
        delete: DeleteSportRecordsUseCase,
        networkMonitor: NetworkMonitor
    ) {
        self.observeRemoteRecordsUseCase = observeRemote
        self.fetchLocalRecordsUseCase = fetchLocal
        self.deleteUseCase = delete
        self.networkMonitor = networkMonitor
    }

    // MARK: - Derived

    private var localRecords: [SportRecord] {
        guard case let .loaded(records) = content else { return [] }
        return records
    }

    private var allRecords: [SportRecord] {
        (localRecords + remoteRecords).sorted { $0.createdAt > $1.createdAt }
    }

    /// Whether any records exist at all, regardless of the selected filter — lets
    /// the view tell "nothing yet" apart from "nothing in this segment".
    public var hasRecords: Bool { !allRecords.isEmpty }

    public var visibleRecords: [SportRecord] {
        let records = switch filter {
        case .all: allRecords
        case .local: localRecords
        case .remote: remoteRecords
        }
        return records.filter { !pendingDeletes.contains($0.id) }
    }

    // MARK: - Loading

    public func load() async {
        await reloadLocal()
    }

    public func retry() async {
        await reloadLocal()
    }

    private func reloadLocal() async {
        if case .failed = content {
            content = .loading
        }
        do {
            let records = try await fetchLocalRecordsUseCase()
            content = .loaded(records)
        } catch {
            content = .failed
        }
    }

    // MARK: - Observing

    public func observeConnectivity() async {
        for await online in networkMonitor.updates {
            isOffline = !online
        }
    }

    public func observeData() async {
        await observeRemote()
    }

    private func observeRemote() async {
        if remoteUnavailable {
            remoteUnavailable = false
        }
        do {
            for try await records in observeRemoteRecordsUseCase() {
                remoteRecords = records
            }
        } catch {
            remoteUnavailable = true
        }
    }

    // MARK: - Deletion

    public func delete(_ record: SportRecord) async {
        pendingDeletes.insert(record.id)
        defer { pendingDeletes.remove(record.id) }

        do {
            try await deleteUseCase([record])
            removeRecords(ids: [record.id])
        } catch {
            deleteErrors = error.failedStores
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
        let currentSelection = selection
        let selected = allRecords.filter { currentSelection.contains($0.id) }
        guard !selected.isEmpty else { return }

        pendingDeletes = pendingDeletes.union(currentSelection)
        defer { pendingDeletes.subtract(currentSelection) }
        cancelEditing()

        do {
            try await deleteUseCase(selected)
            removeRecords(ids: currentSelection)
            pendingDeletes.subtract(currentSelection)
        } catch {
            let failed = error.failedStores
            let succeeded = selected.filter { !failed.contains($0.storageType) }
            removeRecords(ids: Set(succeeded.map(\.id)))
            deleteErrors = failed
        }
    }

    private func removeRecords(ids: Set<UUID>) {
        if case var .loaded(records) = content, !records.isEmpty {
            records.removeAll { ids.contains($0.id) }
            content = .loaded(records)
        }
        if !remoteRecords.isEmpty {
            remoteRecords.removeAll { ids.contains($0.id) }
        }
    }
}
