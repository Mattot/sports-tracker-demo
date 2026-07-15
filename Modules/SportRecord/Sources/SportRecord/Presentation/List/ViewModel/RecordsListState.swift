/// Primary content state of the list, independent of the offline banner.
/// No separate `empty` case — `loaded([])` says the same thing.
public enum RecordsContentState: Sendable, Equatable {
    case loading
    case loaded([SportRecord])
    case failed
}

/// Segmented-control filter. `all` shows both stores.
public enum RecordsFilter: String, CaseIterable, Sendable, Identifiable {
    case all
    case local
    case remote

    public var id: Self { self }

    public var title: String {
        switch self {
        case .all: L10n.Filter.all
        case .local: L10n.Filter.local
        case .remote: L10n.Filter.remote
        }
    }
}
