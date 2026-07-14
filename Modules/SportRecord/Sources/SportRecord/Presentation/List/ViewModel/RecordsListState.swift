/// Primary content state of the list, independent of the offline banner.
public enum RecordsContentState: Sendable, Equatable {
    case loading
    case empty
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
        case .all: "All"
        case .local: "Local"
        case .remote: "Remote"
        }
    }
}
