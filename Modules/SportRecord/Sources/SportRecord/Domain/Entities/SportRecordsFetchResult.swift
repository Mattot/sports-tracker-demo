/// Result of a combined fetch across both stores. A single-store failure still
/// returns the other store's records and records which store(s) failed.
public struct SportRecordsFetchResult: Sendable {
    public let records: [SportRecord]  // merged, sorted by createdAt desc
    public let failedStores: Set<StorageType>

    public init(records: [SportRecord], failedStores: Set<StorageType>) {
        self.records = records
        self.failedStores = failedStores
    }
}
