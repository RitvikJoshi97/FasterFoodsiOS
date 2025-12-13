import AppIntents

struct AddFoodLogIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Food Log Item"
    static var description = IntentDescription(
        "Quickly add a meal or food to your FasterFoods log.")
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    static var openAppWhenRun = false

    @Parameter(
        title: "Food or Meal",
        requestValueDialog: IntentDialog("What should I log to your FasterFoods food log?")
    )
    var itemName: FreeformItemEntity

    @Parameter(
        title: "Calories (optional)",
        default: nil,
        requestValueDialog: IntentDialog("How many calories was it?")
    )
    var calories: Int?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = FoodLogIntentService()
        let result = try await service.addItem(
            named: itemName.title,
            calories: calories.map(String.init)
        )

        return .result(
            dialog: IntentDialog("\(result.itemName) was logged for \(result.mealName).")
        )
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$itemName)") {
            \.$calories
        }
    }
}
