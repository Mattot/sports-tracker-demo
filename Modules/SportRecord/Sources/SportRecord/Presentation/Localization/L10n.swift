import Foundation

/// Typed access to the package's localized strings. Every value resolves against
/// `Bundle.module` so the feature stays self-contained. Keys and English source
/// live in `Resources/Localizable.xcstrings`; this enum is the only place that
/// names them. When the module count grows, replace this hand-written file with
/// SwiftGen output generated from the catalog.
enum L10n {
    enum List {
        static var title: String { str("list.title") }
        static var deleteFailedTitle: String { str("list.deleteError.title") }
        static var loadErrorTitle: String { str("list.loadError.title") }
        static var loadErrorMessage: String { str("list.loadError.message") }
        static var emptyTitle: String { str("list.empty.title") }
        static var emptyMessage: String { str("list.empty.message") }
        static var bannerOffline: String { str("list.banner.offline") }
        static var bannerRemoteUnavailable: String { str("list.banner.remoteUnavailable") }
        static var addButton: String { str("list.add.button") }
        static var filterPicker: String { str("list.filter.picker") }
        static var deleteErrorBoth: String { str("list.deleteError.both") }
        static var deleteErrorRemote: String { str("list.deleteError.remote") }
        static var deleteErrorLocal: String { str("list.deleteError.local") }
        static var deleteErrorUnknown: String { str("list.deleteError.unknown") }

        static func emptyFilteredTitle(_ filter: String) -> String {
            String(format: str("list.empty.filtered.title"), filter)
        }
        static func emptyFilteredMessage(_ filter: String) -> String {
            String(format: str("list.empty.filtered.message"), filter)
        }
        static func deleteSelectionButton(_ count: Int) -> String {
            String(format: str("list.deleteSelection.button"), count)
        }
        static func deleteConfirmTitle(_ count: Int) -> String {
            String(localized: "list.deleteConfirm.title \(count)", bundle: .module)
        }
    }

    enum Filter {
        static var all: String { str("filter.all") }
        static var local: String { str("filter.local") }
        static var remote: String { str("filter.remote") }
    }

    enum Common {
        static var ok: String { str("common.ok") }
        static var cancel: String { str("common.cancel") }
        static var delete: String { str("common.delete") }
        static var done: String { str("common.done") }
        static var edit: String { str("common.edit") }
        static var tryAgain: String { str("common.tryAgain") }
        static var save: String { str("common.save") }
        static var loading: String { str("common.loading") }
    }

    enum AddRecord {
        static var title: String { str("addRecord.title") }
        static var sectionActivity: String { str("addRecord.section.activity") }
        static var namePlaceholder: String { str("addRecord.name.placeholder") }
        static var locationPlaceholder: String { str("addRecord.location.placeholder") }
        static var sectionDuration: String { str("addRecord.section.duration") }
        static var sectionStorage: String { str("addRecord.section.storage") }
        static var storagePicker: String { str("addRecord.storage.picker") }
        static var saveErrorTitle: String { str("addRecord.saveError.title") }
        static var saveErrorRemote: String { str("addRecord.saveError.remote") }
        static var saveErrorLocal: String { str("addRecord.saveError.local") }
        static var durationHours: String { str("addRecord.duration.hours") }
        static var durationMinutes: String { str("addRecord.duration.minutes") }
        static var durationSeconds: String { str("addRecord.duration.seconds") }
    }

    enum Storage {
        static var local: String { str("storageType.local") }
        static var remote: String { str("storageType.remote") }
    }
}

/// Resolves a catalog key against the package bundle.
private func str(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}
