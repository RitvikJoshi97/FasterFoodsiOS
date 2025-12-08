import HealthKit
import SwiftUI

struct WorkoutsView: View {
    @EnvironmentObject private var app: AppState
    @StateObject private var viewModel = WorkoutsViewModel()
    @StateObject private var healthKitManager = HealthKitWorkoutManager()
    @State private var isLoadingRecommendations = false
    @State private var requestingHealthAccess = false
    @State private var importingHealthWorkoutIDs: Set<UUID> = []
    @State private var isPresentingAddWorkout = false
    var embedsInNavigationStack = true

    var body: some View {
        Group {
            if embedsInNavigationStack {
                NavigationStack {
                    listContent
                }
            } else {
                listContent
            }
        }
        .onAppear {
            viewModel.bootstrap(with: app)
            healthKitManager.refreshAuthorizationStatus()
            print("WorkoutsView appeared - workout items count: \(app.workoutItems.count)")
        }
        .onChange(of: viewModel.selectedActivityID) { oldValue, newValue in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    @ViewBuilder
    private var listContent: some View {
        List {
            Section {
                WorkoutSuggestionsCard(
                    viewModel: viewModel,
                    recommendations: app.workoutRecommendations,
                    isLoadingRecommendations: isLoadingRecommendations,
                    onRefreshRecommendations: refreshRecommendations,
                    onDismissRecommendation: { id in
                        Task {
                            try? await app.sendWorkoutRecommendationFeedback(
                                id: id, action: .dismissed)
                        }
                    },
                    onAddWorkout: { isPresentingAddWorkout = true }
                )
            }

            healthKitSection

            if !app.workoutItems.isEmpty {
                WorkoutHistoryList(
                    items: app.workoutItems,
                    activities: viewModel.activities,
                    onDelete: { id in
                        Task {
                            try? await app.deleteWorkout(id: id)
                        }
                    })
            } else {
                Section {
                    Text("No workouts yet. Log your first workout above!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Workouts")
        .sheet(isPresented: $isPresentingAddWorkout) {
            AddWorkoutsView(
                viewModel: viewModel,
                onSubmit: {
                    addWorkout()
                    isPresentingAddWorkout = false
                },
                onCancel: {
                    isPresentingAddWorkout = false
                }
            )
        }
    }

    @ViewBuilder
    private var healthKitSection: some View {
        Section("Health App") {
            switch healthKitManager.authorizationState {
            case .unavailable:
                Text("Health data is not available on this device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .notDetermined:
                VStack(alignment: .leading, spacing: 8) {
                    Text(
                        "Connect to the Health app to import workouts recorded on your iPhone or Apple Watch."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    Button(action: requestHealthKitAccess) {
                        if requestingHealthAccess {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Connect to Health", systemImage: "heart.text.square")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            case .denied:
                Text(
                    "Health access has been denied. Enable FasterFoods in the Health app under Data Access & Devices to import workouts."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            case .authorized:
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent workouts from Health")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Button(action: refreshHealthKitWorkouts) {
                            if healthKitManager.isFetchingRecentWorkouts {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Refresh Health workouts")
                    }
                    if healthKitManager.recentWorkouts.isEmpty {
                        Text("No workouts found in the last two weeks.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(healthKitManager.recentWorkouts.prefix(5)) { workout in
                            HealthKitWorkoutRow(
                                workout: workout,
                                isImporting: importingHealthWorkoutIDs.contains(workout.id),
                                onImport: { importHealthWorkout(workout) }
                            )
                        }
                    }
                }
            }
        }
    }

    private func addWorkout() {
        guard let item = viewModel.makeWorkoutItem() else { return }
        Task {
            do {
                try await app.addWorkout(item)
                viewModel.resetComposer()
            } catch {
                print("Failed to add workout: \(error)")
            }
        }
    }

    private func refreshRecommendations() {
        Task {
            isLoadingRecommendations = true
            defer { isLoadingRecommendations = false }
            do {
                try await app.loadWorkoutRecommendations()
            } catch {
                print("Failed to load workout recommendations: \(error)")
            }
        }
    }

    private func requestHealthKitAccess() {
        guard !requestingHealthAccess else { return }
        requestingHealthAccess = true
        Task {
            await healthKitManager.requestAuthorization()
            requestingHealthAccess = false
        }
    }

    private func refreshHealthKitWorkouts() {
        healthKitManager.fetchRecentWorkouts()
    }

    private func importHealthWorkout(_ workout: HKWorkout) {
        let identifier = workout.id
        guard !importingHealthWorkoutIDs.contains(identifier) else { return }
        importingHealthWorkoutIDs.insert(identifier)
        Task {
            defer {
                Task { @MainActor in
                    importingHealthWorkoutIDs.remove(identifier)
                }
            }
            guard let item = viewModel.makeWorkoutItem(fromHealthKit: workout) else { return }
            do {
                try await app.addWorkout(item)
            } catch {
                print("Failed to import workout from HealthKit: \(error)")
            }
        }
    }
}

// MARK: - View Model

@MainActor
final class WorkoutsViewModel: ObservableObject {
    @Published var selectedActivityID: String {
        didSet {
            guard oldValue != selectedActivityID else { return }
            handleActivityChange(isFromQuickPick: isApplyingQuickPick)
        }
    }
    @Published var selectedCategoryID: String {
        didSet {
            guard oldValue != selectedCategoryID else { return }
            handleCategoryChange(isFromQuickPick: isApplyingQuickPick)
        }
    }
    @Published var workoutName: String = ""
    @Published var duration: String = ""
    @Published var calories: String = ""
    @Published var parameterValues: [String: String] = [:]
    @Published var workoutDate: Date = Date()
    @Published var isApplyingQuickPick = false

    private let isoFormatter: ISO8601DateFormatter

    let activities: [WorkoutActivityDefinition]
    let quickPicks: [WorkoutQuickPickDefinition]

    init(
        activities: [WorkoutActivityDefinition] = WorkoutActivityDefinition.defaultActivities,
        quickPicks: [WorkoutQuickPickDefinition] = WorkoutQuickPickDefinition.defaultQuickPicks
    ) {
        self.activities = activities
        self.quickPicks = quickPicks
        _selectedActivityID = Published(initialValue: activities.first?.id ?? "")
        _selectedCategoryID = Published(initialValue: activities.first?.categories.first?.id ?? "")
        isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        ensureDefaultOptionValues()
    }

    func bootstrap(with app: AppState) {
        let items = app.workoutItems
        guard let latest = items.first else { return }
        workoutName = latest.name
        if activities.contains(where: { $0.id == latest.activity }) {
            selectedActivityID = latest.activity
        }
        if let activity = activities.first(where: { $0.id == latest.activity }),
            activity.categories.contains(where: { $0.id == latest.category })
        {
            selectedCategoryID = latest.category
        }
    }

    var selectedActivity: WorkoutActivityDefinition? {
        activities.first(where: { $0.id == selectedActivityID })
    }

    var selectedCategory: WorkoutCategoryDefinition? {
        selectedActivity?.categories.first(where: { $0.id == selectedCategoryID })
    }

    func binding(for parameter: WorkoutParameterDefinition) -> Binding<String> {
        Binding(
            get: { self.parameterValues[parameter.id] ?? "" },
            set: { self.parameterValues[parameter.id] = $0 }
        )
    }

    func applyQuickPick(_ pick: WorkoutQuickPickDefinition) {
        isApplyingQuickPick = true
        workoutName = pick.label
        selectedActivityID = pick.activityID
        selectedCategoryID = pick.categoryID
        duration = pick.duration ?? ""
        calories = pick.calories ?? ""
        parameterValues = pick.parameterPrefill
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.isApplyingQuickPick = false
        }
    }

    func makeWorkoutItem() -> WorkoutLogItem? {
        guard
            let category = selectedCategory,
            !duration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let durationValue = Double(duration)
        else {
            return nil
        }

        var params: [String: AnyCodableValue] = [:]
        for parameter in category.parameters {
            let value =
                parameterValues[parameter.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !value.isEmpty {
                // Try to parse as number, otherwise keep as string
                if let intValue = Int(value) {
                    params[parameter.name] = .int(intValue)
                } else if let doubleValue = Double(value) {
                    params[parameter.name] = .double(doubleValue)
                } else {
                    params[parameter.name] = .string(value)
                }
            } else if parameter.required {
                return nil
            }
        }

        let caloriesText = calories.trimmingCharacters(in: .whitespacesAndNewlines)
        let caloriesValue: Double?
        if caloriesText.isEmpty {
            caloriesValue = nil
        } else if let numericValue = Double(caloriesText) {
            caloriesValue = numericValue
        } else {
            return nil
        }

        let item = WorkoutLogItem(
            name: workoutName.isEmpty ? category.name : workoutName,
            activity: selectedActivityID,
            category: category.id,
            duration: String(durationValue),
            calories: caloriesValue.map { String($0) },
            parameters: params,
            datetime: isoFormatter.string(from: workoutDate)
        )
        return item
    }

    func makeWorkoutItem(fromHealthKit workout: HKWorkout) -> WorkoutLogItem? {
        let durationMinutes = max(workout.duration / 60, 1)
        let durationString = formatMinutes(durationMinutes)
        let caloriesValue = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())

        var params: [String: AnyCodableValue] = [
            "Source": .string("Apple Health"),
            "Activity Type": .string(workout.workoutActivityType.displayName),
        ]

        if let distanceMeters = workout.totalDistance?.doubleValue(for: .meter()),
            distanceMeters > 0
        {
            let kilometers = (distanceMeters / 1000)
            params["Distance (km)"] = .double(roundValue(kilometers, decimalPlaces: 2))
        }

        if let deviceName = workout.device?.name {
            params["Device"] = .string(deviceName)
        }

        return WorkoutLogItem(
            name: workout.workoutActivityType.displayName,
            activity: WorkoutActivityDefinition.Constants.others,
            category: WorkoutActivityDefinition.Constants.healthKitImport,
            duration: durationString,
            calories: caloriesValue.map { String(Int($0.rounded())) },
            parameters: params,
            datetime: isoFormatter.string(from: workout.endDate)
        )
    }

    func resetComposer() {
        workoutName = ""
        duration = ""
        calories = ""
        parameterValues = [:]
        workoutDate = Date()
    }

    private func handleActivityChange(isFromQuickPick: Bool) {
        let firstCategoryID = selectedActivity?.categories.first?.id ?? ""
        if !isFromQuickPick {
            selectedCategoryID = firstCategoryID
            parameterValues = [:]
        } else if selectedCategoryID.isEmpty {
            selectedCategoryID = firstCategoryID
        }
        ensureDefaultOptionValues()
    }

    private func handleCategoryChange(isFromQuickPick: Bool) {
        if !isFromQuickPick {
            parameterValues = [:]
        }
        ensureDefaultOptionValues()
    }

    private func ensureDefaultOptionValues() {
        guard let parameters = selectedCategory?.parameters else { return }
        for parameter in parameters {
            guard case .options(let options) = parameter.kind,
                let first = options.first
            else { continue }
            let currentValue =
                parameterValues[parameter.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if currentValue.isEmpty {
                parameterValues[parameter.id] = first
            }
        }
    }

    private func roundValue(_ value: Double, decimalPlaces: Int) -> Double {
        let multiplier = pow(10.0, Double(decimalPlaces))
        return (value * multiplier).rounded() / multiplier
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let roundedValue = roundValue(minutes, decimalPlaces: 1)
        if roundedValue.rounded() == roundedValue {
            return String(Int(roundedValue))
        }
        return String(roundedValue)
    }
}

// MARK: - HealthKit

@MainActor
final class HealthKitWorkoutManager: ObservableObject {
    enum AuthorizationState {
        case unavailable
        case notDetermined
        case denied
        case authorized
    }

    @Published private(set) var authorizationState: AuthorizationState
    @Published private(set) var recentWorkouts: [HKWorkout] = []
    @Published private(set) var isFetchingRecentWorkouts = false

    private let healthStore = HKHealthStore()
    private let lookbackDays = 14

    init() {
        if HKHealthStore.isHealthDataAvailable() {
            authorizationState = .notDetermined
        } else {
            authorizationState = .unavailable
        }
    }

    func refreshAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationState = .unavailable
            recentWorkouts = []
            return
        }

        let status = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        switch status {
        case .sharingAuthorized:
            authorizationState = .authorized
            if recentWorkouts.isEmpty {
                fetchRecentWorkouts()
            }
        case .sharingDenied:
            authorizationState = .denied
            recentWorkouts = []
        case .notDetermined:
            fallthrough
        @unknown default:
            authorizationState = .notDetermined
        }
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationState = .unavailable
            return
        }

        var readTypes: Set<HKObjectType> = [HKObjectType.workoutType()]
        let identifiers: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .activeEnergyBurned,
            .distanceWalkingRunning,
            .distanceCycling,
            .distanceSwimming,
        ]
        identifiers.compactMap { HKObjectType.quantityType(forIdentifier: $0) }.forEach {
            readTypes.insert($0)
        }

        do {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if success {
                        continuation.resume(returning: ())
                    } else {
                        continuation.resume(throwing: HealthKitAuthorizationError.requestFailed)
                    }
                }
            }
            authorizationState = .authorized
            fetchRecentWorkouts()
        } catch {
            authorizationState = .denied
            print("HealthKit authorization failed: \(error)")
        }
    }

    func fetchRecentWorkouts(limit: Int = 10) {
        guard authorizationState == .authorized else { return }
        isFetchingRecentWorkouts = true

        let startDate =
            Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date())
            ?? Date.distantPast
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: HKObjectType.workoutType(),
            predicate: predicate,
            limit: limit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in
            guard let self else { return }
            Task { @MainActor in
                self.isFetchingRecentWorkouts = false
                if let workouts = samples as? [HKWorkout] {
                    self.recentWorkouts = workouts
                } else if let error {
                    print("Failed to fetch workouts from HealthKit: \(error)")
                    self.recentWorkouts = []
                }
            }
        }
        healthStore.execute(query)
    }

    enum HealthKitAuthorizationError: Error {
        case requestFailed
    }
}

extension HKWorkout: Identifiable {
    public var id: UUID { uuid }
}

extension HKWorkoutActivityType {
    fileprivate var displayName: String {
        switch self {
        case .running: return "Running"
        case .walking: return "Walking"
        case .hiking: return "Hiking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .traditionalStrengthTraining: return "Strength Training"
        case .functionalStrengthTraining: return "Functional Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .coreTraining: return "Core Training"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stair Climbing"
        case .dance: return "Dance"
        case .mindAndBody: return "Mind & Body"
        case .crossTraining: return "Cross Training"
        case .martialArts: return "Martial Arts"
        case .boxing: return "Boxing"
        default: return "Workout"
        }
    }
}

// MARK: - Suggestions Section

private struct HealthKitWorkoutRow: View {
    let workout: HKWorkout
    let isImporting: Bool
    let onImport: () -> Void

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static let distanceFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.maximumFractionDigits = 2
        formatter.numberFormatter.minimumFractionDigits = 0
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.workoutActivityType.displayName)
                        .font(.subheadline.weight(.medium))
                    Text(Self.dateFormatter.string(from: workout.startDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isImporting {
                    ProgressView()
                        .scaleEffect(0.9)
                } else {
                    Button("Log") {
                        onImport()
                    }
                    .buttonStyle(.bordered)
                }
            }

            if !detailLine.isEmpty {
                Text(detailLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var detailLine: String {
        var parts: [String] = []
        if let durationText = Self.durationFormatter.string(from: workout.duration) {
            parts.append(durationText)
        }
        if let energy = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
            parts.append("\(Int(energy.rounded())) kcal")
        }
        if let distanceMeters = workout.totalDistance?.doubleValue(for: .meter()),
            distanceMeters > 0
        {
            let measurement = Measurement(value: distanceMeters / 1000, unit: UnitLength.kilometers)
            parts.append(Self.distanceFormatter.string(from: measurement))
        }
        return parts.joined(separator: " • ")
    }
}

// MARK: - Composer Form

// MARK: - Support Models

struct WorkoutActivityDefinition: Identifiable {
    enum Constants {
        static let cardio = "cardio-running"
        static let cycling = "cycling"
        static let gymStrength = "gym-strength"
        static let mindBody = "mind-body"
        static let waterSports = "water-sports"
        static let winterSports = "winter-sports"
        static let combatMixed = "combat-mixed"
        static let teamField = "team-field"
        static let others = "others"
        static let racketPrecision = "racket-precision"
        static let healthKitImport = "healthkit-import"
    }

    let id: String
    let name: String
    let categories: [WorkoutCategoryDefinition]

    static let defaultActivities = WorkoutActivityDefinitionDefaults.defaultActivities
}

struct WorkoutCategoryDefinition: Identifiable {
    let id: String
    let name: String
    let parameters: [WorkoutParameterDefinition]
}

struct WorkoutParameterDefinition: Identifiable {
    enum Kind {
        case number(unit: String)
        case text(unit: String)
        case options([String])
    }

    let id: String
    let name: String
    let kind: Kind
    let required: Bool

    init(id: String, name: String, kind: Kind, required: Bool = false) {
        self.id = id
        self.name = name
        self.kind = kind
        self.required = required
    }

    var placeholder: String {
        switch kind {
        case .number(let unit):
            return unit.isEmpty ? "Enter value" : "Enter value (\(unit))"
        case .text(let unit):
            return unit.isEmpty ? "Enter details" : "Enter details (\(unit))"
        case .options:
            return "Select option"
        }
    }
}

struct WorkoutQuickPickDefinition: Identifiable {
    let id: UUID = UUID()
    let label: String
    let activityID: String
    let categoryID: String
    let duration: String?
    let calories: String?
    let parameterPrefill: [String: String]

    var activityName: String {
        switch activityID {
        case WorkoutActivityDefinition.Constants.cardio: return "Cardio"
        case WorkoutActivityDefinition.Constants.cycling: return "Cycling"
        case WorkoutActivityDefinition.Constants.gymStrength: return "Strength"
        case WorkoutActivityDefinition.Constants.mindBody: return "Mind & Body"
        case WorkoutActivityDefinition.Constants.waterSports: return "Water Sports"
        case WorkoutActivityDefinition.Constants.winterSports: return "Winter Sports"
        case WorkoutActivityDefinition.Constants.combatMixed: return "Combat"
        case WorkoutActivityDefinition.Constants.teamField: return "Team Sports"
        case WorkoutActivityDefinition.Constants.racketPrecision: return "Racket Sports"
        case WorkoutActivityDefinition.Constants.others: return "Others"
        default: return ""
        }
    }

    var categoryName: String {
        switch categoryID {
        case "outdoor-run": return "Outdoor run"
        case "indoor-run": return "Indoor run"
        case "walking": return "Walking"
        case "hiking": return "Hiking"
        case "outdoor-cycling": return "Outdoor cycling"
        case "indoor-cycling": return "Indoor cycling"
        case "traditional-strength": return "Traditional strength"
        case "hiit": return "HIIT"
        case "yoga": return "Yoga"
        case "pilates": return "Pilates"
        case "pool-swim": return "Pool swim"
        case "tennis": return "Tennis"
        default: return ""
        }
    }

    static let defaultQuickPicks: [WorkoutQuickPickDefinition] = [
        WorkoutQuickPickDefinition(
            label: "Outdoor Run (30 min)",
            activityID: WorkoutActivityDefinition.Constants.cardio,
            categoryID: "outdoor-run",
            duration: "30",
            calories: nil,
            parameterPrefill: [:]
        ),
        WorkoutQuickPickDefinition(
            label: "HIIT Circuit (20 min)",
            activityID: WorkoutActivityDefinition.Constants.gymStrength,
            categoryID: "hiit",
            duration: "20",
            calories: nil,
            parameterPrefill: [:]
        ),
        WorkoutQuickPickDefinition(
            label: "Yoga Flow (25 min)",
            activityID: WorkoutActivityDefinition.Constants.mindBody,
            categoryID: "yoga",
            duration: "25",
            calories: nil,
            parameterPrefill: [:]
        ),
        WorkoutQuickPickDefinition(
            label: "Strength Session (40 min)",
            activityID: WorkoutActivityDefinition.Constants.gymStrength,
            categoryID: "traditional-strength",
            duration: "40",
            calories: nil,
            parameterPrefill: [:]
        ),
    ]
}
