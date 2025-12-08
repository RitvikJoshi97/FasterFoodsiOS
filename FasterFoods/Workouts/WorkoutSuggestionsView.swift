import SwiftUI

struct WorkoutSuggestionsCard: View {
    @ObservedObject var viewModel: WorkoutsViewModel
    let recommendations: [ShoppingRecommendation]
    let isLoadingRecommendations: Bool
    let onRefreshRecommendations: () -> Void
    let onDismissRecommendation: (String) -> Void
    let onAddWorkout: () -> Void
    @State private var highlightedSuggestion: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            recommendationHeadline
                .font(.body)

            WorkoutSuggestionsSection(
                viewModel: viewModel,
                recommendations: recommendations,
                isLoadingRecommendations: isLoadingRecommendations,
                onRefreshRecommendations: onRefreshRecommendations,
                onDismissRecommendation: onDismissRecommendation,
                onAddWorkout: onAddWorkout,
                highlightedSuggestion: highlightedSuggestion
            )

            HStack(spacing: 12) {
                Button(action: applyHighlightedSuggestion) {
                    Text(highlightedButtonTitle)
                        .font(.subheadline)
                        .lineLimit(1)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(highlightedSuggestion.isEmpty)

                Button(action: onAddWorkout) {
                    Label("Log Workout", systemImage: "plus")
                        .font(.subheadline)
                        .lineLimit(1)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
        }
        .padding(.vertical, 4)
        .onAppear(perform: updateHighlight)
        .onChange(of: viewModel.quickPicks.map(\.id)) { _ in updateHighlight() }
        .onChange(of: recommendations.map(\.id)) { _ in updateHighlight() }
    }

    private var recommendationHeadline: Text {
        guard !highlightedSuggestion.isEmpty else {
            return Text("Log a workout to keep your momentum going.")
                .foregroundStyle(.secondary)
        }
        return Text("We recommend ")
            + Text(highlightedSuggestion)
            .foregroundStyle(Color.accentColor)
            .fontWeight(.semibold)
            + Text(" today. It should give you a nice boost of energy.")
            .foregroundStyle(.primary)
    }

    private var highlightedButtonTitle: String {
        highlightedSuggestion.isEmpty ? "Suggested Workout" : "\(highlightedSuggestion)"
    }

    private func updateHighlight() {
        let titles = suggestionTitles
        guard !titles.isEmpty else {
            highlightedSuggestion = ""
            return
        }
        if !titles.contains(highlightedSuggestion) {
            highlightedSuggestion = titles.randomElement() ?? ""
        }
    }

    private var suggestionTitles: [String] {
        let quickPickTitles = viewModel.quickPicks.map(\.label)
        let recommendationTitles = recommendations.compactMap { recommendation in
            recommendation.quickPickDefinition?.label ?? recommendation.title
        }
        return quickPickTitles + recommendationTitles
    }

    private func applyHighlightedSuggestion() {
        guard !highlightedSuggestion.isEmpty else { return }
        if let pick = viewModel.quickPicks.first(where: { $0.label == highlightedSuggestion }) {
            viewModel.applyQuickPick(pick)
            onAddWorkout()
            return
        }

        if let rec = recommendations.first(where: { $0.title == highlightedSuggestion }),
            let quickPick = rec.quickPickDefinition
        {
            viewModel.applyQuickPick(quickPick)
            onAddWorkout()
        }
    }
}

private struct WorkoutSuggestionsSection: View {
    @ObservedObject var viewModel: WorkoutsViewModel
    let recommendations: [ShoppingRecommendation]
    let isLoadingRecommendations: Bool
    let onRefreshRecommendations: () -> Void
    let onDismissRecommendation: (String) -> Void
    let onAddWorkout: () -> Void
    let highlightedSuggestion: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Other suggestions")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.quickPicks) { pick in
                        suggestionChip(
                            title: pick.label,
                            backgroundColor: Color(.systemGray6),
                            isHighlighted: highlightedSuggestion == pick.label
                        ) {
                            viewModel.applyQuickPick(pick)
                            onAddWorkout()
                        }
                    }

                    ForEach(recommendations) { rec in
                        let label = rec.quickPickDefinition?.label ?? rec.title
                        suggestionChip(
                            title: label,
                            backgroundColor: Color.accentColor.opacity(0.12),
                            showDismiss: true,
                            dismissAction: { onDismissRecommendation(rec.id) },
                            isHighlighted: highlightedSuggestion == label
                        ) {
                            if let quickPick = rec.quickPickDefinition {
                                viewModel.applyQuickPick(quickPick)
                                onAddWorkout()
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }

            // if recommendations.isEmpty && !isLoadingRecommendations {
            //     Text("No AI suggestions yet. Tap refresh to fetch new ideas!")
            //         .font(.footnote)
            //         .foregroundStyle(.secondary)
            // }
        }
    }

    private func suggestionChip(
        title: String,
        subtitle: String? = nil,
        backgroundColor: Color,
        showDismiss: Bool = false,
        dismissAction: (() -> Void)? = nil,
        isHighlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isHighlighted ? .primary : Color.secondary)
                    Spacer(minLength: 4)
                    if showDismiss, let dismissAction {
                        Button(action: dismissAction) {
                            Image(systemName: "xmark.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isHighlighted ? Color.primary.opacity(0.75) : .secondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: 220, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(.plain)
    }
}

extension ShoppingRecommendation {
    fileprivate var quickPickDefinition: WorkoutQuickPickDefinition? {
        guard let metadata else { return nil }
        let activity =
            metadata["activityID"] ?? metadata["activity_id"]
            ?? WorkoutActivityDefinition.Constants.cardio
        let category =
            metadata["categoryID"] ?? metadata["category_id"]
            ?? WorkoutActivityDefinition.Constants.cardio
        let duration =
            metadata["duration"] ?? metadata["durationMinutes"] ?? metadata["duration_minutes"]
        let calories = metadata["calories"]
        let filteredParameters = metadata.filter { key, _ in
            ![
                "activityID", "activity_id", "categoryID", "category_id", "duration",
                "durationMinutes",
                "duration_minutes", "calories",
            ].contains(key)
        }

        return WorkoutQuickPickDefinition(
            label: title,
            activityID: activity,
            categoryID: category,
            duration: duration,
            calories: calories,
            parameterPrefill: filteredParameters
        )
    }
}
