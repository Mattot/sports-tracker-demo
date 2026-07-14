import SwiftUI
import Core

public struct RecordsListView: View {
    @State private var viewModel: RecordsListViewModel
    // The list supplies its own reload as the add screen's `onSaved`, so the
    // callback carries it: (onSaved) -> Void.
    private let onAddRecord: (@escaping () -> Void) -> Void

    @Environment(\.scenePhase) private var scenePhase
    // Measured List height, used to make the empty state fill the viewport
    // (containerRelativeFrame doesn't size reliably inside a List).
    @State private var listHeight: CGFloat = 0

    public init(viewModel: RecordsListViewModel, onAddRecord: @escaping (@escaping () -> Void) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onAddRecord = onAddRecord
    }

    // Root view of the App-owned NavigationStack — it must NOT introduce its own
    // stack, so navigation state (path, title, toolbar) stays composed in App.
    public var body: some View {
        content
            .navigationTitle("Sport Records")
            .toolbar { toolbarContent }
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
            // Entering the foreground: pick up anything added or removed elsewhere
            // (other device, Firestore console) while the app wasn't in front.
            // `onChange` doesn't fire for the initial value, so launch is unaffected —
            // the initial fetch stays with `.task { load() }`.
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await viewModel.refresh() }
            }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.content {
        case .loading:
            ContentStateView(state: .loading)
        case .failed:
            ContentStateView(
                state: .failed(title: "Couldn't Load Records", message: "Something went wrong reaching your data."),
                action: .init(title: "Try Again") { Task { await viewModel.retry() } }
            )
        case .loaded:
            recordsList
        }
    }

    /// A single plain List: the offline banner scrolls above a pinned (sticky)
    /// segmented-filter section header, and the section body is the rows or a
    /// centered empty state. Everything scrolls, so pull-to-refresh works on
    /// every segment.
    private var recordsList: some View {
        List(selection: $viewModel.selection) {
            banner
            Section {
                if viewModel.visibleRecords.isEmpty {
                    emptyRow
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
                filterPicker
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(viewModel.isEditing ? .active : .inactive))
        .refreshable { await viewModel.refresh() }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { listHeight = proxy.size.height }
                    .onChange(of: proxy.size.height) { _, height in listHeight = height }
            }
        }
    }

    private var filterPicker: some View {
        Picker("Filter", selection: $viewModel.filter) {
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
    /// message when the selected segment is empty. Sized to the measured List
    /// height so it fills/centres, and untagged + `selectionDisabled` so edit
    /// mode can't select it.
    @ViewBuilder
    private var emptyRow: some View {
        let state: ContentStateView.State = viewModel.hasRecords
            ? .empty(title: "No \(viewModel.filter.title) Records", message: "You have no \(viewModel.filter.title.lowercased()) records yet.")
            : .empty(title: "No Sport Records", message: "Add your first activity to see it here.")
        ContentStateView(state: state)
            .frame(maxWidth: .infinity, minHeight: listHeight)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .selectionDisabled()
    }

    // MARK: - Banner (a scrollable row above the sticky filter)

    @ViewBuilder
    private var banner: some View {
        if viewModel.isOffline {
            bannerRow("You're offline — showing local records.", style: .warning)
        } else if viewModel.remoteUnavailable {
            bannerRow("Couldn't reach remote — showing local records.", style: .info)
        }
    }

    private func bannerRow(_ text: String, style: MessageBanner.Style) -> some View {
        MessageBanner(text, style: style)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .selectionDisabled()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(viewModel.isEditing ? "Done" : "Edit") {
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
                Label("Add Record", systemImage: "plus")
            }
        }
        // Delete lives in the bottom bar while editing; the confirmation hangs off
        // this action rather than the content.
        if viewModel.isEditing {
            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) {
                    viewModel.requestDeleteSelection()
                } label: {
                    Text("Delete Records (\(viewModel.selection.count))")
                }
                .disabled(viewModel.selection.isEmpty)
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
            }
        }
    }
}
