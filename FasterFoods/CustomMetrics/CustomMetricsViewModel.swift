import SwiftUI

final class CustomMetricsViewModel: ObservableObject {
    struct QuickChip: Identifiable {
        let id = UUID()
        let name: String
        let unit: String
    }

    @Published var name: String = ""
    @Published var value: String = ""
    @Published var unit: String = ""
    @Published var date: Date = Date()

    private let isoFormatter: ISO8601DateFormatter

    init() {
        isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    static let quickChips: [QuickChip] = [
        QuickChip(name: "Weight", unit: "lbs"),
        QuickChip(name: "Water Intake", unit: "oz"),
        QuickChip(name: "Sleep Hours", unit: "hours"),
        QuickChip(name: "Steps", unit: "steps"),
        QuickChip(name: "Resting Heart Rate", unit: "bpm"),
        QuickChip(name: "Blood Pressure", unit: "mmHg"),
        QuickChip(name: "Mood", unit: "1-10"),
        QuickChip(name: "Energy Level", unit: "1-10"),
    ]

    func applyQuickChip(_ chip: QuickChip) {
        name = chip.name
        if unit.isEmpty {
            unit = chip.unit
        }
    }

    func summary(for metrics: [CustomMetric]) -> CustomMetricSummary {
        CustomMetricSummary(metrics: metrics)
    }

    func makeMetric() -> CustomMetric? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, !trimmedValue.isEmpty else { return nil }

        let metricUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let metric = CustomMetric(
            name: trimmedName,
            value: trimmedValue,
            unit: metricUnit.isEmpty ? "unit" : metricUnit,
            date: isoFormatter.string(from: date),
            metricType: trimmedName
        )
        return metric
    }

    func resetComposer() {
        // keep name to encourage repeat tracking
        value = ""
        unit = ""
        date = Date()
    }
}

struct CustomMetricSummary {
    let totalMetrics: Int
    let uniqueTypes: Int
    let metricsThisWeek: Int
    let mostTrackedMetric: String
    let mostRecentValue: String
    let mostRecentDate: String

    init(metrics: [CustomMetric]) {
        totalMetrics = metrics.count
        uniqueTypes = Set(metrics.map { $0.metricType }).count

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium

        let calendar = Calendar.current
        let now = Date()

        metricsThisWeek =
            metrics.filter { metric in
                guard let date = isoFormatter.date(from: metric.date) else { return false }
                return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
            }.count

        let counted = metrics.reduce(into: [String: Int]()) { partial, metric in
            partial[metric.metricType, default: 0] += 1
        }
        if let mostFrequent = counted.max(by: { $0.value < $1.value })?.key {
            mostTrackedMetric = mostFrequent
        } else {
            mostTrackedMetric = uniqueTypes > 0 ? "Exploring" : "Get started"
        }

        if let latest = metrics.max(by: { $0.date < $1.date }),
            let date = isoFormatter.date(from: latest.date)
        {
            mostRecentValue = "\(latest.value) \(latest.unit)"
            mostRecentDate = displayFormatter.string(from: date)
        } else {
            mostRecentValue = "—"
            mostRecentDate = "Log your first entry"
        }
    }
}
