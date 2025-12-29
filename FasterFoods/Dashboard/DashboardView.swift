//
//  DashboardView.swift
//  FasterFoods
//
//  Created by Ritvik Joshi on 11/04/25.
//

import Foundation
import SwiftUI
import UIKit

enum TodaysProgressDestination: Identifiable, Hashable {
    case workouts
    case foodLog
    case customMetrics

    var id: String {
        switch self {
        case .workouts: return "workouts"
        case .foodLog: return "foodLog"
        case .customMetrics: return "customMetrics"
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject private var toastService: ToastService
    @Environment(\.colorScheme) private var colorScheme
    @State private var todaysProgressDestination: TodaysProgressDestination?
    @State private var isHeaderCompact = false
    @State private var selectedAchievement: Achievement?
    @State private var showAllAchievements = false

    private let workoutGoalMinutes: Double = 45
    private let macroTargets = MacroTargets(calories: 2000, carbs: 240, protein: 120, fat: 70)
    private let featuredArticles = ArticleLoader.featured(limit: 4)

    private var greeting: String {
        if let user = app.currentUser {
            return "Welcome back, \(user.firstName) \(user.lastName)"
        }
        return "Welcome to FasterFoods"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Color.clear
                        .frame(height: 0)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: DashboardScrollOffsetPreferenceKey.self,
                                    value: proxy.frame(in: .named("dashboardScroll")).minY
                                )
                            }
                        )

                    Text(greeting)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Today's Progress", systemImage: "chart.bar.doc.horizontal")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        TodaysProgressStack(
                            workoutSummary: workoutSummary,
                            foodSummary: foodLogSummary,
                            onWorkoutTap: { todaysProgressDestination = .workouts },
                            onFoodLogTap: { todaysProgressDestination = .foodLog },
                            onSleepTap: { todaysProgressDestination = .customMetrics }
                        )
                        .padding(.vertical, 4)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Suggested Reads", systemImage: "book.closed")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        SuggestedReadsSection(articles: featuredArticles)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Goals and Achievements", systemImage: "flag.checkered")
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }

                        GoalsView(showHeader: false)

                        AchievementsOverviewView(
                            achievements: achievementsForDisplay,
                            onSelect: { achievement in
                                selectedAchievement = achievement
                            },
                            onViewAll: {
                                showAllAchievements = true
                            },
                            maxVisible: 4
                        )
                    }

                    GamePlanSectionView()
                }
                .padding(.horizontal)
                .padding(.vertical, 24)
                .padding(.bottom, 36)
            }
            .coordinateSpace(name: "dashboardScroll")
            .onPreferenceChange(DashboardScrollOffsetPreferenceKey.self) { offset in
                withAnimation(.easeInOut(duration: 0.25)) {
                    isHeaderCompact = offset < -20
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        if let icon = currentIconImage {
                            Image(uiImage: icon)
                                .resizable()
                                .renderingMode(.original)
                                .scaledToFit()
                                .frame(
                                    width: isHeaderCompact ? 24 : 32,
                                    height: isHeaderCompact ? 24 : 32
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        Text("FasterFoods")
                            .font(.system(size: isHeaderCompact ? 18 : 20, weight: .semibold))
                    }
                    .accessibilityLabel("FasterFoods Home")
                }
            }
            .navigationDestination(item: $todaysProgressDestination) { destination in
                switch destination {
                case .workouts:
                    WorkoutsView(embedsInNavigationStack: false)
                case .foodLog:
                    FoodLogView(embedsInNavigationStack: false)
                case .customMetrics:
                    CustomMetricsView(embedsInNavigationStack: false)
                }
            }
            .navigationDestination(item: $selectedAchievement) { achievement in
                AllAchievementsView(
                    achievements: achievementsForDisplay,
                    selectedAchievement: achievement
                )
            }
            .navigationDestination(isPresented: $showAllAchievements) {
                AllAchievementsView(achievements: achievementsForDisplay)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView()
                            .environmentObject(app)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: isHeaderCompact ? 18 : 24, weight: .semibold))
                            .frame(
                                width: isHeaderCompact ? 36 : 44,
                                height: isHeaderCompact ? 36 : 44
                            )
                            .contentShape(Rectangle())
                            .accessibilityLabel("Settings")
                    }
                }
            }
        }
        .glassNavigationBarStyle()
        .task {
            ensureHighlightedWorkoutSuggestion()
            await app.refreshLatestGamePlan()
        }
        .onChange(of: app.workoutRecommendations.map(\.id)) { _, _ in
            ensureHighlightedWorkoutSuggestion()
        }
        .onChange(of: app.gamePlanUpdateNotice) { _, newValue in
            guard newValue else { return }
            toastService.show("Game Plan has been updated")
            app.consumeGamePlanUpdateNotice()
        }
    }
}

extension DashboardView {
    fileprivate var currentIconImage: UIImage? {
        if let image = UIImage(named: currentIconName) {
            return image
        }
        if let image = UIImage(named: currentIconName + ".png") {
            return image
        }
        if let url = Bundle.main.url(
            forResource: currentIconName,
            withExtension: "png",
            subdirectory: "Images"
        ),
            let image = UIImage(contentsOfFile: url.path)
        {
            return image
        }
        if let url = Bundle.main.url(
            forResource: currentIconName + ".png",
            withExtension: nil,
            subdirectory: "Images"
        ),
            let image = UIImage(contentsOfFile: url.path)
        {
            return image
        }
        return nil
    }

    fileprivate var currentIconName: String {
        colorScheme == .dark ? "dark_icon" : "light_icon"
    }

    fileprivate var workoutSummary: WorkoutSummary {
        let todayItems = app.workoutItems.filter { isToday($0.datetime) }
        let totalMinutes = todayItems.reduce(0) { partialResult, item in
            partialResult + parseDurationMinutes(from: item.duration)
        }
        let progress = workoutGoalMinutes > 0 ? min(totalMinutes / workoutGoalMinutes, 1) : 0

        let state: WorkoutState
        if todayItems.isEmpty || totalMinutes <= 0 {
            state = .notStarted
        } else if totalMinutes >= workoutGoalMinutes {
            state = .completed
        } else {
            state = .partiallyCompleted
        }

        let remainingMinutes = max(workoutGoalMinutes - totalMinutes, 0)
        let remainingText = formatMinutesText(remainingMinutes, roundUp: true)
        let doneText = formatMinutesText(totalMinutes, roundUp: false)

        let workoutRecommendation = app.highlightedWorkoutSuggestion.trimmingCharacters(
            in: .whitespacesAndNewlines)
        let workoutRecommendationIcon =
            workoutRecommendation.isEmpty
            ? ""
            : WorkoutSuggestionIconProvider.systemImageName(
                for: workoutRecommendation,
                quickPicks: WorkoutQuickPickDefinition.defaultQuickPicks,
                recommendations: app.workoutRecommendations
            )

        return WorkoutSummary(
            remainingText: remainingText,
            doneText: doneText,
            recommendationHighlight: workoutRecommendation,
            recommendationIconName: workoutRecommendationIcon,
            progress: progress,
            state: state
        )
    }

    fileprivate var achievementsForDisplay: [Achievement] {
        Achievement.sortedForDisplay(Achievement.sample)
    }

    fileprivate var foodLogSummary: FoodLogSummary {
        let todayItems = app.foodLogItems.filter { isToday($0.datetime) }
        let totalCalories = todayItems.reduce(0.0) { $0 + parseDouble($1.calories) }
        let protein = todayItems.reduce(0.0) { $0 + parseDouble($1.protein) }
        let fat = todayItems.reduce(0.0) { $0 + parseDouble($1.fat) }
        let carbohydrates = todayItems.reduce(0.0) { total, item in
            let explicitCarbs = parseDouble(item.carbohydrates)
            if explicitCarbs > 0 {
                return total + explicitCarbs
            }
            let itemCalories = parseDouble(item.calories)
            let itemProtein = parseDouble(item.protein)
            let itemFat = parseDouble(item.fat)
            let carbCalories = max(itemCalories - (itemProtein * 4 + itemFat * 9), 0)
            return total + (carbCalories / 4)
        }
        let calorieGoal = max(macroTargets.calories, 0)
        let caloriesRemaining = max(calorieGoal - totalCalories, 0)
        let caloriesProgress = calorieGoal > 0 ? min(totalCalories / calorieGoal, 1) : 0

        let macros: [MacroRingData] = [
            MacroRingData(
                label: "Carbs", consumed: carbohydrates, target: macroTargets.carbs, color: .orange),
            MacroRingData(
                label: "Protein", consumed: protein, target: macroTargets.protein, color: .purple),
            MacroRingData(label: "Fat", consumed: fat, target: macroTargets.fat, color: .pink),
        ]

        let completionScores = macros.map { $0.progress }
        let hasData = macros.contains(where: { $0.consumed > 0 })
        let macroRecommendation: String
        if hasData {
            if completionScores.allSatisfy({ $0 >= 1 }) {
                macroRecommendation = "Try to not have more today"
            } else if completionScores.allSatisfy({ $0 >= 0.75 }) {
                macroRecommendation = "Light curd"
            } else {
                macroRecommendation = "Pasta"
            }
        } else {
            macroRecommendation = "Pasta"
        }

        let aiRecommendation = app.foodLogRecommendations.first
        let recommendation: String
        if let aiRecommendation {
            let trimmedDescription =
                aiRecommendation.description.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedTitle = aiRecommendation.title.trimmingCharacters(
                in: .whitespacesAndNewlines)
            if !trimmedDescription.isEmpty {
                recommendation = trimmedDescription
            } else if !trimmedTitle.isEmpty {
                recommendation = "We recommend \(trimmedTitle) today."
            } else {
                recommendation = macroRecommendation
            }
        } else {
            recommendation = macroRecommendation
        }

        return FoodLogSummary(
            calories: Int(totalCalories.rounded()),
            caloriesRemaining: Int(caloriesRemaining.rounded()),
            calorieGoal: Int(calorieGoal.rounded()),
            progress: caloriesProgress,
            macros: macros,
            recommendation: recommendation,
            mealsCount: todayItems.count,
            todayItems: todayItems
        )
    }

    fileprivate var workoutSuggestionTitles: [String] {
        let quickPickTitles = WorkoutQuickPickDefinition.defaultQuickPicks.map(\.label)
        let recommendationTitles = app.workoutRecommendations.compactMap { recommendation in
            recommendation.quickPickDefinition?.label ?? recommendation.title
        }
        return quickPickTitles + recommendationTitles
    }

    fileprivate func ensureHighlightedWorkoutSuggestion() {
        let titles = workoutSuggestionTitles
        guard !titles.isEmpty else {
            app.highlightedWorkoutSuggestion = ""
            return
        }
        if !titles.contains(app.highlightedWorkoutSuggestion) {
            app.highlightedWorkoutSuggestion = titles.randomElement() ?? ""
        }
    }

    fileprivate func formatMinutesText(_ minutes: Double, roundUp: Bool) -> String {
        let adjusted = roundUp ? ceil(minutes) : minutes
        if adjusted >= 60 {
            return String(format: "%.1fh", adjusted / 60)
        }
        return "\(Int(adjusted))min"
    }

    fileprivate func parseDurationMinutes(from text: String) -> Double {
        let allowedCharacters = CharacterSet(charactersIn: "0123456789.")
        let filtered = text.unicodeScalars.filter { allowedCharacters.contains($0) }
        return Double(String(filtered)) ?? 0
    }

    fileprivate func parseDouble(_ text: String?) -> Double {
        guard let raw = text, !raw.isEmpty else { return 0 }
        let allowedCharacters = CharacterSet(charactersIn: "0123456789.")
        let filtered = raw.unicodeScalars.filter { allowedCharacters.contains($0) }
        return Double(String(filtered)) ?? 0
    }

    fileprivate func isToday(_ isoString: String) -> Bool {
        guard let date = parseDate(from: isoString) else { return false }
        return Calendar.current.isDateInToday(date)
    }

    fileprivate func parseDate(from isoString: String) -> Date? {
        if let date = DashboardView.isoFormatterWithFractional.date(from: isoString) {
            return date
        }
        return DashboardView.isoFormatter.date(from: isoString)
    }

    fileprivate static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    fileprivate static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

struct DashboardCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                Spacer()
            }
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct WorkoutSummary {
    let remainingText: String
    let doneText: String
    let recommendationHighlight: String
    let recommendationIconName: String
    let progress: Double
    let state: WorkoutState
}

struct FoodLogSummary {
    let calories: Int
    let caloriesRemaining: Int
    let calorieGoal: Int
    let progress: Double
    let macros: [MacroRingData]
    let recommendation: String
    let mealsCount: Int
    let todayItems: [FoodLogItem]
}

private struct DashboardScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct MacroRingData: Identifiable {
    let label: String
    let consumed: Double
    let target: Double
    let color: Color

    var id: String { label }

    var progress: Double {
        guard target > 0 else { return 0 }
        return min(consumed / target, 1)
    }

    var formattedValue: String {
        "\(Int(consumed.rounded()))g"
    }
}

struct MacroTargets {
    let calories: Double
    let carbs: Double
    let protein: Double
    let fat: Double
}

enum WorkoutState {
    case notStarted
    case partiallyCompleted
    case completed
}

extension WorkoutState {
    var accentColor: Color {
        switch self {
        case .completed: return .green
        case .partiallyCompleted: return .orange
        case .notStarted: return .gray
        }
    }

    var statusLabel: String {
        switch self {
        case .completed: return "Completed"
        case .partiallyCompleted: return "In progress"
        case .notStarted: return "Not started"
        }
    }
}

struct TodaysProgressStack: View {
    let workoutSummary: WorkoutSummary
    let foodSummary: FoodLogSummary
    let onWorkoutTap: (() -> Void)?
    let onFoodLogTap: (() -> Void)?
    let onSleepTap: (() -> Void)?

    init(
        workoutSummary: WorkoutSummary,
        foodSummary: FoodLogSummary,
        onWorkoutTap: (() -> Void)? = nil,
        onFoodLogTap: (() -> Void)? = nil,
        onSleepTap: (() -> Void)? = nil
    ) {
        self.workoutSummary = workoutSummary
        self.foodSummary = foodSummary
        self.onWorkoutTap = onWorkoutTap
        self.onFoodLogTap = onFoodLogTap
        self.onSleepTap = onSleepTap
    }

    var body: some View {
        VStack(spacing: 12) {
            WorkoutCardView(
                remainingText: workoutSummary.remainingText,
                doneText: workoutSummary.doneText,
                recommendationHighlight: workoutSummary.recommendationHighlight,
                recommendationIconName: workoutSummary.recommendationIconName,
                progress: workoutSummary.progress,
                state: workoutSummary.state,
                onTap: onWorkoutTap
            )
            FoodLogCardView(
                summary: foodSummary,
                onTap: onFoodLogTap
            )
            SleepCardView(onTap: onSleepTap)
        }
    }
}

struct SuggestedReadsSection: View {
    let articles: [ArticleTopic]

    var body: some View {
        if articles.isEmpty {
            Text("Your personalized reading list will appear here soon.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(articles) { article in
                        NavigationLink {
                            ArticleDetailView(article: article)
                        } label: {
                            SuggestedReadCard(article: article)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct SuggestedReadCard: View {
    let article: ArticleTopic
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(article.title)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .foregroundColor(.primary)

            Spacer(minLength: 0)

            Label("Read more", systemImage: "arrow.up.forward.circle.fill")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(buttonBackground, in: Capsule())
                .foregroundColor(buttonTextColor)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.bottom, 2)
        }
        .padding()
        .frame(width: 240, height: 160, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(cardStroke, lineWidth: 1)
        )
    }

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color.green.opacity(0.22)
            : Color.green.opacity(0.12)
    }

    private var cardStroke: Color {
        colorScheme == .dark
            ? Color.green.opacity(0.45)
            : Color.green.opacity(0.25)
    }

    private var buttonBackground: Color {
        colorScheme == .dark
            ? Color.green.opacity(0.3)
            : Color.green.opacity(0.2)
    }

    private var buttonTextColor: Color {
        colorScheme == .dark ? .white : .primary
    }
}

struct ArticleTopic: Decodable, Identifiable {
    let title: String
    let link: String
    let imageLinks: [String]

    var id: String { link }

    var readableLink: String {
        link
            .replacingOccurrences(of: ".md", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    var randomImageURL: URL? {
        guard !imageLinks.isEmpty else { return nil }
        return imageLinks.compactMap { URL(string: $0) }.randomElement()
    }

    var markdownResourceName: String {
        link.replacingOccurrences(of: ".md", with: "")
    }

    enum CodingKeys: String, CodingKey {
        case title
        case link
        case imageLinks = "image_links"
    }

    static let fallback: [ArticleTopic] = [
        ArticleTopic(
            title: "Sodium and Potassium Balance",
            link: "sodiumPotasium.md",
            imageLinks: []
        ),
        ArticleTopic(
            title: "Exercise and Cardiovascular Health",
            link: "exercise.md",
            imageLinks: []
        ),
        ArticleTopic(
            title: "Stress and Hormonal Regulation",
            link: "stress.md",
            imageLinks: []
        ),
        ArticleTopic(
            title: "Sleep Quality and Circadian Rhythm",
            link: "sleep.md",
            imageLinks: []
        ),
    ]
}

struct ArticleLibrary: Decodable {
    let topics: [ArticleTopic]
}

enum ArticleLoader {
    private static var cachedTopics: [ArticleTopic]?

    static func featured(limit: Int) -> [ArticleTopic] {
        let topics = allTopics()
        return Array(topics.prefix(limit))
    }

    static func allTopics() -> [ArticleTopic] {
        if let cached = cachedTopics {
            return cached
        }

        let decoder = JSONDecoder()
        let bundleURLs: [URL?] = [
            Bundle.main.url(
                forResource: "articles", withExtension: "json", subdirectory: "Articles"),
            Bundle.main.url(forResource: "articles", withExtension: "json"),
        ]

        for url in bundleURLs.compactMap({ $0 }) {
            if let data = try? Data(contentsOf: url),
                let library = try? decoder.decode(ArticleLibrary.self, from: data),
                !library.topics.isEmpty
            {
                cachedTopics = library.topics
                return library.topics
            }
        }

        cachedTopics = ArticleTopic.fallback
        return ArticleTopic.fallback
    }
}
