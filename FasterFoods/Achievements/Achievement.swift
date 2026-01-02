import SwiftUI

struct Achievement: Identifiable, Hashable {
    let id = UUID()
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
    static let sample: [Achievement] = [
        Achievement(
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
