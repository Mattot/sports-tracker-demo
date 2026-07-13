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

    private let text: String
    private let style: Style

    public init(_ text: String, style: Style = .warning) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: style.systemImage)
            Text(text)
                .font(.footnote.weight(.medium))
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.tint.opacity(0.15))
        .foregroundStyle(style.tint)
    }
}
