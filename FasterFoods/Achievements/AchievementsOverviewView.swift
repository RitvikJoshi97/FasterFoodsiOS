import SwiftUI
import UIKit

struct AchievementsOverviewView: View {
    let achievements: [Achievement]
    let itemSize: CGFloat
    let onSelect: ((Achievement) -> Void)?
    let onViewAll: (() -> Void)?
    let maxVisible: Int?
    @State private var selectedAchievement: Achievement?

    init(
        achievements: [Achievement],
        itemSize: CGFloat = 72,
        initialSelection: Achievement? = nil,
        onSelect: ((Achievement) -> Void)? = nil,
        onViewAll: (() -> Void)? = nil,
        maxVisible: Int? = nil
    ) {
        self.achievements = achievements
        self.itemSize = itemSize
        self.onSelect = onSelect
        self.onViewAll = onViewAll
        self.maxVisible = maxVisible
        _selectedAchievement = State(initialValue: initialSelection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if onSelect == nil, let selected = selectedAchievement {
                VStack(alignment: .leading, spacing: 12) {
                    AchievementBadgeView(
                        achievement: selected,
                        itemSize: itemSize + 6
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(selected.title)
                            .font(.headline)
                        Text(selected.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button("Show all goals and achievements") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedAchievement = nil
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                }
            } else {
                let visibleAchievements =
                    maxVisible == nil
                    ? achievements
                    : Array(achievements.prefix(maxVisible ?? achievements.count))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(visibleAchievements) { achievement in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if let onSelect {
                                        onSelect(achievement)
                                    } else {
                                        selectedAchievement = achievement
                                    }
                                }
                            } label: {
                                AchievementBadgeView(
                                    achievement: achievement,
                                    itemSize: itemSize
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        if let onViewAll {
                            Button {
                                onViewAll()
                            } label: {
                                ViewAllBadgeView(itemSize: itemSize)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.leading, 4)
                    .padding(.trailing, 8)
                }
            }
        }
    }
}

private struct ViewAllBadgeView: View {
    let itemSize: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.secondary.opacity(0.15))
                .frame(width: itemSize, height: itemSize)
                .overlay(
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )

            VStack(spacing: 4) {
                Image(systemName: "ellipsis")
                    .font(.system(size: itemSize * 0.3, weight: .semibold))
                Text("View All")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(Color.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("View all goals and achievements")
    }
}

struct AchievementBadgeView: View {
    let achievement: Achievement
    let itemSize: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let displayColors = adjustedColors(for: colorScheme)
        ZStack {
            if !achievement.isCompleted {
                Circle()
                    .stroke(Color.primary.opacity(0.12), lineWidth: 6)
                    .frame(width: itemSize + 8, height: itemSize + 8)

                Circle()
                    .trim(from: 0, to: min(max(achievement.percentage / 100, 0), 1))
                    .stroke(
                        LinearGradient(
                            colors: displayColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: itemSize + 8, height: itemSize + 8)
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: displayColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: itemSize, height: itemSize)
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.08 : 0.16),
                            Color.white.opacity(0.0),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: itemSize, height: itemSize)
                .blendMode(.screen)

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.25 : 0.35),
                            Color.white.opacity(0.05),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .frame(width: itemSize, height: itemSize)

            Image(systemName: achievement.symbolName)
                .font(.system(size: itemSize * 0.36, weight: .semibold))
                .foregroundStyle(.white)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(achievement.title)
    }

    private func adjustedColors(for scheme: ColorScheme) -> [Color] {
        let saturation: CGFloat = scheme == .dark ? 0.55 : 0.65
        let brightness: CGFloat = scheme == .dark ? 0.75 : 0.95
        return achievement.gradientColors.map {
            $0.adjusted(saturation: saturation, brightness: brightness)
        }
    }
}

extension Color {
    fileprivate func adjusted(saturation: CGFloat, brightness: CGFloat) -> Color {
        let uiColor = UIColor(self)
        var hue: CGFloat = 0
        var currentSaturation: CGFloat = 0
        var currentBrightness: CGFloat = 0
        var alpha: CGFloat = 0

        guard
            uiColor.getHue(
                &hue, saturation: &currentSaturation, brightness: &currentBrightness, alpha: &alpha)
        else {
            return self.opacity(0.9)
        }

        let newSaturation = min(currentSaturation * saturation, 1)
        let newBrightness = min(max(currentBrightness * brightness, 0), 1)
        return Color(
            UIColor(hue: hue, saturation: newSaturation, brightness: newBrightness, alpha: alpha))
    }
}
