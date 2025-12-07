//
//  DashboardView.swift
//  FasterFoods
//
//  Created by Ritvik Joshi on 11/04/25.
//

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
    @Environment(\.colorScheme) private var colorScheme
    @State private var todaysProgressDestination: TodaysProgressDestination?
    @State private var isHeaderCompact = false

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
                        TodaysProgressCarousel(
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

                    GoalsSection()
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

        let durationText: String
        if totalMinutes >= 60 {
            durationText = String(format: "%.1fh", totalMinutes / 60)
        } else {
            durationText = "\(Int(totalMinutes))min"
        }

        let subtitleText: String
        switch state {
        case .completed:
            subtitleText = "Well done, rest well"
        case .partiallyCompleted:
            let remaining = max(workoutGoalMinutes - totalMinutes, 0)
            subtitleText = "\(Int(ceil(remaining))) minutes more"
        case .notStarted:
            subtitleText = "Start your workout"
        }

        return WorkoutSummary(
            durationText: durationText,
            subtitleText: subtitleText,
            progress: progress,
            state: state
        )
    }

    fileprivate var foodLogSummary: FoodLogSummary {
        let todayItems = app.foodLogItems.filter { isToday($0.datetime) }
        let totalCalories = todayItems.reduce(0.0) { $0 + parseDouble($1.calories) }
        let protein = todayItems.reduce(0.0) { $0 + parseDouble($1.protein) }
        let fat = todayItems.reduce(0.0) { $0 + parseDouble($1.fat) }

        // Estimate carbs from remaining calories if explicit value is missing.
        let carbCalories = max(totalCalories - (protein * 4 + fat * 9), 0)
        let carbs = carbCalories / 4

        let macros: [MacroRingData] = [
            MacroRingData(
                label: "Carbs", consumed: carbs, target: macroTargets.carbs, color: .orange),
            MacroRingData(
                label: "Protein", consumed: protein, target: macroTargets.protein, color: .purple),
            MacroRingData(label: "Fat", consumed: fat, target: macroTargets.fat, color: .pink),
        ]

        let completionScores = macros.map { $0.progress }
        let hasData = macros.contains(where: { $0.consumed > 0 })
        let recommendation: String
        if hasData {
            if completionScores.allSatisfy({ $0 >= 1 }) {
                recommendation = "Try to not have more today"
            } else if completionScores.allSatisfy({ $0 >= 0.75 }) {
                recommendation = "Light curd"
            } else {
                recommendation = "Pasta"
            }
        } else {
            recommendation = "Pasta"
        }

        return FoodLogSummary(
            calories: Int(totalCalories.rounded()),
            macros: macros,
            recommendation: recommendation
        )
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
    let durationText: String
    let subtitleText: String
    let progress: Double
    let state: WorkoutState
}

struct FoodLogSummary {
    let calories: Int
    let macros: [MacroRingData]
    let recommendation: String
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
    fileprivate var accentColor: Color {
        switch self {
        case .completed: return .green
        case .partiallyCompleted: return .orange
        case .notStarted: return .gray
        }
    }

    fileprivate var statusLabel: String {
        switch self {
        case .completed: return "Completed"
        case .partiallyCompleted: return "In progress"
        case .notStarted: return "Not started"
        }
    }
}

struct TodaysProgressCarousel: View {
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
        TabView {
            WorkoutCardView(
                durationText: workoutSummary.durationText,
                subtitleText: workoutSummary.subtitleText,
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
        .frame(height: 190)
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
    }
}

struct WorkoutCardView: View {
    let durationText: String
    let subtitleText: String
    let progress: Double
    let state: WorkoutState
    let onTap: (() -> Void)?

    init(
        durationText: String,
        subtitleText: String,
        progress: Double,
        state: WorkoutState,
        onTap: (() -> Void)? = nil
    ) {
        self.durationText = durationText
        self.subtitleText = subtitleText
        self.progress = progress
        self.state = state
        self.onTap = onTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Workout")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Text(state.statusLabel)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(state.accentColor.opacity(0.15))
                    .cornerRadius(8)
            }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(durationText)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.primary)

                    Text(subtitleText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                        .frame(width: 70, height: 70)

                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(
                            state.accentColor,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 70, height: 70)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(state.accentColor.opacity(0.1))
        )
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .animation(.easeInOut, value: progress)
        .contentShape(Rectangle())
        .onTapGesture {
            guard let onTap else { return }
            onTap()
        }
    }
}

struct FoodLogCardView: View {
    let summary: FoodLogSummary
    let onTap: (() -> Void)?

    init(
        summary: FoodLogSummary,
        onTap: (() -> Void)? = nil
    ) {
        self.summary = summary
        self.onTap = onTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(summary.calories) kcal")
                        .font(.system(size: 32, weight: .bold))
                    Text("logged today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    ForEach(summary.macros) { macro in
                        MacroRingView(macro: macro)
                    }
                }
            }

            Spacer()

            Text(summary.recommendation)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.1))
        )
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            guard let onTap else { return }
            onTap()
        }
    }
}

struct MacroRingView: View {
    let macro: MacroRingData

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 36, height: 36)

                Circle()
                    .trim(from: 0, to: CGFloat(macro.progress))
                    .stroke(
                        macro.color,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 36, height: 36)

                Text("\(Int(macro.progress * 100))%")
                    .font(.system(size: 10, weight: .bold))
                    .fontWeight(.semibold)
            }

            VStack(spacing: 2) {
                Text(macro.label)
                    .font(.caption2)
                    .fontWeight(.medium)
                Text(macro.formattedValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SleepCardView: View {
    let onTap: (() -> Void)?

    init(onTap: (() -> Void)? = nil) {
        self.onTap = onTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep")
                .font(.title3)
                .fontWeight(.semibold)

            Spacer()

            Text("7h sleep yesterday")
                .font(.system(size: 28, weight: .bold))

            Text("Recommended sleep: 8h for today")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.12))
        )
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            guard let onTap else { return }
            onTap()
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

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: article.randomImageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Color.accentColor.opacity(0.15)
                case .empty:
                    Color.gray.opacity(0.1)
                @unknown default:
                    Color.gray.opacity(0.1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [.black.opacity(0.7), .black.opacity(0.2)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(article.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .foregroundColor(.white)
                Spacer()
                HStack {
                    Spacer()
                    Label("Read more", systemImage: "arrow.up.forward")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundColor(.white)
                }
            }
            .padding()
        }
        .frame(width: 240, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 4)
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

// MARK: - Goals Section
struct GoalsSection: View {
    @State private var goalDescription = ""
    @State private var savedGoals: [Goal] = []
    @State private var recommendations: [GoalRecommendation] = []
    @State private var isSubmitting = false
    @State private var isLoading = true
    @State private var isLoadingRecommendations = true
    @State private var statusMessage: String?
    @State private var isSuccess = false
    @State private var selectedRecommendation: GoalRecommendation?
    @State private var gamePlanPreview = ""
    @State private var gamePlanMarkdown = ""
    @State private var activeSheet: GoalSectionSheet?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Goal Setting", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Capture your long-form fitness goals and get inspired by community suggestions.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    activeGoalsSection
                    gamePlanSection
                    statusMessageView
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .gamePlan:
                GamePlanDetailView(markdown: gamePlanMarkdown)
            case .addGoal:
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            goalForm
                            statusMessageView
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    }
                    .navigationTitle("Add Goal")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                activeSheet = nil
                            }
                        }
                    }
                }
                .presentationDetents([.fraction(0.75), .large])
                .presentationDragIndicator(.visible)
                .task {
                    await loadRecommendationsIfNeeded()
                }
            }
        }
        .onAppear {
            loadGamePlanContentIfNeeded()
            Task {
                await loadData()
            }
        }
    }

    private enum GoalSectionSheet: Identifiable {
        case addGoal
        case gamePlan

        var id: String {
            switch self {
            case .addGoal: return "addGoal"
            case .gamePlan: return "gamePlan"
            }
        }
    }

    @ViewBuilder
    private var activeGoalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(.secondary)
                Text("Your active goals")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button {
                    activeSheet = .addGoal
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
                ForEach(savedGoals) { goal in
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
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }

    @ViewBuilder
    private var gamePlanSection: some View {
        if !gamePlanPreview.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Game Plan", systemImage: "map")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Group {
                    if let attributed = try? AttributedString(
                        markdown: gamePlanPreview,
                        options: .init(
                            interpretedSyntax: .full,
                            failurePolicy: .returnPartiallyParsedIfPossible
                        )
                    ) {
                        Text(attributed)
                    } else {
                        Text(gamePlanPreview)
                    }
                }
                .font(.footnote)
                .multilineTextAlignment(.leading)
                .lineLimit(6)
                .lineSpacing(4)
                .foregroundStyle(.primary)

                Button {
                    guard !gamePlanMarkdown.isEmpty else { return }
                    activeSheet = .gamePlan
                } label: {
                    HStack(spacing: 6) {
                        Text("Read more")
                        Image(systemName: "arrow.up.forward.circle.fill")
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.2), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(gamePlanMarkdown.isEmpty)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.green.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.green.opacity(0.25), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var goalForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            recommendationsSection
            VStack(alignment: .leading, spacing: 8) {
                Text("Your long-form goal")
                    .font(.subheadline)
                    .fontWeight(.medium)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $goalDescription)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .onChange(of: goalDescription) { oldValue, newValue in
                            // Clear selected recommendation if user types manually
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

            Button(action: saveGoal) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                    Image(systemName: "sparkles")
                    Text(isSubmitting ? "Saving..." : "Save Goal")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    goalDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.accentColor.opacity(0.4) : Color.accentColor
                )
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(
                goalDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || isSubmitting)

        }
    }

    @ViewBuilder
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.secondary)
                Text("Popular community goals")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if isLoadingRecommendations {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            if isLoadingRecommendations {
                Text("Loading inspiration from the community...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if recommendations.isEmpty {
                Text("No suggested goals yet. Check back soon!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                                    if let title = recommendation.title {
                                        Text(title)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .lineLimit(2)
                                    }
                                    Text(recommendation.description)
                                        .font(.caption2)
                                        .lineLimit(3)
                                    if let count = recommendation.usageCount {
                                        Text("\(count) keeping this")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(width: 200, alignment: .leading)
                                .background(
                                    selectedRecommendation?.id == recommendation.id
                                        ? Color.accentColor : Color.secondary.opacity(0.2)
                                )
                                .foregroundStyle(
                                    selectedRecommendation?.id == recommendation.id
                                        ? .white : .primary
                                )
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusMessageView: some View {
        if let message = statusMessage {
            HStack(spacing: 8) {
                Image(
                    systemName: isSuccess
                        ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(isSuccess ? .green : .red)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(isSuccess ? .green : .red)
            }
            .padding(.top, 4)
        }
    }

    private func loadGamePlanContentIfNeeded() {
        guard gamePlanPreview.isEmpty else { return }
        if let content = GamePlanLoader.load() {
            gamePlanPreview = content.previewMarkdown
            gamePlanMarkdown = content.markdown
        }
    }

    @MainActor
    private func loadData() async {
        isLoading = true

        // Load goals first
        do {
            let goals = try await APIClient.shared.getGoals()
            savedGoals = goals
            if goals.isEmpty && activeSheet == nil {
                activeSheet = .addGoal
            }
        } catch {
            print("Error loading goals: \(error)")
            savedGoals = []
            if activeSheet == nil {
                activeSheet = .addGoal
            }
        }
        isLoading = false

        await loadRecommendations()
    }

    private func saveGoal() {
        guard !goalDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        isSubmitting = true
        statusMessage = nil

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
                    savedGoals.insert(newGoal, at: 0)
                    goalDescription = ""
                    selectedRecommendation = nil
                    isSubmitting = false
                    isSuccess = true
                    statusMessage = "Goal saved. Keep up the great work!"
                    activeSheet = nil

                    // Clear success message after 3 seconds
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        await MainActor.run {
                            statusMessage = nil
                            isSuccess = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    isSuccess = false
                    statusMessage = "Could not save goal. Please try again."

                    // Clear error message after 3 seconds
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        await MainActor.run {
                            statusMessage = nil
                        }
                    }
                }
                print("Error saving goal: \(error)")
            }
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return dateString
    }

    @MainActor
    private func loadRecommendations() async {
        isLoadingRecommendations = true
        defer { isLoadingRecommendations = false }

        do {
            let recs = try await APIClient.shared.getGoalRecommendations()
            recommendations = recs
        } catch {
            print("Error loading goal recommendations: \(error)")
            recommendations = []
        }
    }

    @MainActor
    private func loadRecommendationsIfNeeded() async {
        guard recommendations.isEmpty, !isLoadingRecommendations else { return }
        await loadRecommendations()
    }
}

struct GamePlanDetailView: View {
    let markdown: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if let attributed = try? AttributedString(
                        markdown: markdown,
                        options: .init(
                            interpretedSyntax: .full,
                            failurePolicy: .returnPartiallyParsedIfPossible
                        )
                    ) {
                        Text(attributed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(markdown)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .lineSpacing(8)
                .textSelection(.enabled)
                .padding()
            }
            .navigationTitle("Game Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct GamePlanContent {
    let previewMarkdown: String
    let markdown: String
}

enum GamePlanLoader {
    static func load(maxPreviewLength: Int = 360) -> GamePlanContent? {
        let possibleURLs: [URL?] = [
            Bundle.main.url(forResource: "gameplan", withExtension: "md", subdirectory: "GamePlan"),
            Bundle.main.url(forResource: "gameplan", withExtension: "md"),
        ]

        for url in possibleURLs.compactMap({ $0 }) {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                let preview = buildPreview(from: content, maxLength: maxPreviewLength)
                let spacedPreview = addParagraphSpacing(to: preview)
                let spacedContent = addParagraphSpacing(to: content)
                if !spacedPreview.isEmpty {
                    return GamePlanContent(previewMarkdown: spacedPreview, markdown: spacedContent)
                }
            }
        }
        return nil
    }

    private static func addParagraphSpacing(to markdown: String) -> String {
        markdown.replacingOccurrences(of: "\n\n", with: "\n\n\n")
    }

    private static func buildPreview(from markdown: String, maxLength: Int) -> String {
        let sections = markdown.components(separatedBy: "\n\n")
        var collected: [String] = []
        var runningCount = 0

        for section in sections {
            let trimmed = section.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.hasPrefix("#") || trimmed == "---" { continue }
            if trimmed.lowercased().hasPrefix("table of contents") { continue }
            collected.append(trimmed)
            runningCount += trimmed.count
            if runningCount >= maxLength { break }
        }

        var preview = collected.joined(separator: "\n\n")
        guard !preview.isEmpty else { return "" }

        if preview.count > maxLength {
            var truncated = String(preview.prefix(maxLength))
            if let lastNewline = truncated.lastIndex(of: "\n") {
                truncated = String(truncated[..<lastNewline])
            } else if let lastSpace = truncated.lastIndex(of: " ") {
                truncated = String(truncated[..<lastSpace])
            }
            preview = truncated + "..."
        }

        return preview
    }
}
