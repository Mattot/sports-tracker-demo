import Foundation
import Network

/// Observes device connectivity as a stream of "is online" values. Each
/// subscription to `updates` starts its own `NWPathMonitor`, yields the current
/// reachability, then every change, until the consuming task ends.
public protocol NetworkMonitor: Sendable {
    var updates: AsyncStream<Bool> { get }
}

/// `NWPathMonitor`-backed implementation. Lockless: the monitor lives entirely
/// inside the `AsyncStream` closure and is cancelled when the stream terminates
/// (i.e. when the observing task is cancelled), so there is no shared mutable
/// state to synchronize and nothing to reconcile with Swift 6 isolation.
public struct PathNetworkMonitor: NetworkMonitor {
    public init() {}

    public var updates: AsyncStream<Bool> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "com.matusselecky.sportstracker.connectivity")
            monitor.pathUpdateHandler = { path in
                continuation.yield(path.status == .satisfied)
            }
            continuation.onTermination = { _ in
                monitor.cancel()
                Loggers.connectivity.debug("Path monitor cancelled")
            }
            monitor.start(queue: queue)
            Loggers.connectivity.debug("Path monitor started")
        }
    }
}
