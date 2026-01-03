import SwiftUI
import UIKit

struct ShareAchievementView: View {
    let achievement: Achievement
    let background: ShareAchievementBackground
    let size: CGSize

    init(
        achievement: Achievement,
        background: ShareAchievementBackground,
        size: CGSize = CGSize(width: 360, height: 520)
    ) {
        self.achievement = achievement
        self.background = background
        self.size = size
    }

    var body: some View {
        let badgeSize = min(size.width, size.height) * 0.32
        let titleFontSize = max(20, size.width * 0.06)
        let detailFontSize = max(14, size.width * 0.04)
        let watermarkSize = max(12, size.width * 0.03)
        let paddingSize = max(20, size.width * 0.08)

        VStack(spacing: 16) {
            AchievementBadgeView(achievement: achievement, itemSize: badgeSize)

            VStack(spacing: 6) {
                Text(achievement.title)
                    .font(.system(size: titleFontSize, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text(achievement.detail)
                    .font(.system(size: detailFontSize))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 10)

            VStack(spacing: 6) {
                if let iconImage {
                    Image(uiImage: iconImage)
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: watermarkSize * 2.2, height: watermarkSize * 2.2)
                }

                Text("FasterFoods")
                    .font(.system(size: watermarkSize, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
        .padding(paddingSize)
        .frame(width: size.width, height: size.height, alignment: .center)
        .background(backgroundView)
        .environment(\.colorScheme, background == .dark ? .dark : .light)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch background {
        case .light:
            Color.white
        case .dark:
            Color.black
        case .colored:
            LinearGradient(
                colors: achievement.gradientColors.map { $0.opacity(0.35) } + [
                    Color.black.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var iconName: String {
        background == .dark ? "dark_icon" : "light_icon"
    }

    private var iconImage: UIImage? {
        if let image = UIImage(named: iconName) {
            return image
        }
        if let url = Bundle.main.url(
            forResource: iconName,
            withExtension: "png",
            subdirectory: "Images"
        ),
            let image = UIImage(contentsOfFile: url.path)
        {
            return image
        }
        return nil
    }
}

enum ShareAchievementBackground: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    case colored = "Colored"

    var id: String { rawValue }
}
