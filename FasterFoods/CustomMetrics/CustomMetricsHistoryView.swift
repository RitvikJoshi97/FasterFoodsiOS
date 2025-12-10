import SwiftUI

struct MetricHistorySection: View {
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
        if metrics.isEmpty {
            Section("Your metrics") {
                VStack(spacing: 12) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text("Nothing logged yet")
                        .font(.headline)
                    Text(
                        "Track weight, hydration, energy levels, or any metric that matters to you."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        } else {
            ForEach(groupedMetrics.keys.sorted(), id: \.self) { key in
                if let items = groupedMetrics[key] {
                    MetricTypeGroup(
                        title: key,
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
            let previous =
                items
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

struct MetricTypeGroup: View {
    let title: String
    let entries: [CustomMetric]
    let latestDisplay: String
    let trendDisplay: String
    let deleteAction: (String) -> Void
    let dateFormatter: DateFormatter
    let isoFormatter: ISO8601DateFormatter

    var body: some View {
        Section {
            ForEach(entries) { entry in
                MetricEntryRow(
                    entry: entry,
                    formattedDate: formattedDate(for: entry),
                    onDelete: { deleteAction(entry.id) })
            }
        } header: {
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
        }
    }

    private func formattedDate(for metric: CustomMetric) -> String {
        guard let date = isoFormatter.date(from: metric.date) else { return metric.date }
        return dateFormatter.string(from: date)
    }
}

struct MetricEntryRow: View {
    let entry: CustomMetric
    let formattedDate: String
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.value) \(entry.unit)")
                    .font(.headline)
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
