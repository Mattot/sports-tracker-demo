import SwiftUI

struct SportRecordRow: View {
    let record: SportRecord

    private var formattedDuration: String {
        Duration.seconds(record.duration)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(record.storageType.accentColor)
                .frame(width: 4)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.name)
                    .font(.headline)
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                    Text(record.location)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedDuration)
                    .font(.callout.monospacedDigit())
                Text(record.storageType.label)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(record.storageType.accentColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(record.storageType.accentColor)
            }
        }
        .padding(.vertical, 4)
    }
}
