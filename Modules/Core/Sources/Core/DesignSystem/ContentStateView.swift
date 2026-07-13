import SwiftUI

/// Full-screen scaffolding for loading / empty / failed states.
public struct ContentStateView: View {
    public enum State: Sendable {
        case loading
        case empty(title: String, message: String)
        case failed(title: String, message: String)
    }

    private let state: State
    private let onRetry: (() -> Void)?

    public init(state: State, onRetry: (() -> Void)? = nil) {
        self.state = state
        self.onRetry = onRetry
    }

    public var body: some View {
        switch state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .empty(title, message):
            ContentUnavailableView(title, systemImage: "tray", description: Text(message))
        case let .failed(title, message):
            ContentUnavailableView {
                Label(title, systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                if let onRetry {
                    Button("Try Again", action: onRetry)
                }
            }
        }
    }
}
