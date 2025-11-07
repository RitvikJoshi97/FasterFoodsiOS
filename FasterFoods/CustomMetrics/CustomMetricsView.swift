import SwiftUI

struct CustomMetricsView: View {
    @EnvironmentObject private var app: AppState
    @StateObject private var viewModel = CustomMetricsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    MetricSummaryCard(stats: viewModel.summary(for: app.customMetrics))

                    MetricComposer(viewModel: viewModel) {
                        addMetric()
                    }

                    MetricSuggestions(suggestions: CustomMetricsViewModel.suggestions) { suggestion in
                        viewModel.applySuggestion(suggestion)
                    }

                    MetricHistorySection(metrics: app.customMetrics) { id in
                        Task {
                            try? await app.deleteCustomMetric(id: id)
                        }
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Custom metrics")
        }
    }

    private func addMetric() {
        guard let metric = viewModel.makeMetric() else { return }
        Task {
            try? await app.addCustomMetric(metric)
            await MainActor.run {
                viewModel.resetComposer()
            }
        }
    }
}

// MARK: - View Model

final class CustomMetricsViewModel: ObservableObject {
    struct Suggestion: Identifiable {
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

    static let suggestions: [Suggestion] = [
        Suggestion(name: "Weight", unit: "lbs"),
        Suggestion(name: "Water Intake", unit: "oz"),
        Suggestion(name: "Sleep Hours", unit: "hours"),
        Suggestion(name: "Steps", unit: "steps"),
        Suggestion(name: "Resting Heart Rate", unit: "bpm"),
        Suggestion(name: "Blood Pressure", unit: "mmHg"),
        Suggestion(name: "Mood", unit: "1-10"),
        Suggestion(name: "Energy Level", unit: "1-10")
    ]

    func applySuggestion(_ suggestion: Suggestion) {
        name = suggestion.name
        if unit.isEmpty {
            unit = suggestion.unit
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

// MARK: - Summary

private struct MetricSummaryCard: View {
    let stats: CustomMetricSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("At a glance")
                .font(.headline)
            HStack(spacing: 16) {
                MetricSummaryTile(
                    title: "Logged metrics",
                    value: "\(stats.totalMetrics)",
                    subtitle: "\(stats.metricsThisWeek) this week"
                )
                MetricSummaryTile(
                    title: "Unique types",
                    value: "\(stats.uniqueTypes)",
                    subtitle: stats.mostTrackedMetric
                )
                MetricSummaryTile(
                    title: "Latest entry",
                    value: stats.mostRecentValue,
                    subtitle: stats.mostRecentDate
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

private struct MetricSummaryTile: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Composer

private struct MetricComposer: View {
    @ObservedObject var viewModel: CustomMetricsViewModel
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Log a metric")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                TextField("Metric name (e.g., Weight)", text: $viewModel.name)
                    .textInputAutocapitalization(.words)
                HStack(spacing: 12) {
                    TextField("Value", text: $viewModel.value)
                        .keyboardType(.decimalPad)
                    TextField("Unit (e.g., lbs)", text: $viewModel.unit)
                }
                DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )

            Button(action: onSubmit) {
                Label("Add metric", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.makeMetric() == nil)
        }
    }
}

private struct MetricSuggestions: View {
    let suggestions: [CustomMetricsViewModel.Suggestion]
    let onSuggestion: (CustomMetricsViewModel.Suggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Popular metrics")
                .font(.headline)
            FlexibleChips(suggestions: suggestions, onSuggestion: onSuggestion)
        }
    }
}

private struct FlexibleChips: View {
    let suggestions: [CustomMetricsViewModel.Suggestion]
    let onSuggestion: (CustomMetricsViewModel.Suggestion) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(suggestions) { suggestion in
                Button {
                    onSuggestion(suggestion)
                } label: {
                    Text("\(suggestion.name) (\(suggestion.unit))")
                        .font(.caption)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - History

private struct MetricHistorySection: View {
    let metrics: [CustomMetric]
    let onDelete: (String) -> Void

    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your metrics")
                .font(.headline)

            if metrics.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text("Nothing logged yet")
                        .font(.headline)
                    Text("Track weight, hydration, energy levels, or any metric that matters to you.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(28)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            } else {
                ForEach(groupedMetrics.keys.sorted(), id: \.self) { key in
                    if let items = groupedMetrics[key] {
                        MetricTypeGroup(title: key,
                                        entries: items.sorted { $0.date > $1.date },
                                        latestDisplay: latestBadge(for: items),
                                        trendDisplay: trendBadge(for: items),
                                        deleteAction: onDelete,
                                        dateFormatter: displayFormatter,
                                        isoFormatter: isoFormatter)
                    }
                }
            }
        }
    }

    private var groupedMetrics: [String: [CustomMetric]] {
        Dictionary(grouping: metrics, by: { $0.metricType })
    }

    private func latestBadge(for items: [CustomMetric]) -> String {
        guard let latest = items.max(by: { $0.date < $1.date }) else { return "" }
        return "\(latest.value) \(latest.unit)"
    }

    private func trendBadge(for items: [CustomMetric]) -> String {
        guard
            items.count > 1,
            let latest = items.max(by: { $0.date < $1.date }),
            let previous = items
                .filter({ $0.id != latest.id })
                .max(by: { $0.date < $1.date }),
            let latestValue = Double(latest.value),
            let previousValue = Double(previous.value)
        else {
            return ""
        }

        let delta = latestValue - previousValue
        guard delta != 0 else { return "" }
        let sign = delta > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", delta)) \(latest.unit)"
    }
}

private struct MetricTypeGroup: View {
    let title: String
    let entries: [CustomMetric]
    let latestDisplay: String
    let trendDisplay: String
    let deleteAction: (String) -> Void
    let dateFormatter: DateFormatter
    let isoFormatter: ISO8601DateFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                if !latestDisplay.isEmpty {
                    Label(latestDisplay, systemImage: "sparkles")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }
                if !trendDisplay.isEmpty {
                    Label(trendDisplay, systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                }
            }

            ForEach(entries) { entry in
                MetricEntryRow(entry: entry,
                               formattedDate: formattedDate(for: entry),
                               onDelete: { deleteAction(entry.id) })
            }
        }
    }

    private func formattedDate(for metric: CustomMetric) -> String {
        guard let date = isoFormatter.date(from: metric.date) else { return metric.date }
        return dateFormatter.string(from: date)
    }
}

private struct MetricEntryRow: View {
    let entry: CustomMetric
    let formattedDate: String
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.value) \(entry.unit)")
                    .font(.headline)
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Helpers

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

        metricsThisWeek = metrics.filter { metric in
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
           let date = isoFormatter.date(from: latest.date) {
            mostRecentValue = "\(latest.value) \(latest.unit)"
            mostRecentDate = displayFormatter.string(from: date)
        } else {
            mostRecentValue = "—"
            mostRecentDate = "Log your first entry"
        }
    }
}
