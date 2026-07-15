import SwiftUI

extension StorageType {
    /// Colour used to visually distinguish records by store (assignment requirement).
    var accentColor: Color {
        switch self {
        case .local: .blue
        case .remote: .purple
        }
    }

    var label: String {
        switch self {
        case .local: L10n.Storage.local
        case .remote: L10n.Storage.remote
        }
    }
}
