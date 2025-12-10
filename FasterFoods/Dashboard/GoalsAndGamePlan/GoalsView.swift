import Foundation
import SwiftUI

struct GoalsView<GamePlanContentView: View, ExpandedGamePlanContentView: View>: View {
    let gamePlanView: (@escaping () -> Void) -> GamePlanContentView
    let expandedGamePlanView: () -> ExpandedGamePlanContentView
    let hasGamePlanContent: Bool

    @State private var savedGoals: [Goal] = []
    @State private var isLoading = true
    @State private var showAddGoal = false
    @State private var showExpandedGamePlan = false
    @State private var isGoalsExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Goals and Game Plan", systemImage: "flag.checkered")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Tell us your goals and let us help curate a game plan.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    goalsList
                    if hasGamePlanContent {
                        gamePlanView { showExpandedGamePlan = true }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showAddGoal) {
            NavigationStack {
                AddGoalView { goal in
                    savedGoals.insert(goal, at: 0)
                }
            }
        }
        .sheet(isPresented: $showExpandedGamePlan) {
            expandedGamePlanView()
        }
        .task {
            await loadGoals()
        }
    }

    @ViewBuilder
    private var goalsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(.secondary)
                Text("Your active goals")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button {
                    showAddGoal = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel("Add goal")
                }
            }

            if savedGoals.isEmpty {
                Text("No active goals yet. Tap below to add one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isGoalsExpanded.toggle()
                    }
                } label: {
                    let preview = Array(savedGoals.prefix(3))
                    Group {
                        if isGoalsExpanded {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.secondary.opacity(0.08))
                                .frame(height: 16)
                                .opacity(0)
                        } else {
                            ZStack(alignment: .leading) {
                                ForEach(Array(preview.enumerated()), id: \.element.id) {
                                    index, goal in
                                    goalCard(for: goal)
                                        .offset(y: CGFloat(index) * 10)
                                        .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 6)
                                        .opacity(1)
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.trailing, 12)
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                    }
                }
                .buttonStyle(.plain)

                Text(isGoalsExpanded ? "Hide goals" : "Tap to view all \(savedGoals.count) goals")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isGoalsExpanded.toggle()
                        }
                    }

                if isGoalsExpanded {
                    VStack(spacing: 12) {
                        ForEach(savedGoals) { goal in
                            goalCard(for: goal)
                        }
                    }
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .offset(y: -12))
                        )
                    )
                }
            }
        }
    }

    @MainActor
    private func loadGoals() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let goals = try await APIClient.shared.getGoals()
            savedGoals = goals
            if goals.isEmpty {
                showAddGoal = true
            }
            isGoalsExpanded = false
        } catch {
            savedGoals = []
            showAddGoal = true
        }
    }

    private func formatDate(_ dateString: String) -> String {
        guard let date = parseGoalDate(dateString) else { return dateString }

        if Calendar.current.isDateInToday(date) {
            return "Today at \(GoalsDateFormatters.timeFormatter.string(from: date))"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Yesterday at \(GoalsDateFormatters.timeFormatter.string(from: date))"
        }

        return GoalsDateFormatters.fullDateFormatter.string(from: date)
    }

    private func parseGoalDate(_ dateString: String) -> Date? {
        if let date = GoalsDateFormatters.isoFormatterWithFractional.date(from: dateString) {
            return date
        }
        return GoalsDateFormatters.isoFormatter.date(from: dateString)
    }

    @ViewBuilder
    private func goalCard(for goal: Goal) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.description)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                if let createdAt = goal.createdAt {
                    Text("Added \(formatDate(createdAt))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

private enum GoalsDateFormatters {
    static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}
