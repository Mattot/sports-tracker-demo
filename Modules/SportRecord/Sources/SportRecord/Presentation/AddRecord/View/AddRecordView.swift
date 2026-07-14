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
            Section("Activity") {
                TextField("Name", text: $viewModel.name)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .location }
                TextField("Location", text: $viewModel.location)
                    .focused($focusedField, equals: .location)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
            }
            Section("Duration") {
                DurationPicker(
                    hours: $viewModel.hours,
                    minutes: $viewModel.minutes,
                    seconds: $viewModel.seconds
                )
            }
            Section("Storage") {
                Picker("Select storage", selection: $viewModel.storageType) {
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
        .navigationTitle("Add Record")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onCancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { if await viewModel.save() { onSaved() } }
                }
                .disabled(!viewModel.canSave)
            }
        }
        .alert(
            "Couldn't Save",
            isPresented: Binding(
                get: { viewModel.saveError != nil },
                set: { if !$0 { viewModel.saveError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.saveError ?? "")
        }
        .interactiveDismissDisabled(viewModel.isSaving)
    }
}
