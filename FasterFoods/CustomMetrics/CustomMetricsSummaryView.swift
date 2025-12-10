import SwiftUI

struct MetricSummaryCard: View {
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

struct MetricSummaryTile: View {
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
