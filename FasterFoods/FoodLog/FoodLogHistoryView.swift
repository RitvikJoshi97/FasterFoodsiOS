import SwiftUI

struct FoodLogHistoryView: View {
    @EnvironmentObject private var app: AppState
    let items: [FoodLogItem]
    let mode: FoodLogHistoryGraphMode
    var onDelete: (FoodLogItem) -> Void

    @State private var showAllMonthHistory = false
    @State private var expandedItemIds: Set<String> = []
    @State private var ingredientsByItemId: [String: [FoodLogIngredient]] = [:]
    @State private var ingredientErrors: [String: String] = [:]
    @State private var loadingIngredientIds: Set<String> = []

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

                if expandedItemIds.contains(item.id) {
                    ingredientsSection(for: item)
                }
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            toggleIngredients(for: item)
        }
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

    private func toggleIngredients(for item: FoodLogItem) {
        if expandedItemIds.contains(item.id) {
            expandedItemIds.remove(item.id)
            return
        }
        expandedItemIds.insert(item.id)
        if ingredientsByItemId[item.id] != nil { return }
        if loadingIngredientIds.contains(item.id) { return }
        loadingIngredientIds.insert(item.id)
        Task {
            do {
                let ingredients = try await app.getFoodLogItemIngredients(itemId: item.id)
                await MainActor.run {
                    ingredientsByItemId[item.id] = ingredients
                    ingredientErrors[item.id] = nil
                    loadingIngredientIds.remove(item.id)
                }
            } catch {
                await MainActor.run {
                    ingredientErrors[item.id] = error.localizedDescription
                    loadingIngredientIds.remove(item.id)
                }
            }
        }
    }

    @ViewBuilder
    private func ingredientsSection(for item: FoodLogItem) -> some View {
        if loadingIngredientIds.contains(item.id) {
            Text("Loading ingredients...")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let error = ingredientErrors[item.id], !error.isEmpty {
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let ingredients = ingredientsByItemId[item.id] {
            if ingredients.isEmpty {
                Text("No ingredients saved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ingredients")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(ingredients) { ingredient in
                        Text(ingredientLine(ingredient))
                            .font(.caption)
                    }
                }
            }
        }
    }

    private func ingredientLine(_ ingredient: FoodLogIngredient) -> String {
        let name = ingredient.itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let quantity = ingredient.quantity?.trimmingCharacters(in: .whitespacesAndNewlines)
        let unit = ingredient.unit?.trimmingCharacters(in: .whitespacesAndNewlines)
        var detailParts: [String] = []
        if let quantity, !quantity.isEmpty { detailParts.append(quantity) }
        if let unit, !unit.isEmpty { detailParts.append(unit) }
        if detailParts.isEmpty {
            return name.isEmpty ? "Ingredient" : name
        }
        let detail = detailParts.joined(separator: " ")
        return name.isEmpty ? detail : "\(name) · \(detail)"
    }
}
