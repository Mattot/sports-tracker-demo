import SwiftUI

public struct AddRecordView: View {
    private enum Field { case name, location }

    @State private var viewModel: AddRecordViewModel
    @FocusState private var focusedField: Field?

    private let onSaved: () -> Void
    private let onCancel: () -> Void

    public init(
        viewModel: AddRecordViewModel,
        onSaved: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
        self.onCancel = onCancel
    }

    public var body: some View {
        Form {
            Section(L10n.AddRecord.sectionActivity) {
                TextField(L10n.AddRecord.namePlaceholder, text: $viewModel.name)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .location }
                TextField(L10n.AddRecord.locationPlaceholder, text: $viewModel.location)
                    .focused($focusedField, equals: .location)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
            }
            Section(L10n.AddRecord.sectionDuration) {
                DurationPicker(
                    hours: $viewModel.hours,
                    minutes: $viewModel.minutes,
                    seconds: $viewModel.seconds
                )
            }
            Section(L10n.AddRecord.sectionStorage) {
                Picker(L10n.AddRecord.storagePicker, selection: $viewModel.storageType) {
                    ForEach(StorageType.allCases, id: \.self) { type in
                        Text(type.label)
                            .foregroundStyle(type.accentColor)
                            .tag(type)
                    }
                }
                .pickerStyle(.menu)
                .tint(viewModel.storageType.accentColor)
            }
        }
        .onAppear { focusedField = .name }
        .navigationTitle(L10n.AddRecord.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.Common.cancel) {
                    onCancel()
                }
                .disabled(viewModel.isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.Common.save) {
                    Task { if await viewModel.save() { onSaved() } }
                }
                .disabled(!viewModel.canSave || viewModel.isSaving)
            }
        }
        .alert(
            L10n.AddRecord.saveErrorTitle,
            isPresented: Binding(
                get: { viewModel.saveError != nil },
                set: { if !$0 { viewModel.saveError = nil } }
            )
        ) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(viewModel.saveError ?? "")
        }
        .interactiveDismissDisabled(viewModel.isSaving)
    }
}
