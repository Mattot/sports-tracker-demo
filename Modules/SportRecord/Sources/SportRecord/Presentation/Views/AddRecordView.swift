import SwiftUI

public struct AddRecordView: View {
    @State private var viewModel: AddRecordViewModel
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
                TextField("Location", text: $viewModel.location)
            }
            Section("Duration") {
                DurationPicker(
                    hours: $viewModel.hours,
                    minutes: $viewModel.minutes,
                    seconds: $viewModel.seconds
                )
            }
            Section("Storage") {
                Picker("Storage", selection: $viewModel.storageType) {
                    ForEach(StorageType.allCases, id: \.self) { type in
                        Text(type.label).tag(type)
                    }
                }
                .pickerStyle(.menu)
            }
        }
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
