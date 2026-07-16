import SwiftUI

/// A full-width inline banner for non-blocking status messages (e.g. offline).
public struct MessageBanner: View {
    public enum Style: Sendable {
        case info, warning, error

        var systemImage: String {
            switch self {
            case .info: "info.circle.fill"
            case .warning: "wifi.slash"
            case .error: "exclamationmark.triangle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .info: .blue
            case .warning: .orange
            case .error: .red
            }
        }
    }

    public struct Action {
        public let title: String
        public let handler: () -> Void

        public init(title: String, handler: @escaping () -> Void) {
            self.title = title
            self.handler = handler
        }
    }

    private let text: String
    private let style: Style
    private let action: Action?

    public init(
        _ text: String,
        style: Style = .warning,
        action: Action? = nil
    ) {
        self.text = text
        self.style = style
        self.action = action
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: style.systemImage)
                .foregroundStyle(style.tint)
                .accessibilityHidden(true)

            Text(text)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            if let action {
                Button(action.title, action: action.handler)
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(style.tint)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.tint.opacity(0.15))
    }
}
