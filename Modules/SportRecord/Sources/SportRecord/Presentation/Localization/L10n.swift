import Foundation

/// Typed access to the package's localized strings. Every value resolves against
/// `Bundle.module` so the feature stays self-contained. Keys and English source
/// live in `Resources/Localizable.xcstrings`; this enum is the only place that
/// names them. When the module count grows, replace this hand-written file with
/// SwiftGen output generated from the catalog.
enum L10n {
    enum List {
        static var title: String { str("list.title") }
    }
}

/// Resolves a catalog key against the package bundle.
private func str(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}
