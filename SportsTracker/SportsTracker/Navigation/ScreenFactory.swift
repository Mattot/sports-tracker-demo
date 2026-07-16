import FactoryKit
import SportRecord
import SwiftUI

/// Composition root: resolves dependencies from the container and builds screens
/// with constructor-injected ViewModels. Screens receive navigation as closures,
/// so they never know the router exists.
@MainActor
struct ScreenFactory {
    let container: Container
    let router: AppRouter

    func recordsList() -> some View {
        RecordsListView(
            viewModel: RecordsListViewModel(
                observeRemote: container.observeRemoteRecordsUseCase(),
                fetchLocal: container.fetchLocalRecordsUseCase(),
                delete: container.deleteSportRecordsUseCase(),
                networkMonitor: container.networkMonitor()
            ),
            onAddRecord: { onSaved in router.present(.addRecord(onSaved: onSaved)) }
        )
    }

    func addRecord(onSaved: @escaping () -> Void) -> some View {
        NavigationStack {
            AddRecordView(
                viewModel: AddRecordViewModel(save: container.saveSportRecordUseCase()),
                onSaved: {
                    onSaved()
                    router.dismissSheet()
                },
                onCancel: { router.dismissSheet() }
            )
        }
    }
}
