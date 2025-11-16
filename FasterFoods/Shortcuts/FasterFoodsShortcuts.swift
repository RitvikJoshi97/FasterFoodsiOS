import AppIntents

struct FasterFoodsShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .purple

    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddShoppingItemIntent(),
            phrases: [
                "${applicationName} add {itemName} to my shopping list"
            ],
            shortTitle: "Add Shopping Item",
            systemImageName: "cart.badge.plus"
        )

        AppShortcut(
            intent: AddShoppingItemIntent(),
            phrases: [
                "Add {itemName} to my shopping list in ${applicationName}"
            ],
            shortTitle: "Shopping List Item",
            systemImageName: "cart.badge.plus"
        )

        AppShortcut(
            intent: AddShoppingItemIntent(),
            phrases: [
                "In ${applicationName}, add {itemName} to my shopping list"
            ],
            shortTitle: "Use Shopping Shortcut",
            systemImageName: "cart.badge.plus"
        )
    }
}
