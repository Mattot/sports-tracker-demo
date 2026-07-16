import SwiftUI

struct SportRecordRow: View {
    let record: SportRecord

    private var formattedDuration: String {
        Duration.seconds(record.duration)
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .narrow))
    }

    /// Spelled-out duration for VoiceOver ("1 hour, 2 minutes") — the `.narrow`
    /// display form ("1h 2m") reads poorly aloud.
    private var spokenDuration: String {
        Duration.seconds(record.duration)
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(record.storageType.accentColor)
                .frame(width: 4)
                .frame(maxHeight: .infinity)

            // Single row normally; stacks when large accessibility text sizes stop
            // the horizontal layout from fitting, so nothing truncates.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    leading
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 4) {
                        durationText
                        badge
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    leading
                    HStack(spacing: 8) {
                        durationText
                        badge
                    }
                }
            }
        }
        .padding(.vertical, 4)
        // One combined element instead of five separate VoiceOver stops.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(record.name), \(record.location), \(spokenDuration), \(record.storageType.label)"
        )
    }

    private var leading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.name)
                .font(.headline)
            HStack(spacing: 4) {
                Image(systemName: "mappin.and.ellipse")
                    .accessibilityHidden(true)
                Text(record.location)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var durationText: some View {
        Text(formattedDuration)
            .font(.callout.monospacedDigit())
    }

    private var badge: some View {
        HStack(spacing: 3) {
            Image(systemName: record.storageType.symbolName)
            Text(record.storageType.label)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(record.storageType.accentColor, in: Capsule())
        .foregroundStyle(.white)
    }
}
