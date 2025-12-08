import SwiftUI

struct FoodLogSuggestionsView: View {
    let staticSuggestions: [String]
    let aiSuggestions: [ShoppingRecommendation]
    var isLoading: Bool
    var onSelectSuggestion: (String) -> Void
    var onSelectRecommendation: (ShoppingRecommendation) -> Void
    @State private var highlightedSuggestionId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let highlighted = highlightedSuggestion {
                highlightedSuggestionView(for: highlighted)
            } else if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Fetching ideas…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if aiSuggestions.isEmpty {
                Text("Tap refresh to get AI-powered meal ideas.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            otherSuggestionsSection
        }
        .onAppear(perform: updateHighlight)
        .onChange(of: aiSuggestions.map(\.id)) { _ in updateHighlight() }
    }

    private var highlightedSuggestion: ShoppingRecommendation? {
        if let highlightedSuggestionId,
            let match = aiSuggestions.first(where: { $0.id == highlightedSuggestionId })
        {
            return match
        }
        return aiSuggestions.first
    }

    private var remainingAISuggestions: [ShoppingRecommendation] {
        guard let highlightedId = highlightedSuggestion?.id else { return aiSuggestions }
        return aiSuggestions.filter { $0.id != highlightedId }
    }

    private func updateHighlight() {
        if let highlightedSuggestion,
            aiSuggestions.contains(where: { $0.id == highlightedSuggestion.id })
        {
            return
        }
        highlightedSuggestionId = aiSuggestions.first?.id
    }

    private func highlightedSuggestionView(for recommendation: ShoppingRecommendation) -> some View
    {
        VStack(alignment: .leading, spacing: 10) {
            Text("We recommend ")
                .foregroundStyle(.primary)
                + Text(recommendation.title)
                .foregroundStyle(Color.accentColor)
                .fontWeight(.semibold)
                + Text(" today.")
                .foregroundStyle(.primary)

            if !recommendation.description.isEmpty {
                Text(recommendation.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var otherSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Other suggestions")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(remainingAISuggestions) { recommendation in
                        suggestionChip(
                            title: recommendation.title,
                            subtitle: recommendation.description,
                            background: Color.accentColor.opacity(0.14),
                            foreground: Color.accentColor
                        ) {
                            onSelectRecommendation(recommendation)
                        }
                    }

                    ForEach(staticSuggestions, id: \.self) { suggestion in
                        suggestionChip(
                            title: suggestion,
                            background: Color(.systemGray6),
                            foreground: Color.primary
                        ) {
                            onSelectSuggestion(suggestion)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func suggestionChip(
        title: String,
        subtitle: String? = nil,
        background: Color,
        foreground: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(foreground.opacity(0.8))
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: 220, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(background)
            )
        }
        .buttonStyle(.plain)
    }
}
