import SwiftUI
import LociCore
import LociDesignSystem

/// Prev / next day + date selection for the Daily destination.
struct DaySwitcher: View {
    @Binding var selectedDay: Date
    var calendar: Calendar = .current
    var onChange: ((Date) -> Void)?

    var body: some View {
        HStack(spacing: LociSpacing.stack(.sm)) {
            Button {
                shift(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous day")

            DatePicker(
                "Day",
                selection: Binding(
                    get: { selectedDay },
                    set: { newValue in
                        let day = DailyNoteIdentity.startOfDay(newValue, calendar: calendar)
                        selectedDay = day
                        onChange?(day)
                    }
                ),
                displayedComponents: [.date]
            )
            .labelsHidden()
            .datePickerStyle(.compact)

            Button {
                shift(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next day")

            Spacer(minLength: 0)

            Button("Today") {
                let today = DailyNoteIdentity.startOfDay(Date(), calendar: calendar)
                selectedDay = today
                onChange?(today)
            }
            .font(LociTypography.font(.caption))
            .foregroundStyle(LociColors.accent)
            .buttonStyle(.plain)
            .accessibilityLabel("Jump to today")
        }
        .foregroundStyle(LociColors.ink)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("day-switcher")
    }

    private func shift(by days: Int) {
        let next = DailyNoteIdentity.shift(selectedDay, byDays: days, calendar: calendar)
        selectedDay = next
        onChange?(next)
    }
}
