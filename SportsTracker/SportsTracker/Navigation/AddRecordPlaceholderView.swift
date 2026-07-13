import SwiftUI

/// Iteration-1 placeholder for the add-record sheet. Replaced by the real
/// add screen in iteration 2; the sheet seam is wired now so the flow works.
struct AddRecordPlaceholderView: View {
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Add Record",
                systemImage: "plus.circle",
                description: Text("Coming in iteration 2.")
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }
            }
        }
    }
}
