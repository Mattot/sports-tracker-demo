import SwiftUI

/// Full-screen scaffolding for loading / empty / failed states.
public struct ContentStateView: View {
    public enum State: Sendable {
        case loading
        case empty(title: String, message: String)
        case failed(title: String, message: String)
    }

    /// Optional call-to-action rendered under the message — e.g. "Try Again" on a
    /// failure, or "Refresh Data" on an empty state that has no pull-to-refresh.
    public struct Action {
        public let title: String
        public let handler: () -> Void

        public init(title: String, handler: @escaping () -> Void) {
            self.title = title
            self.handler = handler
        }
    }

    private let state: State
    private let action: Action?

    public init(state: State, action: Action? = nil) {
        self.state = state
        self.action = action
    }

    public var body: some View {
        switch state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .empty(title, message):
            ContentUnavailableView {
                Label(title, systemImage: "tray")
            } description: {
                Text(message)
            } actions: {
                actionButton
            }
        case let .failed(title, message):
            ContentUnavailableView {
                Label(title, systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                actionButton
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if let action {
            Button(action.title, action: action.handler)
        }
    }
}
