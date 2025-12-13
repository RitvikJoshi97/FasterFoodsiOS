import AppIntents

struct FasterFoodsShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .purple

    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddShoppingItemIntent(),
            phrases: [
                "Add ${itemName} to my shopping list on ${applicationName}"
            ],
            shortTitle: "Add to Shopping Item",
            systemImageName: "cart.badge.plus"
        )

        AppShortcut(
            intent: AddFoodLogIntent(),
            phrases: [
                "Add ${itemName} to my food log on ${applicationName}",
                "${applicationName} add ${itemName} to my food log",
                "In ${applicationName}, add ${itemName} to my food log",
                "Log ${itemName} in my food log with ${applicationName}",
            ],
            shortTitle: "Add to Food Log",
            systemImageName: "fork.knife.circle"
        )

        AppShortcut(
            intent: AddWorkoutItemIntent(),
            phrases: [
                "Add ${itemName} to my workout log on ${applicationName}",
                "${applicationName} add ${itemName} to my workout log",
                "In ${applicationName}, add ${itemName} to my workout log",
                "Log ${itemName} in my workout log with ${applicationName}",
            ],
            shortTitle: "Add to Workout",
            systemImageName: "figure.run.circle"
        )
    }
}
