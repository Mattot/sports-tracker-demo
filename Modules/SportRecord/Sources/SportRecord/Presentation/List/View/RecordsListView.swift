import Core
import SwiftUI

public struct RecordsListView: View {
    @State private var viewModel: RecordsListViewModel
    // The list supplies its own reload as the add screen's `onSaved`, so the
    // callback carries it: (onSaved) -> Void.
    private let onAddRecord: (@escaping () -> Void) -> Void

    // used to reattach data observation on view load or if previously failed
    @State private var triggerObserveData = true

    public init(viewModel: RecordsListViewModel, onAddRecord: @escaping (@escaping () -> Void) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onAddRecord = onAddRecord
    }

    public var body: some View {
        content
            .navigationTitle(L10n.List.title)
            .toolbar { toolbarContent }
            .alert(
                L10n.List.deleteFailedTitle,
                isPresented: Binding(
                    get: { !viewModel.deleteErrors.isEmpty },
                    set: { if !$0 { viewModel.deleteErrors = [] } }
                )
            ) {
                Button(L10n.Common.ok, role: .cancel) {}
            } message: {
                Text(message(for: viewModel.deleteErrors))
            }
            .task { await viewModel.load() }
            .task { await viewModel.observeConnectivity() }
            .task(id: triggerObserveData) {
                await viewModel.observeData()
            }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            banner

            switch viewModel.content {
            case .loading:
                ContentStateView(state: .loading)
            case .failed:
                ContentStateView(
                    state: .failed(title: L10n.List.loadErrorTitle, message: L10n.List.loadErrorMessage),
                    action: .init(title: L10n.Common.tryAgain) { Task { await viewModel.retry() } }
                )
            case .loaded:
                filterPicker
                if viewModel.visibleRecords.isEmpty {
                    emptyState
                } else {
                    recordsList
                }
            }
        }
        .animation(.default, value: viewModel.remoteUnavailable)
        .animation(.default, value: viewModel.isOffline)
    }

    private var recordsList: some View {
        List(selection: $viewModel.selection) {
            ForEach(viewModel.visibleRecords) { record in
                SportRecordRow(record: record)
                    .tag(record.id)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await viewModel.delete(record) }
                        } label: {
                            Label(L10n.Common.delete, systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.editMode, .constant(viewModel.isEditing ? .active : .inactive))
        .animation(.default, value: viewModel.visibleRecords)
    }

    private var filterPicker: some View {
        Picker(L10n.List.filterPicker, selection: $viewModel.filter) {
            ForEach(RecordsFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .textCase(nil)
        .listRowInsets(EdgeInsets())
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// Overall "no records yet" when nothing exists anywhere, or a per-filter
    /// message when the selected segment is empty.
    @ViewBuilder
    private var emptyState: some View {
        ContentStateView(
            state: viewModel.hasRecords
                ? .empty(
                    title: L10n.List.emptyFilteredTitle(viewModel.filter.title),
                    message: L10n.List.emptyFilteredMessage(viewModel.filter.title.lowercased())
                )
                : .empty(title: L10n.List.emptyTitle, message: L10n.List.emptyMessage)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Banner

    @ViewBuilder
    private var banner: some View {
        if viewModel.remoteUnavailable {
            bannerRow(
                L10n.List.bannerRemoteUnavailable,
                style: .error,
                action: .init(title: L10n.Common.tryAgain) { triggerObserveData.toggle() }
            )
        }
        if viewModel.isOffline {
            bannerRow(L10n.List.bannerOffline, style: .warning)
        }
    }

    private func bannerRow(_ text: String, style: MessageBanner.Style, action: MessageBanner.Action? = nil) -> some View {
        MessageBanner(text, style: style, action: action)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .selectionDisabled()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(viewModel.isEditing ? L10n.Common.done : L10n.Common.edit) {
                withAnimation {
                    if viewModel.isEditing {
                        viewModel.cancelEditing()
                    } else {
                        viewModel.isEditing = true
                    }
                }
            }
            // Disabled only when there's nothing to edit at all (no records / error) —
            // the selected segment doesn't matter. Never disable "Done".
            .disabled(!viewModel.isEditing && !viewModel.hasRecords)
        }
        // Add stays put in edit mode — tapping it just cancels editing first.
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.cancelEditing()
                onAddRecord { Task { await viewModel.load() } }
            } label: {
                Label(L10n.List.addButton, systemImage: "plus")
            }
        }
        // Delete lives in the bottom bar while editing; the confirmation hangs off
        // this action rather than the content.
        if viewModel.isEditing {
            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) {
                    viewModel.requestDeleteSelection()
                } label: {
                    Text(L10n.List.deleteSelectionButton(viewModel.selection.count))
                }
                .disabled(viewModel.selection.isEmpty)
                .confirmationDialog(
                    L10n.List.deleteConfirmTitle(viewModel.selection.count),
                    isPresented: $viewModel.isDeleteConfirmationPresented,
                    titleVisibility: .visible
                ) {
                    Button(L10n.Common.delete, role: .destructive) {
                        Task { await viewModel.deleteSelected() }
                    }
                    Button(L10n.Common.cancel, role: .cancel) {}
                }
            }
        }
    }

    // MARK: - Error message

    private func message(for stores: Set<StorageType>) -> String {
        switch (stores.contains(.local), stores.contains(.remote)) {
        case (true, true): L10n.List.deleteErrorBoth
        case (false, true): L10n.List.deleteErrorRemote
        case (true, false): L10n.List.deleteErrorLocal
        case (false, false): L10n.List.deleteErrorUnknown
        }
    }
}
