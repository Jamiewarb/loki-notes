import SwiftUI
import LociCore
import LociDesignSystem

/// Month/week calendar anchored to daily notes (PR25).
struct CalendarView: View {
    var services: AppServices

    @State private var scope: CalendarScope = .month
    @State private var anchor: Date = DailyNoteIdentity.startOfDay(Date())
    @State private var selectedDay: Date?
    @State private var grid = CalendarGrid(
        scope: .month,
        anchor: Date(),
        title: "…",
        weekdaySymbols: [],
        cells: []
    )
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var jumpMessage: String?

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            HStack(spacing: LociSpacing.stack(.md)) {
                LociIcon(Route.calendar.systemImage, size: 22)
                    .foregroundStyle(LociColors.accent)
                Text(Route.calendar.title)
                    .font(LociTypography.font(.display))
                    .foregroundStyle(LociColors.ink)
                Spacer(minLength: 0)
                scopePicker
            }
            .lociAppear(.soft)

            Text(
                "Dots mark days with a daily note, body content, or creations from the local index. Select a day to open its daily note."
            )
            .font(LociTypography.font(.body))
            .foregroundStyle(LociColors.inkSoft)
            .frame(maxWidth: 520, alignment: .leading)

            periodHeader

            weekdayHeader

            calendarGrid
                .accessibilityIdentifier("calendar-grid")

            footerStats

            if let jumpMessage {
                Text(jumpMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                    .accessibilityIdentifier("calendar-jump-message")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
            }
        }
        .padding(LociSpacing.stack(.xl))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: reloadToken) { await reload() }
        .accessibilityIdentifier("calendar-destination")
    }

    private var reloadToken: String {
        let key = DailyNoteIdentity.dateKey(for: anchor, calendar: calendar)
        return "\(scope.rawValue)|\(key)|\(services.index == nil ? "0" : "1")"
    }

    private var scopePicker: some View {
        HStack(spacing: LociSpacing.stack(.xs)) {
            scopeChip(.month)
            scopeChip(.week)
        }
    }

    private func scopeChip(_ value: CalendarScope) -> some View {
        Button {
            scope = value
        } label: {
            Text(value == .month ? "Month" : "Week")
                .font(LociTypography.font(.caption))
                .foregroundStyle(scope == value ? LociColors.paper : LociColors.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(scope == value ? LociColors.accent : LociColors.panel)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("calendar-scope-\(value.rawValue)")
    }

    private var periodHeader: some View {
        HStack(spacing: LociSpacing.stack(.md)) {
            Button {
                anchor = CalendarGridBuilder.shiftAnchor(
                    anchor,
                    scope: scope,
                    by: -1,
                    calendar: calendar
                )
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("calendar-prev")

            Text(grid.title)
                .font(LociTypography.font(.headline))
                .foregroundStyle(LociColors.ink)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("calendar-title")

            Button {
                anchor = CalendarGridBuilder.shiftAnchor(
                    anchor,
                    scope: scope,
                    by: 1,
                    calendar: calendar
                )
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("calendar-next")
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
            spacing: 4
        ) {
            ForEach(grid.weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(LociTypography.font(.overline))
                    .foregroundStyle(LociColors.inkSoft)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
            spacing: 4
        ) {
            ForEach(grid.cells) { cell in
                dayCell(cell)
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .tint(LociColors.accent)
            }
        }
    }

    private func dayCell(_ cell: CalendarCell) -> some View {
        Button {
            Task { await selectDay(cell.day) }
        } label: {
            VStack(spacing: 4) {
                Text(dayNumber(cell.day))
                    .font(LociTypography.font(.callout))
                    .foregroundStyle(foreground(for: cell))
                Circle()
                    .fill(cell.showsDot ? LociColors.accent : Color.clear)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(!cell.showsDot)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(background(for: cell))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(cell.inCurrentPeriod ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("calendar-day-\(cell.dayKey)")
        .accessibilityLabel(accessibilityLabel(for: cell))
    }

    private var footerStats: some View {
        HStack(spacing: LociSpacing.stack(.md)) {
            Text("\(grid.markedDayCount) marked")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
                .accessibilityIdentifier("calendar-marked-count")
            if let selectedDay {
                Text("Selected \(DailyNoteIdentity.title(for: selectedDay, calendar: calendar))")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                    .accessibilityIdentifier("calendar-selected-day")
            }
            Spacer(minLength: 0)
        }
    }

    private func dayNumber(_ day: Date) -> String {
        String(calendar.component(.day, from: day))
    }

    private func foreground(for cell: CalendarCell) -> Color {
        if cell.isSelected { return LociColors.paper }
        if cell.isToday { return LociColors.accent }
        return LociColors.ink
    }

    private func background(for cell: CalendarCell) -> Color {
        if cell.isSelected { return LociColors.accent }
        if cell.isToday { return LociColors.panel }
        return Color.clear
    }

    private func accessibilityLabel(for cell: CalendarCell) -> String {
        var parts = [cell.dayKey]
        if cell.showsDot { parts.append("has activity") }
        if cell.isToday { parts.append("today") }
        if cell.isSelected { parts.append("selected") }
        return parts.joined(separator: ", ")
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await services.ensureIndex()
            let store = CalendarStore(index: services.index)
            grid = try await store.grid(
                scope: scope,
                anchor: anchor,
                selected: selectedDay,
                today: Date(),
                calendar: calendar
            )
        } catch {
            errorMessage = error.localizedDescription
            grid = CalendarGridBuilder.build(
                scope: scope,
                anchor: anchor,
                markers: [],
                selected: selectedDay,
                today: Date(),
                calendar: calendar
            )
        }
    }

    private func selectDay(_ day: Date) async {
        let start = DailyNoteIdentity.startOfDay(day, calendar: calendar)
        selectedDay = start
        services.inspectedDailyDay = start
        jumpMessage = nil
        errorMessage = nil

        // Refresh selection chrome immediately.
        grid = CalendarGridBuilder.build(
            scope: scope,
            anchor: anchor,
            markers: grid.cells.compactMap(\.marker),
            selected: start,
            today: Date(),
            calendar: calendar
        )

        do {
            _ = try await services.ensureIndex()
            guard let daily = services.dailyNotes else {
                errorMessage = "Daily notes unavailable — open a vault in Settings."
                return
            }
            let opened = try await daily.ensure(for: start, calendar: calendar)
            jumpMessage =
                "Opened \(DailyNoteIdentity.relativePath(for: start, calendar: calendar))"
            await services.open(objectID: opened.meta.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
