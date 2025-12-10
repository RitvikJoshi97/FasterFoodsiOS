import SwiftUI

struct CustomMetricsView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var toastService: ToastService
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
        List {
            Section {
                MetricComposer(
                    viewModel: viewModel,
                    quickChips: CustomMetricsViewModel.quickChips
                ) {
                    addMetric()
                }
                .listRowInsets(EdgeInsets())
            }

            Section {
                MetricSummaryCard(stats: viewModel.summary(for: app.customMetrics))
            }

            MetricHistorySection(metrics: app.customMetrics) { id in
                Task {
                    await deleteMetric(id: id)
                }
            }
        }
        .listStyle(.insetGrouped)
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
                    toastService.show("Custom metric added")
                }
            } catch {
                await MainActor.run {
                    toastService.show("Could not add metric.", style: .error)
                }
            }
        }
    }

    @MainActor
    private func deleteMetric(id: String) async {
        do {
            try await app.deleteCustomMetric(id: id)
            toastService.show("Deleted")
        } catch {
            toastService.show("Deleted", style: .error)
        }
    }
}
