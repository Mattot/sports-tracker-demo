import SwiftUI
import Observation

/// Push destinations. Uninhabited today — the list has no pushes yet. The first
/// push is one enum case + one `navigationDestination` branch in `AppFlowView`.
/// (`Codable` is intentionally omitted: it can't be synthesized for an empty
/// enum, and `NavigationStack(path:)` only needs `Hashable`. Add it alongside
/// the first case if path state-restoration is wanted.)
enum Route: Hashable, Sendable {}

/// Modal surfaces. One today.
enum Sheet: Identifiable, Hashable {
    case addRecord
    var id: Self { self }
}

@Observable
@MainActor
final class AppRouter {
    var path: [Route] = []
    var sheet: Sheet?

    // `push(_:)` arrives with the first `Route` case — a function taking the
    // currently-uninhabited `Route` would be uncallable (dead code).
    func pop() { guard !path.isEmpty else { return }; path.removeLast() }
    func popToRoot() { path.removeAll() }

    func present(_ sheet: Sheet) { self.sheet = sheet }
    func dismissSheet() { sheet = nil }
}
