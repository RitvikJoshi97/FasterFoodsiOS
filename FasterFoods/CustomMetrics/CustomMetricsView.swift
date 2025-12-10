import SwiftUI

struct CustomMetricsView: View {
    @EnvironmentObject private var app: AppState
    @StateObject private var viewModel = CustomMetricsViewModel()
    var embedsInNavigationStack = true

    var body: some View {
        Group {
            if embedsInNavigationStack {
                NavigationStack {
                    content
                }
            } else {
                content
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                MetricComposer(
                    viewModel: viewModel,
                    quickChips: CustomMetricsViewModel.quickChips
                ) {
                    addMetric()
                }

                MetricSummaryCard(stats: viewModel.summary(for: app.customMetrics))

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

    private func addMetric() {
        guard let metric = viewModel.makeMetric() else { return }
        Task {
            do {
                try await app.addCustomMetric(metric)
                await MainActor.run {
                    viewModel.resetComposer()
                }
            } catch {
                // Silently handle errors - user can retry if needed
                print("Error adding custom metric: \(error)")
            }
        }
    }
}
