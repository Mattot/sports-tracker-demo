import SwiftUI
import Core

public struct RecordsListView: View {
    @State private var viewModel: RecordsListViewModel
    // The list supplies its own reload as the add screen's `onSaved`, so the
    // callback carries it: (onSaved) -> Void.
    private let onAddRecord: (@escaping () -> Void) -> Void

    public init(viewModel: RecordsListViewModel, onAddRecord: @escaping (@escaping () -> Void) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onAddRecord = onAddRecord
    }

    // Root view of the App-owned NavigationStack — it must NOT introduce its own
    // stack, so navigation state (path, title, toolbar) stays composed in App.
    public var body: some View {
        content
            .navigationTitle("Sport Records")
            .safeAreaInset(edge: .top, spacing: 0) { banner }
            .toolbar { toolbarContent }
            .confirmationDialog(
                "Delete \(viewModel.selection.count) record(s)?",
                isPresented: $viewModel.isDeleteConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task { await viewModel.deleteSelected() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert(
                "Delete failed",
                isPresented: Binding(
                    get: { viewModel.deleteError != nil },
                    set: { if !$0 { viewModel.deleteError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.deleteError ?? "")
            }
            .task { await viewModel.load() }
            .task { await viewModel.observeConnectivity() }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.content {
        case .loading:
            ContentStateView(state: .loading)
        case .empty:
            ContentStateView(state: .empty(title: "No Sport Records", message: "Add your first activity to see it here."))
        case .failed:
            ContentStateView(
                state: .failed(title: "Couldn't Load Records", message: "Something went wrong reaching your data."),
                onRetry: { Task { await viewModel.retry() } }
            )
        case .loaded:
            list
        }
    }

    private var list: some View {
        List(selection: $viewModel.selection) {
            Section {
                if viewModel.visibleRecords.isEmpty {
                    Text("No \(viewModel.filter.title.lowercased()) records")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.visibleRecords) { record in
                        SportRecordRow(record: record)
                            .tag(record.id)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await viewModel.delete(record) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            } header: {
                Picker("Filter", selection: $viewModel.filter) {
                    ForEach(RecordsFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .textCase(nil)
                .listRowInsets(EdgeInsets())
                .padding(.bottom, 8)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(viewModel.isEditing ? .active : .inactive))
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Banner

    @ViewBuilder
    private var banner: some View {
        if viewModel.isOffline {
            MessageBanner("You're offline — showing local records.", style: .warning)
        } else if viewModel.remoteUnavailable {
            MessageBanner("Couldn't reach remote — showing local records.", style: .info)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(viewModel.isEditing ? "Done" : "Select") {
                viewModel.isEditing.toggle()
                if !viewModel.isEditing { viewModel.selection = [] }
            }
            // Nothing to select when the current filter shows no records — but
            // never disable "Done", or the user could get stuck in edit mode.
            .disabled(!viewModel.isEditing && viewModel.visibleRecords.isEmpty)
        }
        ToolbarItem(placement: .topBarTrailing) {
            if viewModel.isEditing {
                Button("Delete", role: .destructive) {
                    viewModel.requestDeleteSelection()
                }
                .disabled(viewModel.selection.isEmpty)
            } else {
                Button {
                    onAddRecord { Task { await viewModel.load() } }
                } label: {
                    Label("Add Record", systemImage: "plus")
                }
            }
        }
    }
}
