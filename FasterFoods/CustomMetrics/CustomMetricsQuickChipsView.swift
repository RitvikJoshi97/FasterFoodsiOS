import SwiftUI

struct QuickMetricChips: View {
    let quickChips: [CustomMetricsViewModel.QuickChip]
    let onQuickChip: (CustomMetricsViewModel.QuickChip) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickChips) { quickChip in
                    Button {
                        onQuickChip(quickChip)
                    } label: {
                        Text("\(quickChip.name) (\(quickChip.unit))")
                            .font(.caption)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}
