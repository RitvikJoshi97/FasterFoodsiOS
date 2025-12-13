import AppIntents

struct AddWorkoutItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Workout Log"
    static var description = IntentDescription("Log a workout directly to FasterFoods.")
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    static var openAppWhenRun = false

    @Parameter(
        title: "Workout",
        requestValueDialog: IntentDialog("What workout did you do?")
    )
    var itemName: FreeformItemEntity

    @Parameter(
        title: "Duration (minutes)",
        default: 30,
        requestValueDialog: IntentDialog("How long was it?")
    )
    var durationMinutes: Int

    @Parameter(
        title: "Calories (optional)",
        default: nil,
        requestValueDialog: IntentDialog("How many calories did you burn?")
    )
    var calories: Int?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = WorkoutIntentService()
        let result = try await service.addWorkout(
            named: itemName.title,
            durationMinutes: durationMinutes,
            calories: calories
        )

        let minutesText =
            result.durationMinutes == 1
            ? "1 minute"
            : "\(result.durationMinutes) minutes"

        return .result(
            dialog: IntentDialog("\(result.itemName) logged for \(minutesText).")
        )
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$itemName) for \(\.$durationMinutes) minutes") {
            \.$calories
        }
    }
}
