import SwiftUI

struct WorkoutHistoryList: View {
    let items: [WorkoutLogItem]
    let activities: [WorkoutActivityDefinition]
    let onDelete: (String) -> Void

    @State private var graphMode: WorkoutHistoryGraphMode = .week

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

    private let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM"
        return formatter
    }()

    var body: some View {
        Section {
            WorkoutHistoryGraphsView(mode: graphMode, items: items)

            ForEach(sortedItems) { item in
                WorkoutHistoryRow(
                    item: item,
                    categoryLabel: label(forCategory: item.category, activityID: item.activity),
                    dateText: formattedDate(for: item),
                    parameterSummary: parameterSummary(for: item)
                ) {
                    onDelete(item.id)
                }
            }
        } header: {
            HStack {
                Text("Workout History")
                    .font(.headline)
                Spacer()
                Picker("Range", selection: $graphMode) {
                    ForEach(WorkoutHistoryGraphMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
                .labelsHidden()
            }
            .padding(.bottom, 4)
        }
    }

    private var sortedItems: [WorkoutLogItem] {
        items.sorted { $0.datetime > $1.datetime }
    }

    private func formattedDate(for item: WorkoutLogItem) -> String {
        guard let date = parse(dateString: item.datetime) else { return item.datetime }
        return displayFormatter.string(from: date)
    }

    private func parameterSummary(for item: WorkoutLogItem) -> String {
        item.parameters
            .sorted { $0.key < $1.key }
            .map { key, value in "\(key): \(value.stringValue)" }
            .joined(separator: " • ")
    }

    private func label(forCategory id: String, activityID: String) -> String {
        activities
            .first(where: { $0.id == activityID })?
            .categories
            .first(where: { $0.id == id })?
            .name ?? id
    }

    private func parse(dateString: String) -> Date? {
        isoFormatterWithFractional.date(from: dateString) ?? isoFormatter.date(from: dateString)
    }
}

private struct WorkoutHistoryRow: View {
    let item: WorkoutLogItem
    let categoryLabel: String
    let dateText: String
    let parameterSummary: String
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(categoryLabel)
                    .font(.headline)
                if !parameterSummary.isEmpty {
                    Text(parameterSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Text("\(Int(Double(item.duration) ?? 0)) min")
                        .font(.caption)
                    if let caloriesStr = item.calories, let calories = Double(caloriesStr) {
                        Label("\(Int(calories)) kcal", systemImage: "flame")
                            .font(.caption)
                    }
                    Text(dateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
