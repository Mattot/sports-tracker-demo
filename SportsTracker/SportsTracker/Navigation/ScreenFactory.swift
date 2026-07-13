import SwiftUI
import FactoryKit
import SportRecord

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
                fetch: container.fetchSportRecordsUseCase(),
                delete: container.deleteSportRecordsUseCase(),
                networkMonitor: container.networkMonitor()
            ),
            onAddRecord: { router.present(.addRecord) }
        )
    }

    func addRecord() -> some View {
        AddRecordPlaceholderView(onClose: { router.dismissSheet() })
    }
}
