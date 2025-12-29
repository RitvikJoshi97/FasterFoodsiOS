import SwiftUI

struct AllAchievementsView: View {
    let achievements: [Achievement]
    let selectedAchievement: Achievement?
    @State private var selectedAchievementState: Achievement?

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
                    ForEach(displayAchievements) { achievement in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedAchievementState = achievement
                            }
                        } label: {
                            AchievementBadgeView(achievement: achievement, itemSize: 76)
                        }
                        .buttonStyle(.plain)
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
    }
}
