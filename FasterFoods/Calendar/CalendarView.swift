import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var app: AppState
    @State private var displayedMonth: Date = Date()
    @State private var selectedDate: Date = Date()
    @State private var isWeekFocused = false
    @State private var monthDragOffset: CGFloat = 0
    @State private var weekDragOffset: CGFloat = 0
    @State private var isMonthTransitioning = false
    @State private var isWeekTransitioning = false

    private let calendar = Calendar.current
    private let dragThreshold: CGFloat = 60
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let gridRowSpacing: CGFloat = 18
    private let dayCellMinHeight: CGFloat = 74
    private let dragAnimationDuration: Double = 0.35
    private let headerControlHeight: CGFloat = 40

    private var dragAnimation: Animation {
        .spring(response: 0.35, dampingFraction: 0.8)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    chromeHeader
                    weekdayHeader
                    calendarSection
                    if isWeekFocused {
                        dayAgenda
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 60)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .glassNavigationBarStyle()
    }
}

// MARK: - Header

private extension CalendarView {
    var chromeHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        if isWeekFocused {
                            modeSwitchButton(systemSymbol: "calendar", leadingArrow: true, trailingArrow: false) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isWeekFocused = false
                                }
                            }
                        }

                        Text(displayLabel)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .frame(height: headerControlHeight)
                            .background(.ultraThinMaterial, in: Capsule())

                        if !isWeekFocused {
                            modeSwitchButton(systemSymbol: "square.grid.3x3", leadingArrow: false, trailingArrow: true) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isWeekFocused = true
                                }
                            }
                        }
                    }
                }

                Spacer()

                GlassFloatingButton(title: "Today", action: focusToday)
            }
        }
    }

    var weekdayHeader: some View {
        let symbols = weekdaySymbols
        return HStack {
            ForEach(symbols, id: \.self) { symbol in
                Text(symbol.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    func modeSwitchButton(systemSymbol: String, leadingArrow: Bool, trailingArrow: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if leadingArrow {
                    Image(systemName: "chevron.backward")
                }
                Image(systemName: systemSymbol)
                if trailingArrow {
                    Image(systemName: "chevron.forward")
                }
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(height: headerControlHeight)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Calendar Layouts

private extension CalendarView {
    @ViewBuilder
    var calendarSection: some View {
        if isWeekFocused {
            weekPager
        } else {
            monthPager
        }
    }

    var monthPager: some View {
        let previous = previousMonthDays
        let current = currentMonthDays
        let next = nextMonthDays
        let previousHeight = monthGridHeight(for: previous)
        let currentHeight = monthGridHeight(for: current)
        let nextHeight = monthGridHeight(for: next)
        let tallest = max(previousHeight, max(currentHeight, nextHeight))
        let stackHeight = max(dayCellMinHeight, tallest)

        return ZStack(alignment: .topLeading) {
            calendarGrid(for: previous)
                .offset(y: monthDragOffset - stackHeight)
                .animation(.none, value: displayedMonth)
                .animation(.none, value: monthDragOffset)

            calendarGrid(for: current)
                .offset(y: monthDragOffset)
                .animation(.none, value: displayedMonth)
                .animation(.none, value: monthDragOffset)

            calendarGrid(for: next)
                .offset(y: monthDragOffset + stackHeight)
                .animation(.none, value: displayedMonth)
                .animation(.none, value: monthDragOffset)
        }
        .frame(height: stackHeight)
        .clipped()
        .contentShape(Rectangle())
        .gesture(monthDragGesture(viewHeight: stackHeight))
    }

    var weekPager: some View {
        let previous = previousWeekDays
        let current = currentWeekDays
        let next = nextWeekDays

        return GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                calendarGrid(for: previous)
                    .offset(x: weekDragOffset - width)

                calendarGrid(for: current)
                    .offset(x: weekDragOffset)

                calendarGrid(for: next)
                    .offset(x: weekDragOffset + width)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .clipped()
            .contentShape(Rectangle())
            .gesture(weekDragGesture(viewWidth: width))
        }
        .frame(height: dayCellMinHeight)
    }

    func calendarGrid(for days: [CalendarDay]) -> some View {
        LazyVGrid(columns: columns, spacing: gridRowSpacing) {
            ForEach(days) { day in
                calendarDayView(day)
            }
        }
        .animation(.none, value: days)
    }

    func monthDragGesture(viewHeight: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isMonthTransitioning, viewHeight > 0 else { return }
                let vertical = value.translation.height
                let horizontal = value.translation.width
                guard abs(vertical) >= abs(horizontal) else {
                    monthDragOffset = 0
                    return
                }
                let clamped = min(max(vertical, -viewHeight), viewHeight)
                monthDragOffset = clamped
            }
            .onEnded { value in
                guard !isMonthTransitioning else { return }
                handleMonthDragEnd(value: value, viewHeight: viewHeight)
            }
    }

    func weekDragGesture(viewWidth: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isWeekTransitioning, viewWidth > 0 else { return }
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) >= abs(vertical) else {
                    weekDragOffset = 0
                    return
                }
                let clamped = min(max(horizontal, -viewWidth), viewWidth)
                weekDragOffset = clamped
            }
            .onEnded { value in
                guard !isWeekTransitioning else { return }
                handleWeekDragEnd(value: value, viewWidth: viewWidth)
            }
    }

    func calendarDayView(_ day: CalendarDay) -> some View {
        VStack(spacing: 6) {
            Text(dayLabel(for: day.date))
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(dayBackground(for: day))
                )
                .foregroundStyle(dayForeground(for: day))

            if day.hasEntries {
                Capsule()
                    .fill(Color.accentColor.opacity(calendar.isDate(day.date, inSameDayAs: selectedDate) ? 0.9 : 0.35))
                    .frame(width: 26, height: 4)
            } else {
                Spacer().frame(height: 4)
            }
        }
        .frame(maxWidth: .infinity, minHeight: dayCellMinHeight)
        .opacity(day.isWithinDisplayedMonth || isWeekFocused ? 1 : 0.35)
        .contentShape(Rectangle())
        .onTapGesture {
            select(date: day.date)
        }
    }
}

// MARK: - Agenda & Timeline

private extension CalendarView {
    var dayAgenda: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedDateHeading)
                .font(.title3.bold())

            GlassCard {
                if entriesForSelectedDate.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No logs for this day")
                            .font(.headline)
                        Text("Select a date to see workouts, meals, and custom metrics exactly like the Calendar app.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 12) {
                        ForEach(entriesForSelectedDate) { entry in
                            CalendarEventRow(entry: entry)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Helpers

private extension CalendarView {
    var currentMonthDays: [CalendarDay] {
        calendarDays(for: displayedMonth)
    }

    var previousMonthDays: [CalendarDay] {
        guard let previous = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else { return [] }
        return calendarDays(for: previous)
    }

    var nextMonthDays: [CalendarDay] {
        guard let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return [] }
        return calendarDays(for: next)
    }

    var currentWeekDays: [CalendarDay] {
        weekDays(for: selectedDate)
    }

    var previousWeekDays: [CalendarDay] {
        guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) else { return [] }
        return weekDays(for: previous)
    }

    var nextWeekDays: [CalendarDay] {
        guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) else { return [] }
        return weekDays(for: next)
    }

    func calendarDays(for month: Date) -> [CalendarDay] {
        guard
            let monthRange = calendar.range(of: .day, in: .month, for: month),
            let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }

        var days: [CalendarDay] = []
        let entryLookup = entriesByDay

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingSpaces = (firstWeekday - calendar.firstWeekday + 7) % 7

        if leadingSpaces > 0,
           let previousMonth = calendar.date(byAdding: .month, value: -1, to: firstOfMonth),
           let previousRange = calendar.range(of: .day, in: .month, for: previousMonth),
           let startDay = previousRange.last.map({ $0 - leadingSpaces + 1 }) {
            for day in startDay...previousRange.last! {
                if let date = calendar.date(bySetting: .day, value: day, of: previousMonth) {
                    let hasEntry = entryLookup[calendar.startOfDay(for: date)] != nil
                    days.append(CalendarDay(date: date, isWithinDisplayedMonth: false, hasEntries: hasEntry))
                }
            }
        }

        for day in monthRange {
            if let date = calendar.date(bySetting: .day, value: day, of: firstOfMonth) {
                let hasEntry = entryLookup[calendar.startOfDay(for: date)] != nil
                days.append(CalendarDay(date: date, isWithinDisplayedMonth: true, hasEntries: hasEntry))
            }
        }

        let remainder = days.count % 7
        if remainder != 0,
           let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstOfMonth) {
            for dayOffset in 0..<(7 - remainder) {
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: nextMonth) {
                    let hasEntry = entryLookup[calendar.startOfDay(for: date)] != nil
                    days.append(CalendarDay(date: date, isWithinDisplayedMonth: false, hasEntries: hasEntry))
                }
            }
        }

        return days
    }

    func weekDates(for date: Date) -> [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    func weekDays(for date: Date) -> [CalendarDay] {
        let lookup = entriesByDay
        return weekDates(for: date).map { day in
            CalendarDay(
                date: day,
                isWithinDisplayedMonth: calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month),
                hasEntries: lookup[calendar.startOfDay(for: day)] != nil
            )
        }
    }

    func monthGridHeight(for days: [CalendarDay]) -> CGFloat {
        let rowCount = max(1, days.count / 7)
        let spacingTotal = max(0, rowCount - 1)
        return CGFloat(rowCount) * dayCellMinHeight + CGFloat(spacingTotal) * gridRowSpacing
    }

    func handleMonthDragEnd(value: DragGesture.Value, viewHeight: CGFloat) {
        let vertical = value.translation.height
        let horizontal = value.translation.width
        guard abs(vertical) >= abs(horizontal) else {
            resetMonthDragOffset(animated: true)
            return
        }

        if vertical < -dragThreshold {
            completeMonthTransition(shift: 1, viewHeight: viewHeight)
        } else if vertical > dragThreshold {
            completeMonthTransition(shift: -1, viewHeight: viewHeight)
        } else {
            resetMonthDragOffset(animated: true)
        }
    }

    func handleWeekDragEnd(value: DragGesture.Value, viewWidth: CGFloat) {
        let horizontal = value.translation.width
        let vertical = value.translation.height
        guard abs(horizontal) >= abs(vertical) else {
            resetWeekDragOffset(animated: true)
            return
        }

        if horizontal < -dragThreshold {
            completeWeekTransition(shift: 1, viewWidth: viewWidth)
        } else if horizontal > dragThreshold {
            completeWeekTransition(shift: -1, viewWidth: viewWidth)
        } else {
            resetWeekDragOffset(animated: true)
        }
    }

    func completeMonthTransition(shift: Int, viewHeight: CGFloat) {
        guard shift != 0 else { return }
        isMonthTransitioning = true
        let targetOffset: CGFloat = shift > 0 ? -viewHeight : viewHeight
        withAnimation(dragAnimation) {
            monthDragOffset = targetOffset
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + dragAnimationDuration) {
            shiftMonth(by: shift)
            withAnimation(.none) {
                monthDragOffset = 0
            }
            isMonthTransitioning = false
        }
    }

    func completeWeekTransition(shift: Int, viewWidth: CGFloat) {
        guard shift != 0 else { return }
        isWeekTransitioning = true
        let targetOffset: CGFloat = shift > 0 ? -viewWidth : viewWidth
        withAnimation(dragAnimation) {
            weekDragOffset = targetOffset
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + dragAnimationDuration) {
            shiftWeek(by: shift)
            withAnimation(.none) {
                weekDragOffset = 0
            }
            isWeekTransitioning = false
        }
    }

    func resetMonthDragOffset(animated: Bool) {
        let action = {
            monthDragOffset = 0
        }

        if animated {
            withAnimation(dragAnimation) {
                action()
            }
        } else {
            withAnimation(.none) {
                action()
            }
        }
    }

    func resetWeekDragOffset(animated: Bool) {
        let action = {
            weekDragOffset = 0
        }

        if animated {
            withAnimation(dragAnimation) {
                action()
            }
        } else {
            withAnimation(.none) {
                action()
            }
        }
    }

    func select(date: Date) {
        selectedDate = date
        if !calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month) {
            displayedMonth = date
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isWeekFocused = true
        }
    }

    func shiftMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = newMonth
        if !calendar.isDate(selectedDate, equalTo: newMonth, toGranularity: .month) {
            selectedDate = calendar.startOfDay(for: newMonth)
            isWeekFocused = false
        }
    }

    func focusToday() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            displayedMonth = Date()
            selectedDate = Date()
            isWeekFocused = false
        }
    }

    func shiftWeek(by value: Int) {
        guard let newDate = calendar.date(byAdding: .weekOfYear, value: value, to: selectedDate) else { return }
        selectedDate = newDate
        displayedMonth = newDate
        isWeekFocused = true
    }

    func goToPreviousPeriod() {
        if isWeekFocused {
            shiftWeek(by: -1)
        } else {
            shiftMonth(by: -1)
        }
    }

    func goToNextPeriod() {
        if isWeekFocused {
            shiftWeek(by: 1)
        } else {
            shiftMonth(by: 1)
        }
    }

    func dayBackground(for day: CalendarDay) -> Color {
        if calendar.isDate(day.date, inSameDayAs: selectedDate) {
            return Color.accentColor
        }
        if calendar.isDateInToday(day.date) {
            return Color.accentColor.opacity(0.15)
        }
        return Color(.secondarySystemGroupedBackground)
    }

    func dayForeground(for day: CalendarDay) -> Color {
        if calendar.isDate(day.date, inSameDayAs: selectedDate) {
            return .white
        }
        return .primary
    }

    func dayLabel(for date: Date) -> String {
        "\(calendar.component(.day, from: date))"
    }

    var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        var symbols = formatter.shortStandaloneWeekdaySymbols
        ?? formatter.shortWeekdaySymbols
        ?? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        let startIndex = calendar.firstWeekday - 1
        if startIndex > 0 {
            let prefix = symbols[startIndex...]
            let suffix = symbols[..<startIndex]
            symbols = Array(prefix + suffix)
        }
        return symbols
    }

    var entriesForSelectedDate: [CalendarEntry] {
        entriesByDay[calendar.startOfDay(for: selectedDate)] ?? []
    }

    var entriesByDay: [Date: [CalendarEntry]] {
        var grouped: [Date: [CalendarEntry]] = [:]
        let entries = allEntries
        for entry in entries {
            let key = calendar.startOfDay(for: entry.occurrenceDate)
            grouped[key, default: []].append(entry)
        }

        for key in grouped.keys {
            grouped[key]?.sort(by: { lhs, rhs in
                switch (lhs.startTime, rhs.startTime) {
                case let (l?, r?): return l < r
                case (_?, nil): return true
                case (nil, _?): return false
                default: return lhs.title < rhs.title
                }
            })
        }

        return grouped
    }

    var allEntries: [CalendarEntry] {
        let workouts = app.workoutItems.compactMap { item -> CalendarEntry? in
            guard let date = parse(dateString: item.datetime) else { return nil }
            let durationText = "\(item.duration) min"
            let caloriesText = item.calories.flatMap { "\($0) cal" }
            let subtitle = [durationText, caloriesText].compactMap { $0 }.joined(separator: " • ")
            return CalendarEntry(
                id: "workout-\(item.id)",
                title: item.name,
                subtitle: subtitle,
                type: .workout,
                startTime: date,
                occurrenceDate: date
            )
        }

        let foodLogs = app.foodLogItems.compactMap { item -> CalendarEntry? in
            guard let date = parse(dateString: item.datetime) else { return nil }
            var details: [String] = []
            details.append(item.meal)
            if let calories = item.calories, !calories.isEmpty {
                details.append("\(calories) cal")
            }
            if let mood = item.mood, !mood.isEmpty {
                details.append(mood)
            }
            return CalendarEntry(
                id: "food-\(item.id)",
                title: item.name,
                subtitle: details.joined(separator: " • "),
                type: .food,
                startTime: date,
                occurrenceDate: date
            )
        }

        let metrics = app.customMetrics.compactMap { metric -> CalendarEntry? in
            guard let date = parse(dateString: metric.date) else { return nil }
            let subtitle = "\(metric.value) \(metric.unit)"
            return CalendarEntry(
                id: "metric-\(metric.id)",
                title: metric.name,
                subtitle: subtitle,
                type: .metric,
                startTime: date,
                occurrenceDate: date
            )
        }

        return workouts + foodLogs + metrics
    }

    func parse(dateString: String) -> Date? {
        CalendarView.isoFormatterWithFractional.date(from: dateString)
        ?? CalendarView.isoFormatter.date(from: dateString)
    }

    var selectedDateHeading: String {
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(selectedDate) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday"
        }
        return longDateFormatter.string(from: selectedDate)
    }

    var displayedMonthLabel: String {
        monthFormatter.string(from: displayedMonth)
    }

    var yearLabel: String {
        yearFormatter.string(from: displayedMonth)
    }

    var monthYearDisplay: String {
        "\(displayedMonthLabel) \(yearLabel)"
    }

    var weekRangeDisplay: String {
        guard
            let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDate)
        else { return monthYearDisplay }
        let start = weekRangeFormatter.string(from: interval.start)
        let end = weekRangeFormatter.string(from: calendar.date(byAdding: .day, value: 6, to: interval.start) ?? interval.end)
        return "\(start) - \(end)"
    }

    var displayLabel: String {
        isWeekFocused ? weekRangeDisplay : monthYearDisplay
    }

}

// MARK: - Supporting Views

private struct CalendarDay: Identifiable, Equatable {
    let date: Date
    let isWithinDisplayedMonth: Bool
    let hasEntries: Bool

    var id: Date { date }
}

private struct CalendarEntry: Identifiable {
    enum EntryType {
        case workout
        case food
        case metric

        var color: Color {
            switch self {
            case .workout: return .pink
            case .food: return .orange
            case .metric: return .blue
            }
        }

        var iconName: String {
            switch self {
            case .workout: return "figure.run"
            case .food: return "fork.knife"
            case .metric: return "chart.bar"
            }
        }

        var label: String {
            switch self {
            case .workout: return "Workout"
            case .food: return "Meal"
            case .metric: return "Metric"
            }
        }
    }

    let id: String
    let title: String
    let subtitle: String
    let type: EntryType
    let startTime: Date?
    let occurrenceDate: Date
}

private struct CalendarEventRow: View {
    let entry: CalendarEntry

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: entry.type.iconName)
                .font(.title3)
                .foregroundStyle(entry.type.color)
                .frame(width: 36, height: 36)
                .background(entry.type.color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                if !entry.subtitle.isEmpty {
                    Text(entry.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(timeText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(entry.type.color.opacity(0.12))
        )
    }

    private var timeText: String {
        guard let date = entry.startTime else { return "All day" }
        return CalendarView.timeFormatter.string(from: date)
    }
}

private struct GlassIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.callout.weight(.bold))
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct IconBubble: View {
    let systemName: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.callout.weight(.semibold))
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.25))
        )
    }
}

private struct GlassFloatingButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Formatters

private extension CalendarView {
    static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        return formatter
    }

    var yearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }

    var longDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }

    var weekRangeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }
}
