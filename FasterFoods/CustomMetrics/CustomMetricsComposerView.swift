import SwiftUI

struct MetricComposer: View {
    @ObservedObject var viewModel: CustomMetricsViewModel
    let quickChips: [CustomMetricsViewModel.QuickChip]
    let onSubmit: () -> Void

    @FocusState private var isNameFocused: Bool
    @State private var hasInteracted = false

    private var shouldShowDetails: Bool {
        hasInteracted
            || isNameFocused
            || !viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Metric name (e.g., Weight)", text: $viewModel.name)
                    .textInputAutocapitalization(.words)
                    .focused($isNameFocused)
                    .onChange(of: isNameFocused) { _, focused in
                        if focused { hasInteracted = true }
                    }
                    .onChange(of: viewModel.name) { _, newValue in
                        if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            hasInteracted = true
                        }
                    }

                QuickMetricChips(quickChips: quickChips) { chip in
                    viewModel.applyQuickChip(chip)
                    hasInteracted = true
                }

                if shouldShowDetails {
                    Group {
                        HStack(spacing: 12) {
                            TextField("Value", text: $viewModel.value)
                                .keyboardType(.decimalPad)
                            TextField("Unit (e.g., lbs)", text: $viewModel.unit)
                        }
                        DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                let canSubmit = viewModel.makeMetric() != nil

                Button {
                    HapticSoundPlayer.shared.playPrimaryTap()
                    onSubmit()
                } label: {
                    Label {
                        Text("Add Metric")
                    } icon: {
                        Image(systemName: "plus")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .animation(.easeInOut(duration: 0.2), value: shouldShowDetails)
    }
}
