/// Thrown when one or both stores fail during a delete. Names exactly which
/// store(s) failed; the succeeded store's deletes are already committed.
public struct SportRecordsDeleteError: Error, Equatable, Sendable {
    public let failedStores: Set<StorageType>

    public init(failedStores: Set<StorageType>) {
        self.failedStores = failedStores
    }
}
