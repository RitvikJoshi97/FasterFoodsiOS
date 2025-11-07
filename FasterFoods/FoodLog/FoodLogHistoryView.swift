import SwiftUI

struct FoodLogHistoryView: View {
    let items: [FoodLogItem]
    var onDelete: (FoodLogItem) -> Void

    private let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private let isoFormatter = ISO8601DateFormatter()

    var body: some View {
        if items.isEmpty {
            Text("No entries yet. Log your first meal above!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
        } else {
            ForEach(items) { item in
                historyRow(for: item)
            }
        }
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
                    Text(item.loggingLevel.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let calories = item.calories, !calories.isEmpty {
                    Text("Calories: \(calories)")
                        .font(.caption)
                }
            }
            Spacer()
            Button(role: .destructive) {
                onDelete(item)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }
}
