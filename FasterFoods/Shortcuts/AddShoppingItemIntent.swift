import AppIntents

struct AddShoppingItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Shopping Item"
    static var description = IntentDescription("Quickly add groceries to any FasterFoods shopping list.")
    static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    static var openAppWhenRun = false

    @Parameter(
        title: "Item",
        requestValueDialog: IntentDialog("What should I add to your FasterFoods shopping list?")
    )
    var itemName: String

    @Parameter(
        title: "Shopping List",
        requestValueDialog: IntentDialog("Which FasterFoods list should I use?")
    )
    var list: ShoppingListEntity?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = ShoppingListIntentService()
        let outcome = try await service.addItem(named: itemName, listId: list?.id)

        return .result(dialog: IntentDialog("\(outcome.itemName) was added to \(outcome.listName)."))
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$itemName) to \(\.$list)")
    }
}
