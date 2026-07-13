import Foundation

/// Single-store gateway for the local database.
public protocol LocalSportRecordDataSource: Sendable {
    func fetch() async throws -> [SportRecord]
    func insert(_ record: SportRecord) async throws
    func delete(ids: [UUID]) async throws
}

/// Single-store gateway for the remote backend.
public protocol RemoteSportRecordDataSource: Sendable {
    func fetch() async throws -> [SportRecord]
    func insert(_ record: SportRecord) async throws
    func delete(ids: [UUID]) async throws
}
