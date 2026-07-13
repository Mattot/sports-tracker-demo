/// Which store a record physically lives in. `All` is a *filter*, not a
/// storage type, so it is intentionally absent here.
public enum StorageType: String, CaseIterable, Sendable {
    case local
    case remote
}
