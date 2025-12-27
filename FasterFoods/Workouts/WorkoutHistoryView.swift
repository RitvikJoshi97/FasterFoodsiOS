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
                    iconSystemName: workoutSystemImageName(for: item),
                    categoryLabel: label(for: item),
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
        return item.parameters
            .sorted { $0.key < $1.key }
            .compactMap { key, value in
                // Hide internal metadata from HealthKit imports
                if ["HealthKit UUID", "Activity Type", "Source", "Device"].contains(key) {
                    return nil
                }
                return "\(key): \(value.stringValue)"
            }
            .joined(separator: " • ")
    }

    private func label(for item: WorkoutLogItem) -> String {
        if item.category == WorkoutActivityDefinition.Constants.healthKitImport {
            // Show the underlying Health workout type instead of the generic import category name.
            return item.name
        }
        return
            activities
            .first(where: { $0.id == item.activity })?
            .categories
            .first(where: { $0.id == item.category })?
            .name ?? item.category
    }

    private func parse(dateString: String) -> Date? {
        return isoFormatterWithFractional.date(from: dateString)
            ?? isoFormatter.date(from: dateString)
    }

    private func workoutSystemImageName(for item: WorkoutLogItem) -> String {
        switch item.activity {
        case WorkoutActivityDefinition.Constants.cardio:
            switch item.category {
            case "outdoor-run", "trail-run", "track-run":
                return "figure.run"
            case "indoor-run":
                return "treadmill"
            case "walking":
                return "figure.walk"
            case "hiking":
                return "figure.hiking"
            default:
                return "figure.run"
            }
        case WorkoutActivityDefinition.Constants.cycling:
            return "bicycle"
        case WorkoutActivityDefinition.Constants.gymStrength:
            switch item.category {
            case "flexibility":
                return "figure.flexibility"
            case "hiit":
                return "figure.highintensity.intervaltraining"
            default:
                return "dumbbell"
            }
        case WorkoutActivityDefinition.Constants.mindBody:
            switch item.category {
            case "yoga":
                return "figure.yoga"
            case "tai-chi", "mindful-cooldown":
                return "figure.mind.and.body"
            case "pilates":
                return "figure.pilates"
            default:
                return "figure.mind.and.body"
            }
        case WorkoutActivityDefinition.Constants.waterSports:
            switch item.category {
            case "pool-swim", "open-water-swim":
                return "figure.pool.swim"
            case "rowing":
                return "figure.rowing"
            case "surfing":
                return "figure.surfing"
            case "paddleboarding":
                return "figure.stand.paddle"
            case "kayaking":
                return "figure.kayaking"
            default:
                return "drop"
            }
        case WorkoutActivityDefinition.Constants.winterSports:
            switch item.category {
            case "snowboarding":
                return "figure.snowboarding"
            case "skiing", "cross-country-skiing":
                return "figure.skiing.downhill"
            default:
                return "snowflake"
            }
        case WorkoutActivityDefinition.Constants.combatMixed:
            switch item.category {
            case "boxing", "kickboxing":
                return "figure.boxing"
            case "martial-arts":
                return "figure.martial.arts"
            case "dance-cardio":
                return "figure.dance"
            default:
                return "figure.martial.arts"
            }
        case WorkoutActivityDefinition.Constants.teamField:
            switch item.category {
            case "football":
                return "figure.american.football"
            case "basketball":
                return "figure.basketball"
            case "volleyball":
                return "figure.volleyball"
            case "hockey":
                return "figure.hockey"
            case "cricket":
                return "figure.cricket"
            case "rugby":
                return "figure.rugby"
            default:
                return "figure.team.sports"
            }
        case WorkoutActivityDefinition.Constants.racketPrecision:
            switch item.category {
            case "tennis":
                return "figure.tennis"
            case "badminton":
                return "figure.badminton"
            case "table-tennis":
                return "figure.table.tennis"
            case "golf":
                return "figure.golf"
            case "pickleball":
                return "figure.pickleball"
            default:
                return "figure.racket.sports"
            }
        case WorkoutActivityDefinition.Constants.others:
            switch item.category {
            case "climbing":
                return "figure.climbing"
            case "dance":
                return "figure.dance"
            case "fitness-gaming":
                return "gamecontroller"
            case WorkoutActivityDefinition.Constants.healthKitImport:
                return "heart"
            default:
                return "figure.walk"
            }
        default:
            return "figure.walk"
        }
    }
}

private struct WorkoutHistoryRow: View {
    let item: WorkoutLogItem
    let iconSystemName: String
    let categoryLabel: String
    let dateText: String
    let parameterSummary: String
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconSystemName)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 36, height: 36)
                .padding(6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.secondary)
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
                            .labelStyle(.titleAndIcon)
                            .symbolVariant(.fill)
                            .imageScale(.small)
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
