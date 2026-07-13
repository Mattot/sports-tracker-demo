import Foundation
import Network
import os

/// Observes device connectivity. `isOnline` is the last known value; `updates`
/// yields the current value on subscription and then every change.
public protocol NetworkMonitor: Sendable {
    var isOnline: Bool { get }
    var updates: AsyncStream<Bool> { get }
}

/// `NWPathMonitor`-backed implementation. Thread-safe via an unfair lock so it
/// can satisfy `Sendable` with a synchronous `isOnline` getter.
public final class PathNetworkMonitor: NetworkMonitor {
    private struct State {
        var isOnline = true
        var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.sportstracker.network-monitor")
    private let state = OSAllocatedUnfairLock(initialState: State())

    public init() {
        monitor.pathUpdateHandler = { [state] path in
            let online = path.status == .satisfied
            state.withLock { current in
                current.isOnline = online
                for continuation in current.continuations.values {
                    continuation.yield(online)
                }
            }
        }
        monitor.start(queue: queue)
    }

    public var isOnline: Bool {
        state.withLock { $0.isOnline }
    }

    public var updates: AsyncStream<Bool> {
        AsyncStream { continuation in
            let id = UUID()
            let current = state.withLock { current -> Bool in
                current.continuations[id] = continuation
                return current.isOnline
            }
            continuation.yield(current)
            continuation.onTermination = { [state] _ in
                state.withLock { _ = $0.continuations.removeValue(forKey: id) }
            }
        }
    }

    deinit {
        monitor.cancel()
    }
}
