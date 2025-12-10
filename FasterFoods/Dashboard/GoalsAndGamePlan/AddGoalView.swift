import SwiftUI

struct AddGoalView: View {
    let onGoalSaved: (Goal) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var toastService: ToastService
    @State private var goalDescription = ""
    @State private var recommendations: [GoalRecommendation] = []
    @State private var selectedRecommendation: GoalRecommendation?
    @State private var isLoadingRecommendations = true
    @State private var isSubmitting = false
    @FocusState private var isGoalFieldFocused: Bool

    private var isFormValid: Bool {
        !goalDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                recommendationsSection
                goalEditor
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .navigationTitle("Add Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: saveGoal) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(!isFormValid)
            }
        }
        .task {
            await loadRecommendationsIfNeeded()
            // Focus the editor shortly after sheet appears to show the keyboard.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isGoalFieldFocused = true
            }
        }
    }

    @ViewBuilder
    private var goalEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tell us about your goals")
                .font(.subheadline)
                .fontWeight(.medium)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $goalDescription)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(colorScheme == .dark ? Color.black : Color.white)
                    .cornerRadius(10)
                    .focused($isGoalFieldFocused)
                    .onChange(of: goalDescription) { oldValue, newValue in
                        if let selected = selectedRecommendation {
                            let selectedText = selected.title ?? selected.description
                            if newValue != selectedText && newValue != selected.description {
                                selectedRecommendation = nil
                            }
                        }
                    }

                if goalDescription.isEmpty {
                    Text("Describe your goal in detail...")
                        .foregroundStyle(.secondary.opacity(0.5))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }

            Text("We'll keep this goal pinned to your dashboard so you can stay accountable.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Popular community goals")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(colorScheme == .dark ? .white : .primary)
                Spacer()
                if isLoadingRecommendations {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if isLoadingRecommendations {
                Text("Loading inspiration from the community...")
                    .font(.caption)
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.7) : .secondary)
            } else if recommendations.isEmpty {
                Text("No suggested goals yet. Check back soon!")
                    .font(.caption)
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.7) : .secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(recommendations) { recommendation in
                            Button(action: {
                                let text = recommendation.description
                                goalDescription = text
                                selectedRecommendation = recommendation
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(recommendation.title ?? recommendation.description)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Spacer(minLength: 0)
                                    if let count = recommendation.usageCount {
                                        Text("\(count) keeping this")
                                            .font(.caption2)
                                            .foregroundStyle(
                                                colorScheme == .dark
                                                    ? .white.opacity(0.7) : .secondary
                                            )
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .frame(minHeight: 88, alignment: .topLeading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(width: 200, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(
                                            (selectedRecommendation?.id == recommendation.id)
                                                ? Color.green.opacity(0.28)
                                                : Color.green.opacity(0.12)
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.green.opacity(0.25), lineWidth: 1)
                                )
                                .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
        }
    }

    @MainActor
    private func loadRecommendationsIfNeeded() async {
        guard recommendations.isEmpty, isLoadingRecommendations else { return }
        defer { isLoadingRecommendations = false }

        do {
            let recs = try await APIClient.shared.getGoalRecommendations()
            recommendations = recs
        } catch {
            recommendations = []
        }
    }

    private func saveGoal() {
        guard isFormValid else { return }

        isSubmitting = true

        Task {
            do {
                let trimmedDescription = goalDescription.trimmingCharacters(
                    in: .whitespacesAndNewlines)
                let title = selectedRecommendation?.title
                let source =
                    selectedRecommendation != nil ? "dashboard-recommendation" : "dashboard-manual"

                let newGoal = try await APIClient.shared.createGoal(
                    title: title,
                    description: trimmedDescription,
                    source: source
                )

                await MainActor.run {
                    onGoalSaved(newGoal)
                    isSubmitting = false
                    toastService.show("Goal saved")
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    toastService.show("Could not save goal. Please try again.", style: .error)
                }
            }
        }
    }
}
