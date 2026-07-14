import SwiftUI

/// Owns the app's `NavigationStack` and presents the add-record sheet. The
/// records list is the stack's root view (it does not own a stack itself).
struct AppFlowView: View {
    @Bindable var router: AppRouter
    let factory: ScreenFactory

    var body: some View {
        NavigationStack(path: $router.path) {
            factory.recordsList()
            // No `.navigationDestination` yet: `Route` is uninhabited (no pushes
            // in iteration 1). The first push adds one `Route` case and one
            // `.navigationDestination(for: Route.self)` branch here.
        }
        .sheet(item: $router.sheet) { sheet in
            switch sheet {
            case .addRecord(let onSaved):
                factory.addRecord(onSaved: onSaved)
            }
        }
    }
}
