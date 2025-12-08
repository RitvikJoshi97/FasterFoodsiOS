import SwiftUI

enum WorkoutHistoryGraphMode: String, CaseIterable {
    case week = "W"
    case month = "M"
}

struct WorkoutHistoryGraphsView: View {
    let mode: WorkoutHistoryGraphMode
    let items: [WorkoutLogItem]

    private let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EE")
        return formatter
    }()

    private var calendar: Calendar { Calendar.current }
    private var monthReferenceDate: Date {
        let dates = items.compactMap { parse(dateString: $0.datetime) }
        return dates.max() ?? Date()
    }
    private var weekEndDate: Date {
        calendar.startOfDay(for: Date())
    }

    var body: some View {
        graphContent
            .padding(.vertical, 4)
    }

    @ViewBuilder
    private var graphContent: some View {
        switch mode {
        case .week:
            weekView
        case .month:
            monthView
        }
    }

    private var weekView: some View {
        HStack(spacing: 12) {
            ForEach(weekDates, id: \.self) { date in
                VStack(spacing: 6) {
                    Text(weekdayLabel(for: date))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Circle()
                        .fill(hasWorkout(on: date) ? Color.accentColor : .clear)
                        .frame(width: 10, height: 10)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthView: some View {
        LazyVGrid(columns: monthGridColumns, spacing: 8) {
            ForEach(Array(monthDates.enumerated()), id: \.offset) { _, date in
                monthCell(for: date)
            }
        }
    }

    @ViewBuilder
    private func monthCell(for date: Date?) -> some View {
        if let date {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.caption2.weight(calendar.isDateInToday(date) ? .semibold : .regular))
                    .foregroundStyle(calendar.isDateInToday(date) ? .primary : .secondary)

                if hasWorkout(on: date) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                } else {
                    Color.clear
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 20)
        } else {
            Color.clear
                .frame(height: 20)
        }
    }

    private var weekDates: [Date] {
        let endDate = weekEndDate
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: endDate) else {
            return []
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startDate) }
    }

    private var monthDates: [Date?] {
        guard
            let startOfMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: monthReferenceDate)),
            let dayRange = calendar.range(of: .day, in: .month, for: startOfMonth)
        else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let offset =
            (firstWeekday - calendar.firstWeekday + 7) % 7

        var dates: [Date?] = Array(repeating: nil, count: offset)
        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                dates.append(date)
            }
        }
        let remainder = dates.count % 7
        if remainder != 0 {
            dates.append(contentsOf: Array(repeating: nil, count: 7 - remainder))
        }
        return dates
    }

    private var monthGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    }

    private var workoutDays: Set<Date> {
        let startOfDayDates = items.compactMap { item -> Date? in
            guard let date = parse(dateString: item.datetime) else { return nil }
            return calendar.startOfDay(for: date)
        }
        return Set(startOfDayDates)
    }

    private func parse(dateString: String) -> Date? {
        isoFormatterWithFractional.date(from: dateString) ?? isoFormatter.date(from: dateString)
    }

    private func hasWorkout(on date: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        return workoutDays.contains(dayStart)
    }

    private func weekdayLabel(for date: Date) -> String {
        weekdayFormatter.string(from: date)
    }
}
