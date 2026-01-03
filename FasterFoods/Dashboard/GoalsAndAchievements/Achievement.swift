import SwiftUI

struct Achievement: Identifiable, Hashable {
    let id: String
    let goalId: String?
    let title: String
    let symbolName: String
    let gradientColors: [Color]
    let detail: String
    let percentage: Double
    let startDate: Date
    let targetDate: Date
    let completedDate: Date?
}

extension Achievement {
    init(record: AchievementRecord) {
        let basis = record.goalId ?? record.id
        let style = AchievementStyle.style(for: basis, title: record.title)
        let createdAt = AchievementStyle.parseDate(from: record.createdAt)
        let achievedAt = AchievementStyle.parseDate(from: record.achievedAt)
        let targetDate = achievedAt ?? createdAt ?? Date()
        self.init(
            id: record.id,
            goalId: record.goalId,
            title: record.title,
            symbolName: style.symbolName,
            gradientColors: style.gradientColors,
            detail: record.description,
            percentage: record.percentageCompleted ?? 0,
            startDate: createdAt ?? Date(),
            targetDate: targetDate,
            completedDate: achievedAt
        )
    }

    init(goal: Goal) {
        let basis = goal.id.isEmpty ? (goal.title ?? goal.description) : goal.id
        let style = AchievementStyle.style(for: basis, title: goal.title ?? goal.description)
        let createdAt = AchievementStyle.parseDate(from: goal.createdAt)
        let targetDate = AchievementStyle.parseDate(from: goal.targetDate) ?? createdAt ?? Date()
        let percentage = goal.percentageCompleted ?? 0
        let isCompleted = goal.status?.lowercased() == "completed" || percentage >= 100
        let completedDate =
            isCompleted
            ? AchievementStyle.parseDate(from: goal.updatedAt)
                ?? AchievementStyle.parseDate(from: goal.targetDate)
            : nil
        self.init(
            id: goal.id,
            goalId: goal.id,
            title: goal.title ?? goal.description,
            symbolName: style.symbolName,
            gradientColors: style.gradientColors,
            detail: goal.description,
            percentage: percentage,
            startDate: createdAt ?? Date(),
            targetDate: targetDate,
            completedDate: completedDate
        )
    }

    static let sample: [Achievement] = [
        Achievement(
            id: "sample-workouts",
            goalId: nil,
            title: "Log 3 Workouts a Week",
            symbolName: "figure.run",
            gradientColors: [Color.indigo, Color.blue],
            detail: "You logged three workouts this week! Great going!",
            percentage: 100,
            startDate: makeDate(2025, 12, 20),
            targetDate: makeDate(2025, 12, 29),
            completedDate: makeDate(2025, 12, 29)
        ),
        Achievement(
            id: "sample-5k",
            goalId: nil,
            title: "5K Club",
            symbolName: "figure.run",
            gradientColors: [Color.orange, Color.yellow],
            detail: "Logged 5 kilometers of movement.",
            percentage: 72,
            startDate: makeDate(2025, 12, 1),
            targetDate: makeDate(2026, 1, 10),
            completedDate: nil
        ),
        Achievement(
            id: "sample-focus-lens",
            goalId: nil,
            title: "Focus Lens",
            symbolName: "camera.aperture",
            gradientColors: [Color.blue, Color.teal],
            detail: "Completed a focused tracking streak.",
            percentage: 48,
            startDate: makeDate(2025, 12, 12),
            targetDate: makeDate(2026, 1, 5),
            completedDate: nil
        ),
        Achievement(
            id: "sample-fresh-fuel",
            goalId: nil,
            title: "Fresh Fuel",
            symbolName: "leaf.fill",
            gradientColors: [Color.green, Color.mint],
            detail: "Hit your veggie target for the week.",
            percentage: 90,
            startDate: makeDate(2025, 12, 18),
            targetDate: makeDate(2026, 1, 2),
            completedDate: nil
        ),
        Achievement(
            id: "sample-proud-finish",
            goalId: nil,
            title: "Proud Finish",
            symbolName: "flag.checkered",
            gradientColors: [Color.pink, Color.red],
            detail: "Closed out a perfect week of logs.",
            percentage: 100,
            startDate: makeDate(2025, 12, 8),
            targetDate: makeDate(2025, 12, 22),
            completedDate: makeDate(2025, 12, 22)
        ),
        Achievement(
            id: "sample-balanced-day",
            goalId: nil,
            title: "Balanced Day",
            symbolName: "sun.max.fill",
            gradientColors: [Color.cyan, Color.blue],
            detail: "Balanced your macros for the day.",
            percentage: 100,
            startDate: makeDate(2025, 12, 26),
            targetDate: makeDate(2025, 12, 27),
            completedDate: makeDate(2025, 12, 27)
        ),
        Achievement(
            id: "sample-goal-star",
            goalId: nil,
            title: "Goal Star",
            symbolName: "star.fill",
            gradientColors: [Color.yellow, Color.orange],
            detail: "Completed a personal goal.",
            percentage: 32,
            startDate: makeDate(2025, 12, 28),
            targetDate: makeDate(2026, 1, 18),
            completedDate: nil
        ),
    ]

    var isCompleted: Bool {
        percentage >= 100 || completedDate != nil
    }

    static func sortedForDisplay(_ achievements: [Achievement]) -> [Achievement] {
        achievements.sorted { lhs, rhs in
            let lhsCompleted = lhs.isCompleted
            let rhsCompleted = rhs.isCompleted

            if lhsCompleted != rhsCompleted {
                return lhsCompleted == false
            }

            if lhsCompleted {
                let lhsDate = lhs.completedDate ?? lhs.targetDate
                let rhsDate = rhs.completedDate ?? rhs.targetDate
                return lhsDate > rhsDate
            }

            return lhs.targetDate < rhs.targetDate
        }
    }

    private static func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }
}

private enum AchievementStyle {
    static let symbolNames = [
        "figure.run",
        "leaf.fill",
        "sun.max.fill",
        "flame.fill",
        "star.fill",
        "flag.checkered",
        "heart.fill",
        "bolt.fill",
        "camera.aperture",
        "sparkles",
    ]

    static let gradientSets: [[Color]] = [
        [Color.indigo, Color.blue],
        [Color.orange, Color.yellow],
        [Color.green, Color.mint],
        [Color.pink, Color.red],
        [Color.cyan, Color.blue],
        [Color.purple, Color.indigo],
        [Color.teal, Color.green],
        [Color.yellow, Color.orange],
        [Color.blue, Color.teal],
        [Color.red, Color.orange],
    ]

    static func style(for id: String, title: String) -> (
        symbolName: String, gradientColors: [Color]
    ) {
        let base = id.isEmpty ? title : id
        let symbolIndex = stableIndex(for: base, modulo: symbolNames.count)
        let gradientIndex = stableIndex(for: "\(base)-gradient", modulo: gradientSets.count)
        return (symbolNames[symbolIndex], gradientSets[gradientIndex])
    }

    static func parseDate(from isoString: String?) -> Date? {
        guard let isoString, !isoString.isEmpty else { return nil }
        if let date = isoFormatterWithFractional.date(from: isoString) {
            return date
        }
        return isoFormatter.date(from: isoString)
    }

    private static func stableIndex(for value: String, modulo: Int) -> Int {
        guard modulo > 0 else { return 0 }
        var hash = 0
        for scalar in value.unicodeScalars {
            hash = (hash &* 31) &+ Int(scalar.value)
        }
        return abs(hash) % modulo
    }

    private static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
