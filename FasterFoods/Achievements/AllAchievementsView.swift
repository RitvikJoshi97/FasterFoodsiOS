import SwiftUI

struct AllAchievementsView: View {
    let achievements: [Achievement]
    let selectedAchievement: Achievement?
    @State private var selectedAchievementState: Achievement?
    @State private var showAddGoal = false

    init(
        achievements: [Achievement] = Achievement.sample,
        selectedAchievement: Achievement? = nil
    ) {
        self.achievements = achievements
        self.selectedAchievement = selectedAchievement
        _selectedAchievementState = State(initialValue: selectedAchievement)
    }

    var body: some View {
        let displayAchievements = Achievement.sortedForDisplay(achievements)
        let incompleteAchievements = displayAchievements.filter { !$0.isCompleted }
        let completedAchievements = displayAchievements.filter { $0.isCompleted }
        let completedItemSize: CGFloat = 76
        let incompleteItemSize: CGFloat = 68
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(
                    "Your achievements highlight consistency across meals, workouts, and habits. Keep logging to unlock more milestones tailored to your routine."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                    ],
                    spacing: 16
                ) {
                    ForEach(incompleteAchievements) { achievement in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedAchievementState = achievement
                            }
                        } label: {
                            AchievementBadgeView(
                                achievement: achievement, itemSize: incompleteItemSize)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        showAddGoal = true
                    } label: {
                        AddAchievementBadgeView(itemSize: completedItemSize)
                    }
                    .buttonStyle(.plain)
                }

                if !completedAchievements.isEmpty {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16),
                        ],
                        spacing: 16
                    ) {
                        ForEach(completedAchievements) { achievement in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedAchievementState = achievement
                                }
                            } label: {
                                AchievementBadgeView(
                                    achievement: achievement, itemSize: completedItemSize)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 24)
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $selectedAchievementState) { achievement in
            AchievementDetailView(achievement: achievement)
        }
        .sheet(isPresented: $showAddGoal) {
            NavigationStack {
                AddGoalView { _ in }
            }
        }
    }
}

private struct AddAchievementBadgeView: View {
    let itemSize: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.secondary.opacity(0.15))
                .frame(width: itemSize, height: itemSize)

            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: itemSize * 0.3, weight: .semibold))
                Text("Add")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(Color.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Add achievement")
    }
}
