import SwiftUI

struct FoodLogHistoryView: View {
    let items: [FoodLogItem]
    let mode: FoodLogHistoryGraphMode
    var onDelete: (FoodLogItem) -> Void

    @State private var showAllMonthHistory = false

    private let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let isoFormatter = ISO8601DateFormatter()
    private var calendar: Calendar { Calendar.current }

    @ViewBuilder
    var body: some View {
        Group {
            FoodLogHistoryGraphsView(mode: mode, items: items)
                .listRowSeparator(.hidden)

            if displayedItems.isEmpty {
                Text("No entries yet. Log your first meal above!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(displayedItems) { item in
                    historyRow(for: item)
                }
                if showMoreButtonVisible {
                    Button {
                        showAllMonthHistory = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Show more")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 8)
                }
            }
        }
        .onChange(of: mode) { _, _ in
            showAllMonthHistory = false
        }
    }

    private var sortedItems: [FoodLogItem] {
        items.sorted { first, second in
            let firstDate = parse(dateString: first.datetime)
            let secondDate = parse(dateString: second.datetime)
            switch (firstDate, secondDate) {
            case (let l?, let r?): return l > r
            case (_?, nil): return true
            case (nil, _?): return false
            default: return first.datetime > second.datetime
            }
        }
    }

    private var displayedItems: [FoodLogItem] {
        switch mode {
        case .day:
            return sortedItems.filter(isInToday)
        case .week:
            return sortedItems.filter(isInLastSevenDays)
        case .month:
            if showAllMonthHistory { return sortedItems }
            return sortedItems.filter(isInCurrentMonth)
        }
    }

    private var showMoreButtonVisible: Bool {
        mode == .month && !showAllMonthHistory && displayedItems.count < sortedItems.count
    }

    private func historyRow(for item: FoodLogItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.headline)

                HStack(spacing: 12) {
                    if let date = isoFormatter.date(from: item.datetime) {
                        Text(displayFormatter.string(from: date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(item.meal.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let calories = item.calories, !calories.isEmpty {
                    Text("Calories: \(calories)")
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func parse(dateString: String) -> Date? {
        isoFormatterWithFractional.date(from: dateString) ?? isoFormatter.date(from: dateString)
    }

    private func isInToday(_ item: FoodLogItem) -> Bool {
        guard let date = parse(dateString: item.datetime) else { return false }
        return calendar.isDateInToday(date)
    }

    private func isInLastSevenDays(_ item: FoodLogItem) -> Bool {
        guard let date = parse(dateString: item.datetime) else { return false }
        let end = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -6, to: end) else { return false }
        return (start...end).contains(calendar.startOfDay(for: date))
    }

    private func isInCurrentMonth(_ item: FoodLogItem) -> Bool {
        guard let date = parse(dateString: item.datetime) else { return false }
        let now = Date()
        guard
            let startOfMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now)),
            let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)
        else { return false }

        return date >= startOfMonth && date < startOfNextMonth
    }
}
