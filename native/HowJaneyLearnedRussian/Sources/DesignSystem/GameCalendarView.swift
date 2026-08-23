import SwiftUI

/// Shared month calendar for daily games: content days highlighted, completed
/// days green, in-progress days amber, today ringed, optional future lockout.
struct GameCalendarView: View {
    @Environment(\.theme) private var theme
    let availableDateKeys: Set<String>
    let playedDateKeys: Set<String>
    var partialDateKeys: Set<String> = []
    let selectedDateKey: String
    var disableFuture = false
    let onSelect: (String) -> Void

    @State private var displayedMonth: Date = .now

    private let weekdays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: Design.spacing) {
            HStack {
                Button("Previous month", systemImage: "chevron.left", action: { step(by: -1) })
                    .labelStyle(.iconOnly)
                    .padding(8)
                    .glassEffect(.regular.interactive())
                Spacer()
                Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)
                    .foregroundStyle(theme.accent)
                Spacer()
                Button("Next month", systemImage: "chevron.right", action: { step(by: 1) })
                    .labelStyle(.iconOnly)
                    .padding(8)
                    .glassEffect(.regular.interactive())
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .bold()
                        .foregroundStyle(theme.textSecondary)
                }
                ForEach(Array(dayCells.enumerated()), id: \.offset) { _, cell in
                    if let cell {
                        GameCalendarDayView(cell: cell, onSelect: onSelect)
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }

            Button("Today", systemImage: "calendar.circle", action: goToToday)
                .buttonStyle(.glass)

            HStack(spacing: Design.padding) {
                LegendDot(color: theme.accent, label: "Available")
                if !partialDateKeys.isEmpty {
                    LegendDot(color: theme.info, label: "In progress")
                }
                LegendDot(color: theme.successText, label: "Completed")
            }
            .font(.caption)
            .foregroundStyle(theme.textSecondary)
        }
        .padding(Design.padding)
        .presentationDetents([.medium, .large])
        .presentationBackground(.thinMaterial)
        .onAppear(perform: showSelectedMonth)
    }

    struct DayCell: Hashable {
        let day: Int
        let dateKey: String
        let hasData: Bool
        let isPlayed: Bool
        let isPartial: Bool
        let isToday: Bool
        let isSelected: Bool
        let isDisabled: Bool
    }

    private var dayCells: [DayCell?] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth)
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leadingPad = (firstWeekday + 5) % 7

        let year = calendar.component(.year, from: displayedMonth)
        let month = calendar.component(.month, from: displayedMonth)
        let todayKey = TriviaLogic.dateKey(for: .now)

        var cells: [DayCell?] = Array(repeating: nil, count: leadingPad)
        for day in dayRange {
            let key = String(format: "%04d%02d%02d", year, month, day)
            let isFuture = key > todayKey
            cells.append(
                DayCell(
                    day: day,
                    dateKey: key,
                    hasData: availableDateKeys.contains(key),
                    isPlayed: playedDateKeys.contains(key),
                    isPartial: partialDateKeys.contains(key),
                    isToday: key == todayKey,
                    isSelected: key == selectedDateKey,
                    isDisabled: disableFuture && isFuture
                )
            )
        }
        return cells
    }

    private func step(by months: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: months, to: displayedMonth) {
            displayedMonth = next
        }
    }

    private func goToToday() {
        displayedMonth = .now
    }

    private func showSelectedMonth() {
        if let selected = TriviaLogic.date(fromKey: selectedDateKey) {
            displayedMonth = selected
        }
    }
}

struct GameCalendarDayView: View {
    @Environment(\.theme) private var theme
    let cell: GameCalendarView.DayCell
    let onSelect: (String) -> Void

    private var isSelectable: Bool {
        cell.hasData && !cell.isDisabled
    }

    var body: some View {
        Button(action: select) {
            Text("\(cell.day)")
                .font(.subheadline)
                .bold(cell.hasData)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(background, in: .rect(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(borderColor, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isSelectable)
        .accessibilityLabel(accessibilityText)
    }

    private var background: Color {
        if cell.isPlayed { return theme.success.opacity(0.3) }
        if cell.isPartial { return theme.info.opacity(0.2) }
        return .clear
    }

    private var textColor: Color {
        if cell.isDisabled { return theme.textMuted.opacity(0.3) }
        if cell.isPlayed { return theme.successText }
        if cell.isPartial { return theme.info }
        if cell.hasData { return theme.accent }
        return theme.textMuted.opacity(0.5)
    }

    private var borderColor: Color {
        if cell.isSelected { return theme.textPrimary }
        if cell.isToday { return theme.accent }
        return .clear
    }

    private var accessibilityText: String {
        var text = "Day \(cell.day)"
        if cell.isDisabled { text += ", unavailable" }
        else if cell.isPlayed { text += ", completed" }
        else if cell.isPartial { text += ", in progress" }
        else if cell.hasData { text += ", available" }
        else { text += ", no game" }
        if cell.isToday { text += ", today" }
        return text
    }

    private func select() {
        onSelect(cell.dateKey)
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}
