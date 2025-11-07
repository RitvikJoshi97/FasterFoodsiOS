import SwiftUI

struct FoodLogSuggestionsView: View {
    let staticSuggestions: [String]
    let aiSuggestions: [ShoppingRecommendation]
    var isLoading: Bool
    var onRefresh: () -> Void
    var onSelectSuggestion: (String) -> Void
    var onSelectRecommendation: (ShoppingRecommendation) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Suggestions")
                    .font(.headline)
                Spacer()
                Button(action: onRefresh) {
                    if isLoading {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.plain)
            }

            ChipFlow(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(staticSuggestions, id: \.self) { suggestion in
                    Button {
                        onSelectSuggestion(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }

                ForEach(aiSuggestions) { recommendation in
                    Button {
                        onSelectRecommendation(recommendation)
                    } label: {
                        Text(recommendation.title)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(Color.accentColor)
                            .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
