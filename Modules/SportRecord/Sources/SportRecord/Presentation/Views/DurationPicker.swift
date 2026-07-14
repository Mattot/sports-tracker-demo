import SwiftUI

/// Three wheel pickers — hours / minutes / seconds — bound to Int components.
struct DurationPicker: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    @Binding var seconds: Int

    var body: some View {
        HStack(spacing: 0) {
            wheel($hours, range: 0..<24, unit: "h")
            wheel($minutes, range: 0..<60, unit: "m")
            wheel($seconds, range: 0..<60, unit: "s")
        }
        .frame(maxWidth: .infinity)
    }

    private func wheel(_ value: Binding<Int>, range: Range<Int>, unit: String) -> some View {
        Picker(unit, selection: value) {
            ForEach(range, id: \.self) { Text("\($0) \(unit)").tag($0) }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}
