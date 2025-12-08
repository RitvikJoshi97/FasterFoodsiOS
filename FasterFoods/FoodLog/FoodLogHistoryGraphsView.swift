import SwiftUI

enum FoodLogHistoryGraphMode: String, CaseIterable {
    case day = "D"
    case week = "W"
    case month = "M"
}

struct FoodLogHistoryGraphsView: View {
    let mode: FoodLogHistoryGraphMode
    let items: [FoodLogItem]

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

    private var todayStart: Date? {
        calendar.date(
            bySettingHour: 6, minute: 0, second: 0,
            of: calendar.startOfDay(for: Date())
        )
    }
    private var todayEnd: Date? {
        calendar.date(
            bySettingHour: 22, minute: 0, second: 0,
            of: calendar.startOfDay(for: Date())
        )
    }

    private var todaysMeals: [(item: FoodLogItem, date: Date)] {
        let today = calendar.startOfDay(for: Date())
        return items.compactMap { item in
            guard let date = parse(dateString: item.datetime),
                calendar.isDate(date, inSameDayAs: today)
            else { return nil }
            return (item, date)
        }
        .sorted { $0.date < $1.date }
    }

    var body: some View {
        graphContent
            .padding(.vertical, 4)
    }

    @ViewBuilder
    private var graphContent: some View {
        switch mode {
        case .day:
            dayView
        case .week:
            weekView
        case .month:
            monthView
        }
    }

    private var dayView: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let axisY = proxy.size.height - 26
                ZStack(alignment: .bottomLeading) {
                    // Baseline
                    Path { path in
                        path.move(to: CGPoint(x: 8, y: axisY))
                        path.addLine(to: CGPoint(x: proxy.size.width - 8, y: axisY))
                    }
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)

                    // Time ticks + labels
                    ForEach(timelineHours, id: \.self) { hour in
                        let x = xPosition(forHour: hour, width: proxy.size.width)
                        VStack(spacing: 4) {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.4))
                                .frame(width: 1, height: 8)
                                .offset(y: -4)
                            Text(timeLabel(for: hour))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .position(x: x, y: axisY + 14)
                    }

                    // Meal markers
                    ForEach(todaysMeals, id: \.item.id) { entry in
                        let x = xPosition(for: entry.date, width: proxy.size.width)
                        let height = barHeight(for: entry.item, availableHeight: axisY - 8)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.accentColor.opacity(0.9))
                            .frame(width: 10, height: height)
                            .position(x: x, y: axisY - height / 2)
                    }
                }
            }
            .frame(height: 140)
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
                        .fill(hasMeal(on: date) ? Color.accentColor : .clear)
                        .overlay(
                            Circle()
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
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

                if hasMeal(on: date) {
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

    private var mealDays: Set<Date> {
        let startOfDayDates = items.compactMap { item -> Date? in
            guard let date = parse(dateString: item.datetime) else { return nil }
            return calendar.startOfDay(for: date)
        }
        return Set(startOfDayDates)
    }

    private func parse(dateString: String) -> Date? {
        isoFormatterWithFractional.date(from: dateString) ?? isoFormatter.date(from: dateString)
    }

    private func hasMeal(on date: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        return mealDays.contains(dayStart)
    }

    private func weekdayLabel(for date: Date) -> String {
        weekdayFormatter.string(from: date)
    }

    private var timelineHours: [Int] { [6, 10, 14, 18, 22] }

    private func timeLabel(for hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        let today = calendar.startOfDay(for: Date())
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today) ?? today
        return formatter.string(from: date).lowercased()
    }

    private func xPosition(forHour hour: Int, width: CGFloat) -> CGFloat {
        guard let start = todayStart, let end = todayEnd else { return 0 }
        let hourDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: start) ?? start
        return xPosition(for: hourDate, width: width)
    }

    private func xPosition(for date: Date, width: CGFloat) -> CGFloat {
        guard let start = todayStart, let end = todayEnd else { return 0 }
        let total = end.timeIntervalSince(start)
        let clamped = min(max(date.timeIntervalSince(start), 0), total)
        let padding: CGFloat = 12
        let usableWidth = max(width - padding * 2, 1)
        return padding + CGFloat(clamped / total) * usableWidth
    }

    private func barHeight(for item: FoodLogItem, availableHeight: CGFloat) -> CGFloat {
        let base: CGFloat = 12
        let intensity = mealIntensity(for: item)
        let usable = max(availableHeight - base, 1)
        return base + CGFloat(intensity) * usable
    }

    private func mealIntensity(for item: FoodLogItem) -> Double {
        if let caloriesString = item.calories,
            let calories = Double(caloriesString)
        {
            return min(max(calories / 800, 0.1), 1.0)
        }
        if let portion = item.portionSize?.lowercased() {
            switch portion {
            case "small": return 0.35
            case "medium": return 0.6
            case "large": return 1.0
            default: break
            }
        }
        return 0.55
    }
}
