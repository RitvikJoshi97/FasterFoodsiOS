import SwiftUI
import HealthKit

struct WorkoutsView: View {
    @EnvironmentObject private var app: AppState
    @StateObject private var viewModel = WorkoutsViewModel()
    @StateObject private var healthKitManager = HealthKitWorkoutManager()
    @State private var isLoadingRecommendations = false
    @State private var requestingHealthAccess = false
    @State private var importingHealthWorkoutIDs: Set<UUID> = []
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
                WorkoutComposer(
                    viewModel: viewModel,
                    onSubmit: addWorkout
                )
            }

            Section {
                WorkoutSuggestionsSection(
                    quickPicks: viewModel.quickPicks,
                    recommendations: app.workoutRecommendations,
                    isLoadingRecommendations: isLoadingRecommendations,
                    onQuickPick: viewModel.applyQuickPick(_:),
                    onRefreshRecommendations: refreshRecommendations,
                    onDismissRecommendation: { id in
                        Task {
                            try? await app.sendWorkoutRecommendationFeedback(id: id, action: .dismissed)
                        }
                    }
                )
            }

            healthKitSection

            Section {
                if !app.workoutItems.isEmpty {
                    WorkoutHistoryList(items: app.workoutItems,
                                       activities: viewModel.activities,
                                       onDelete: { id in
                                           Task {
                                               try? await app.deleteWorkout(id: id)
                                           }
                                       })
                } else {
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
                    Text("Connect to the Health app to import workouts recorded on your iPhone or Apple Watch.")
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
                Text("Health access has been denied. Enable FasterFoods in the Health app under Data Access & Devices to import workouts.")
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
           activity.categories.contains(where: { $0.id == latest.category }) {
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
            let value = parameterValues[parameter.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
            "Activity Type": .string(workout.workoutActivityType.displayName)
        ]

        if let distanceMeters = workout.totalDistance?.doubleValue(for: .meter()),
           distanceMeters > 0 {
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
            guard case let .options(options) = parameter.kind,
                  let first = options.first else { continue }
            let currentValue = parameterValues[parameter.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
            .distanceSwimming
        ]
        identifiers.compactMap { HKObjectType.quantityType(forIdentifier: $0) }.forEach { readTypes.insert($0) }

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
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

        let startDate = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date.distantPast
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(sampleType: HKObjectType.workoutType(),
                                  predicate: predicate,
                                  limit: limit,
                                  sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
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

private extension HKWorkoutActivityType {
    var displayName: String {
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

private struct WorkoutSuggestionsSection: View {
    let quickPicks: [WorkoutQuickPickDefinition]
    let recommendations: [ShoppingRecommendation]
    let isLoadingRecommendations: Bool
    let onQuickPick: (WorkoutQuickPickDefinition) -> Void
    let onRefreshRecommendations: () -> Void
    let onDismissRecommendation: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Suggestions")
                    .font(.headline)
                Spacer()
                Button(action: onRefreshRecommendations) {
                    if isLoadingRecommendations {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.plain)
            }

            ChipFlow(horizontalSpacing: 8, verticalSpacing: 8) {
                // Quick picks
                ForEach(quickPicks) { pick in
                    Button {
                        onQuickPick(pick)
                    } label: {
                        Text(pick.label)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }
                
                // AI recommendations
                ForEach(recommendations) { rec in
                    Button {
                        // Could show detail or apply
                    } label: {
                        HStack(spacing: 6) {
                            Text(rec.title)
                                .font(.subheadline)
                            Button {
                                onDismissRecommendation(rec.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .foregroundStyle(Color.accentColor)
                        .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)
        }
    }
}

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
           distanceMeters > 0 {
            let measurement = Measurement(value: distanceMeters / 1000, unit: UnitLength.kilometers)
            parts.append(Self.distanceFormatter.string(from: measurement))
        }
        return parts.joined(separator: " • ")
    }
}

// MARK: - Composer Form

private struct WorkoutComposer: View {
    @ObservedObject var viewModel: WorkoutsViewModel
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Activity and Category selectors side by side
            HStack(spacing: 12) {
                Picker("", selection: $viewModel.selectedActivityID) {
                    ForEach(viewModel.activities) { activity in
                        Text(activity.name).tag(activity.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)

                if let categories = viewModel.selectedActivity?.categories {
                    Picker("", selection: $viewModel.selectedCategoryID) {
                        ForEach(categories) { category in
                            Text(category.name).tag(category.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .disabled(categories.isEmpty)
                }
            }

            // Duration and Calories
            HStack(spacing: 12) {
                TextField("Duration (min)", text: $viewModel.duration)
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: .infinity)
                TextField("Calories", text: $viewModel.calories)
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: .infinity)
            }

            // Time and Date
            HStack(spacing: 12) {
                DatePicker("", selection: $viewModel.workoutDate, displayedComponents: [.hourAndMinute])
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                DatePicker("", selection: $viewModel.workoutDate, displayedComponents: [.date])
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
            }

            // Dynamic Parameters
            if let parameters = viewModel.selectedCategory?.parameters, !parameters.isEmpty {
                Divider()
                Text("Activity Parameters")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(parameters) { parameter in
                    ParameterInput(parameter: parameter, value: viewModel.binding(for: parameter))
                }
            }

            Button(action: onSubmit) {
                Label("Log Workout", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.makeWorkoutItem() == nil)
        }
    }
}

private struct ParameterInput: View {
    let parameter: WorkoutParameterDefinition
    let value: Binding<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(parameter.name)
                    .font(.subheadline)
                if parameter.required {
                    Text("Required")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            switch parameter.kind {
            case .number:
                TextField(parameter.placeholder, text: value)
                    .keyboardType(.decimalPad)
            case .text:
                TextField(parameter.placeholder, text: value)
            case .options(let options):
                Picker(parameter.name, selection: value) {
                    ForEach(options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

// MARK: - History

private struct WorkoutHistoryList: View {
    let items: [WorkoutLogItem]
    let activities: [WorkoutActivityDefinition]
    let onDelete: (String) -> Void

    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout History")
                .font(.headline)
                .padding(.bottom, 4)

            ForEach(sortedItems) { item in
                WorkoutHistoryRow(item: item,
                                  activityLabel: label(forActivity: item.activity),
                                  categoryLabel: label(forCategory: item.category, activityID: item.activity),
                                  dateText: formattedDate(for: item),
                                  parameterSummary: parameterSummary(for: item)) {
                    onDelete(item.id)
                }
            }
        }
    }

    private var sortedItems: [WorkoutLogItem] {
        items.sorted { $0.datetime > $1.datetime }
    }

    private func formattedDate(for item: WorkoutLogItem) -> String {
        guard let date = isoFormatter.date(from: item.datetime) else { return item.datetime }
        return displayFormatter.string(from: date)
    }

    private func parameterSummary(for item: WorkoutLogItem) -> String {
        item.parameters
            .sorted { $0.key < $1.key }
            .map { key, value in "\(key): \(value.stringValue)" }
            .joined(separator: " • ")
    }

    private func label(forActivity id: String) -> String {
        activities.first(where: { $0.id == id })?.name ?? id
    }

    private func label(forCategory id: String, activityID: String) -> String {
        activities
            .first(where: { $0.id == activityID })?
            .categories
            .first(where: { $0.id == id })?
            .name ?? id
    }
}

private struct WorkoutHistoryRow: View {
    let item: WorkoutLogItem
    let activityLabel: String
    let categoryLabel: String
    let dateText: String
    let parameterSummary: String
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.headline)
                Text("\(activityLabel) • \(categoryLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    Label("\(Int(Double(item.duration) ?? 0)) min", systemImage: "clock")
                        .font(.caption)
                    if let caloriesStr = item.calories, let calories = Double(caloriesStr) {
                        Label("\(Int(calories)) kcal", systemImage: "flame")
                            .font(.caption)
                    }
                    Text(dateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if !parameterSummary.isEmpty {
                    Text(parameterSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }
}

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

    static let defaultActivities: [WorkoutActivityDefinition] = [
        // Cardio & Running
        WorkoutActivityDefinition(
            id: Constants.cardio,
            name: "Cardio & Running",
            categories: [
                WorkoutCategoryDefinition(id: "outdoor-run", name: "Outdoor Run", parameters: [
                    WorkoutParameterDefinition(id: "distance", name: "Distance", kind: .number(unit: "km"), required: true),
                    WorkoutParameterDefinition(id: "pace", name: "Pace", kind: .text(unit: "min/km")),
                    WorkoutParameterDefinition(id: "elevation", name: "Elevation Gain", kind: .number(unit: "m"))
                ]),
                WorkoutCategoryDefinition(id: "indoor-run", name: "Indoor Run (Treadmill)", parameters: [
                    WorkoutParameterDefinition(id: "distance", name: "Distance", kind: .number(unit: "km"), required: true),
                    WorkoutParameterDefinition(id: "incline", name: "Incline", kind: .number(unit: "%")),
                    WorkoutParameterDefinition(id: "speed", name: "Speed", kind: .number(unit: "km/h"))
                ]),
                WorkoutCategoryDefinition(id: "walking", name: "Walking", parameters: [
                    WorkoutParameterDefinition(id: "distance", name: "Distance", kind: .number(unit: "km"), required: true),
                    WorkoutParameterDefinition(id: "steps", name: "Steps", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "terrain", name: "Terrain", kind: .options(["Flat", "Hilly", "Mixed"]))
                ]),
                WorkoutCategoryDefinition(id: "hiking", name: "Hiking", parameters: [
                    WorkoutParameterDefinition(id: "distance", name: "Distance", kind: .number(unit: "km"), required: true),
                    WorkoutParameterDefinition(id: "elevation", name: "Elevation Gain", kind: .number(unit: "m"), required: true),
                    WorkoutParameterDefinition(id: "difficulty", name: "Difficulty", kind: .options(["Easy", "Moderate", "Hard", "Extreme"]))
                ]),
                WorkoutCategoryDefinition(id: "trail-run", name: "Trail Run", parameters: [
                    WorkoutParameterDefinition(id: "distance", name: "Distance", kind: .number(unit: "km"), required: true),
                    WorkoutParameterDefinition(id: "elevation", name: "Elevation Gain", kind: .number(unit: "m")),
                    WorkoutParameterDefinition(id: "difficulty", name: "Technical Difficulty", kind: .options(["Easy", "Moderate", "Hard"]))
                ]),
                WorkoutCategoryDefinition(id: "track-run", name: "Track Run", parameters: [
                    WorkoutParameterDefinition(id: "distance", name: "Distance", kind: .number(unit: "km"), required: true),
                    WorkoutParameterDefinition(id: "laps", name: "Laps", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "splits", name: "Split Times", kind: .text(unit: ""))
                ])
            ]
        ),
        
        // Cycling
        WorkoutActivityDefinition(
            id: Constants.cycling,
            name: "Cycling",
            categories: [
                WorkoutCategoryDefinition(id: "outdoor-cycling", name: "Outdoor Cycling", parameters: [
                    WorkoutParameterDefinition(id: "distance", name: "Distance", kind: .number(unit: "km"), required: true),
                    WorkoutParameterDefinition(id: "avg-speed", name: "Average Speed", kind: .number(unit: "km/h")),
                    WorkoutParameterDefinition(id: "elevation", name: "Elevation Gain", kind: .number(unit: "m")),
                    WorkoutParameterDefinition(id: "terrain", name: "Terrain", kind: .options(["Road", "Mountain", "Mixed"]))
                ]),
                WorkoutCategoryDefinition(id: "indoor-cycling", name: "Indoor Cycling (Spinning)", parameters: [
                    WorkoutParameterDefinition(id: "distance", name: "Distance", kind: .number(unit: "km")),
                    WorkoutParameterDefinition(id: "resistance", name: "Resistance Level", kind: .number(unit: "1-10")),
                    WorkoutParameterDefinition(id: "rpm", name: "RPM", kind: .number(unit: "rpm"))
                ]),
                WorkoutCategoryDefinition(id: "ebike", name: "E-Bike Rides", parameters: [
                    WorkoutParameterDefinition(id: "distance", name: "Distance", kind: .number(unit: "km"), required: true),
                    WorkoutParameterDefinition(id: "battery", name: "Battery Usage", kind: .number(unit: "%")),
                    WorkoutParameterDefinition(id: "assist", name: "Assist Level", kind: .options(["Eco", "Tour", "Sport", "Turbo"]))
                ]),
                WorkoutCategoryDefinition(id: "handcycle", name: "Handcycle", parameters: [
                    WorkoutParameterDefinition(id: "distance", name: "Distance", kind: .number(unit: "km"), required: true),
                    WorkoutParameterDefinition(id: "avg-speed", name: "Average Speed", kind: .number(unit: "km/h")),
                    WorkoutParameterDefinition(id: "terrain", name: "Terrain", kind: .options(["Flat", "Hilly", "Mixed"]))
                ])
            ]
        ),
        
        // Gym & Strength
        WorkoutActivityDefinition(
            id: Constants.gymStrength,
            name: "Gym & Strength",
            categories: [
                WorkoutCategoryDefinition(id: "traditional-strength", name: "Traditional Strength Training", parameters: [
                    WorkoutParameterDefinition(id: "exercises", name: "Exercises", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "sets", name: "Sets", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "reps", name: "Reps", kind: .text(unit: "")),
                    WorkoutParameterDefinition(id: "weight", name: "Weight Lifted", kind: .number(unit: "kg"))
                ]),
                WorkoutCategoryDefinition(id: "functional-strength", name: "Functional Strength Training", parameters: [
                    WorkoutParameterDefinition(id: "exercises", name: "Exercises", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "circuits", name: "Circuits", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "ratio", name: "Work:Rest Ratio", kind: .text(unit: ""))
                ]),
                WorkoutCategoryDefinition(id: "core-training", name: "Core Training", parameters: [
                    WorkoutParameterDefinition(id: "exercises", name: "Exercises", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "hold", name: "Hold Time", kind: .number(unit: "seconds")),
                    WorkoutParameterDefinition(id: "reps", name: "Reps", kind: .text(unit: ""))
                ]),
                WorkoutCategoryDefinition(id: "hiit", name: "High-Intensity Interval Training (HIIT)", parameters: [
                    WorkoutParameterDefinition(id: "work", name: "Work Intervals", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "rest", name: "Rest Intervals", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "ratio", name: "Work:Rest Ratio", kind: .text(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "max-hr", name: "Max Heart Rate", kind: .number(unit: "bpm"))
                ]),
                WorkoutCategoryDefinition(id: "circuit-training", name: "Circuit Training", parameters: [
                    WorkoutParameterDefinition(id: "stations", name: "Stations", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "rounds", name: "Rounds", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "rest", name: "Rest Between Rounds", kind: .number(unit: "min"))
                ]),
                WorkoutCategoryDefinition(id: "flexibility", name: "Flexibility / Mobility", parameters: [
                    WorkoutParameterDefinition(id: "stretches", name: "Stretches", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "hold", name: "Hold Time", kind: .number(unit: "seconds")),
                    WorkoutParameterDefinition(id: "focus", name: "Focus Area", kind: .options(["Full Body", "Upper Body", "Lower Body", "Back", "Hips"]))
                ])
            ]
        ),
        
        // Mind & Body
        WorkoutActivityDefinition(
            id: Constants.mindBody,
            name: "Mind & Body",
            categories: [
                WorkoutCategoryDefinition(id: "yoga", name: "Yoga", parameters: [
                    WorkoutParameterDefinition(id: "style", name: "Style", kind: .options(["Hatha", "Vinyasa", "Ashtanga", "Bikram", "Yin", "Restorative"]), required: true),
                    WorkoutParameterDefinition(id: "poses", name: "Poses", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "focus", name: "Focus", kind: .options(["Flexibility", "Strength", "Balance", "Meditation"]))
                ]),
                WorkoutCategoryDefinition(id: "pilates", name: "Pilates", parameters: [
                    WorkoutParameterDefinition(id: "exercises", name: "Exercises", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "equipment", name: "Equipment", kind: .options(["Mat", "Reformer", "Cadillac", "Chair"])),
                    WorkoutParameterDefinition(id: "focus", name: "Focus", kind: .options(["Core", "Full Body", "Flexibility"]))
                ]),
                WorkoutCategoryDefinition(id: "tai-chi", name: "Tai Chi", parameters: [
                    WorkoutParameterDefinition(id: "forms", name: "Forms", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "style", name: "Style", kind: .options(["Yang", "Chen", "Wu", "Sun"])),
                    WorkoutParameterDefinition(id: "focus", name: "Focus", kind: .options(["Balance", "Meditation", "Movement"]))
                ]),
                WorkoutCategoryDefinition(id: "mindful-cooldown", name: "Mindful Cooldown", parameters: [
                    WorkoutParameterDefinition(id: "breathing", name: "Breathing Exercises", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "meditation", name: "Meditation Time", kind: .number(unit: "min")),
                    WorkoutParameterDefinition(id: "focus", name: "Focus", kind: .options(["Breathing", "Body Scan", "Mindfulness"]))
                ])
            ]
        ),
        
        // Water Sports
        WorkoutActivityDefinition(
            id: Constants.waterSports,
            name: "Water Sports",
            categories: [
                WorkoutCategoryDefinition(id: "pool-swim", name: "Pool Swim", parameters: [
                    WorkoutParameterDefinition(id: "distance", name: "Distance", kind: .number(unit: "m"), required: true),
                    WorkoutParameterDefinition(id: "laps", name: "Laps", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "stroke", name: "Stroke", kind: .options(["Freestyle", "Backstroke", "Breaststroke", "Butterfly", "Mixed"])),
                    WorkoutParameterDefinition(id: "pool-length", name: "Pool Length", kind: .number(unit: "m"))
                ]),
                WorkoutCategoryDefinition(id: "open-water-swim", name: "Open Water Swim", parameters: [
                    WorkoutParameterDefinition(id: "distance", name: "Distance", kind: .number(unit: "km"), required: true),
                    WorkoutParameterDefinition(id: "temp", name: "Water Temperature", kind: .number(unit: "°C")),
                    WorkoutParameterDefinition(id: "conditions", name: "Conditions", kind: .options(["Calm", "Moderate", "Rough"]))
                ]),
                WorkoutCategoryDefinition(id: "surfing", name: "Surfing", parameters: [
                    WorkoutParameterDefinition(id: "waves", name: "Waves Caught", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "height", name: "Wave Height", kind: .number(unit: "ft")),
                    WorkoutParameterDefinition(id: "conditions", name: "Conditions", kind: .options(["Clean", "Choppy", "Mushy"]))
                ]),
                WorkoutCategoryDefinition(id: "paddleboarding", name: "Stand-Up Paddleboarding", parameters: [
                    WorkoutParameterDefinition(id: "distance", name: "Distance", kind: .number(unit: "km"), required: true),
                    WorkoutParameterDefinition(id: "conditions", name: "Water Conditions", kind: .options(["Flat", "Small Waves", "Choppy"])),
                    WorkoutParameterDefinition(id: "board", name: "Board Type", kind: .options(["All-Around", "Touring", "Racing"]))
                ]),
                WorkoutCategoryDefinition(id: "rowing", name: "Rowing", parameters: [
                    WorkoutParameterDefinition(id: "distance", name: "Distance", kind: .number(unit: "m"), required: true),
                    WorkoutParameterDefinition(id: "split", name: "Split Time", kind: .text(unit: "min/500m")),
                    WorkoutParameterDefinition(id: "stroke-rate", name: "Stroke Rate", kind: .number(unit: "spm")),
                    WorkoutParameterDefinition(id: "type", name: "Type", kind: .options(["Indoor", "Outdoor"]))
                ]),
                WorkoutCategoryDefinition(id: "kayaking", name: "Kayaking", parameters: [
                    WorkoutParameterDefinition(id: "distance", name: "Distance", kind: .number(unit: "km"), required: true),
                    WorkoutParameterDefinition(id: "water-type", name: "Water Type", kind: .options(["Lake", "River", "Ocean"])),
                    WorkoutParameterDefinition(id: "difficulty", name: "Difficulty", kind: .options(["Easy", "Moderate", "Advanced"]))
                ])
            ]
        ),
        
        // Winter Sports
        WorkoutActivityDefinition(
            id: Constants.winterSports,
            name: "Winter Sports",
            categories: [
                WorkoutCategoryDefinition(id: "snowboarding", name: "Snowboarding", parameters: [
                    WorkoutParameterDefinition(id: "runs", name: "Runs", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "vertical", name: "Vertical Drop", kind: .number(unit: "m")),
                    WorkoutParameterDefinition(id: "terrain", name: "Terrain", kind: .options(["Groomed", "Powder", "Park", "Backcountry"]))
                ]),
                WorkoutCategoryDefinition(id: "skiing", name: "Skiing", parameters: [
                    WorkoutParameterDefinition(id: "runs", name: "Runs", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "vertical", name: "Vertical Drop", kind: .number(unit: "m")),
                    WorkoutParameterDefinition(id: "terrain", name: "Terrain", kind: .options(["Groomed", "Powder", "Moguls", "Backcountry"]))
                ]),
                WorkoutCategoryDefinition(id: "cross-country-skiing", name: "Cross-Country Skiing", parameters: [
                    WorkoutParameterDefinition(id: "distance", name: "Distance", kind: .number(unit: "km"), required: true),
                    WorkoutParameterDefinition(id: "technique", name: "Technique", kind: .options(["Classic", "Skate", "Mixed"])),
                    WorkoutParameterDefinition(id: "terrain", name: "Terrain", kind: .options(["Flat", "Rolling", "Hilly"]))
                ])
            ]
        ),
        
        // Combat / Mixed Training
        WorkoutActivityDefinition(
            id: Constants.combatMixed,
            name: "Combat / Mixed Training",
            categories: [
                WorkoutCategoryDefinition(id: "boxing", name: "Boxing", parameters: [
                    WorkoutParameterDefinition(id: "rounds", name: "Rounds", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "duration", name: "Round Duration", kind: .number(unit: "min")),
                    WorkoutParameterDefinition(id: "type", name: "Type", kind: .options(["Sparring", "Heavy Bag", "Speed Bag", "Shadow Boxing"]))
                ]),
                WorkoutCategoryDefinition(id: "kickboxing", name: "Kickboxing", parameters: [
                    WorkoutParameterDefinition(id: "rounds", name: "Rounds", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "duration", name: "Round Duration", kind: .number(unit: "min")),
                    WorkoutParameterDefinition(id: "focus", name: "Focus", kind: .options(["Striking", "Kicking", "Combination"]))
                ]),
                WorkoutCategoryDefinition(id: "martial-arts", name: "Martial Arts", parameters: [
                    WorkoutParameterDefinition(id: "style", name: "Style", kind: .options(["Karate", "Taekwondo", "Judo", "Brazilian Jiu-Jitsu", "Muay Thai"]), required: true),
                    WorkoutParameterDefinition(id: "belt", name: "Belt Level", kind: .options(["White", "Yellow", "Orange", "Green", "Blue", "Purple", "Brown", "Black"])),
                    WorkoutParameterDefinition(id: "focus", name: "Focus", kind: .options(["Forms", "Sparring", "Self-Defense", "Fitness"]))
                ]),
                WorkoutCategoryDefinition(id: "dance-cardio", name: "Dance / Cardio Dance", parameters: [
                    WorkoutParameterDefinition(id: "style", name: "Style", kind: .options(["Zumba", "Hip Hop", "Latin", "Jazz", "Contemporary"]), required: true),
                    WorkoutParameterDefinition(id: "choreography", name: "Choreography", kind: .options(["Beginner", "Intermediate", "Advanced"])),
                    WorkoutParameterDefinition(id: "intensity", name: "Intensity", kind: .options(["Low", "Moderate", "High"]))
                ])
            ]
        ),
        
        // Team & Field Sports
        WorkoutActivityDefinition(
            id: Constants.teamField,
            name: "Team & Field Sports",
            categories: [
                WorkoutCategoryDefinition(id: "football", name: "Football", parameters: [
                    WorkoutParameterDefinition(id: "position", name: "Position", kind: .options(["Quarterback", "Running Back", "Wide Receiver", "Defense", "Special Teams"])),
                    WorkoutParameterDefinition(id: "plays", name: "Plays", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "yards", name: "Yards Gained", kind: .number(unit: ""))
                ]),
                WorkoutCategoryDefinition(id: "basketball", name: "Basketball", parameters: [
                    WorkoutParameterDefinition(id: "points", name: "Points Scored", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "rebounds", name: "Rebounds", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "assists", name: "Assists", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "type", name: "Type", kind: .options(["Pickup", "League", "Practice"]))
                ]),
                WorkoutCategoryDefinition(id: "volleyball", name: "Volleyball", parameters: [
                    WorkoutParameterDefinition(id: "sets", name: "Sets Played", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "position", name: "Position", kind: .options(["Setter", "Hitter", "Libero", "Middle Blocker"])),
                    WorkoutParameterDefinition(id: "type", name: "Type", kind: .options(["Indoor", "Beach", "Grass"]))
                ]),
                WorkoutCategoryDefinition(id: "hockey", name: "Hockey", parameters: [
                    WorkoutParameterDefinition(id: "periods", name: "Periods", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "goals", name: "Goals", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "assists", name: "Assists", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "type", name: "Type", kind: .options(["Ice", "Field", "Inline"]))
                ]),
                WorkoutCategoryDefinition(id: "cricket", name: "Cricket", parameters: [
                    WorkoutParameterDefinition(id: "overs", name: "Overs", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "runs", name: "Runs Scored", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "wickets", name: "Wickets Taken", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "format", name: "Format", kind: .options(["Test", "ODI", "T20", "Practice"]))
                ]),
                WorkoutCategoryDefinition(id: "rugby", name: "Rugby", parameters: [
                    WorkoutParameterDefinition(id: "halves", name: "Halves", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "tries", name: "Tries", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "tackles", name: "Tackles", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "type", name: "Type", kind: .options(["Union", "League", "Sevens"]))
                ])
            ]
        ),
        
        // Racket & Precision Sports
        WorkoutActivityDefinition(
            id: Constants.racketPrecision,
            name: "Racket & Precision Sports",
            categories: [
                WorkoutCategoryDefinition(id: "tennis", name: "Tennis", parameters: [
                    WorkoutParameterDefinition(id: "sets", name: "Sets", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "games", name: "Games Won", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "type", name: "Type", kind: .options(["Singles", "Doubles", "Practice"])),
                    WorkoutParameterDefinition(id: "surface", name: "Surface", kind: .options(["Hard Court", "Clay", "Grass", "Indoor"]))
                ]),
                WorkoutCategoryDefinition(id: "badminton", name: "Badminton", parameters: [
                    WorkoutParameterDefinition(id: "games", name: "Games", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "points", name: "Points Scored", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "type", name: "Type", kind: .options(["Singles", "Doubles", "Mixed Doubles"]))
                ]),
                WorkoutCategoryDefinition(id: "table-tennis", name: "Table Tennis", parameters: [
                    WorkoutParameterDefinition(id: "games", name: "Games", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "points", name: "Points Scored", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "type", name: "Type", kind: .options(["Singles", "Doubles"]))
                ]),
                WorkoutCategoryDefinition(id: "golf", name: "Golf", parameters: [
                    WorkoutParameterDefinition(id: "holes", name: "Holes Played", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "score", name: "Score", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "par", name: "Par", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "type", name: "Type", kind: .options(["Full Round", "9 Holes", "Driving Range", "Putting Practice"]))
                ]),
                WorkoutCategoryDefinition(id: "pickleball", name: "Pickleball", parameters: [
                    WorkoutParameterDefinition(id: "games", name: "Games", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "points", name: "Points Scored", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "type", name: "Type", kind: .options(["Singles", "Doubles"]))
                ])
            ]
        ),
        
        // Others
        WorkoutActivityDefinition(
            id: Constants.others,
            name: "Others",
            categories: [
                WorkoutCategoryDefinition(id: Constants.healthKitImport, name: "Imported (Health App)", parameters: [
                    WorkoutParameterDefinition(id: "source", name: "Source", kind: .text(unit: "")),
                    WorkoutParameterDefinition(id: "activity-type", name: "Activity Type", kind: .text(unit: "")),
                    WorkoutParameterDefinition(id: "notes", name: "Notes", kind: .text(unit: ""))
                ]),
                WorkoutCategoryDefinition(id: "dance", name: "Dance", parameters: [
                    WorkoutParameterDefinition(id: "style", name: "Style", kind: .options(["Ballet", "Contemporary", "Hip Hop", "Latin", "Ballroom"]), required: true),
                    WorkoutParameterDefinition(id: "level", name: "Level", kind: .options(["Beginner", "Intermediate", "Advanced"])),
                    WorkoutParameterDefinition(id: "type", name: "Type", kind: .options(["Class", "Performance", "Social"]))
                ]),
                WorkoutCategoryDefinition(id: "fitness-gaming", name: "Fitness Gaming", parameters: [
                    WorkoutParameterDefinition(id: "game", name: "Game", kind: .text(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "level", name: "Level", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "score", name: "Score", kind: .number(unit: "")),
                    WorkoutParameterDefinition(id: "platform", name: "Platform", kind: .options(["Nintendo Switch", "PlayStation", "Xbox", "VR", "Mobile"]))
                ]),
                WorkoutCategoryDefinition(id: "climbing", name: "Climbing", parameters: [
                    WorkoutParameterDefinition(id: "routes", name: "Routes", kind: .number(unit: ""), required: true),
                    WorkoutParameterDefinition(id: "difficulty", name: "Difficulty", kind: .options(["5.0-5.5", "5.6-5.9", "5.10-5.12", "5.13+"])),
                    WorkoutParameterDefinition(id: "type", name: "Type", kind: .options(["Indoor", "Outdoor", "Bouldering"]))
                ])
            ]
        )
    ]
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
        )
    ]
}
