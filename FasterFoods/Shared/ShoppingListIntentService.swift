import Foundation

enum ShoppingIntentError: LocalizedError {
    case unauthenticated
    case missingItemName
    case shoppingListNotFound

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "Please log in to FasterFoods, then try again."
        case .missingItemName:
            return "I couldn't work out what to add. Please say the item name."
        case .shoppingListNotFound:
            return "That shopping list no longer exists. Pick another one and try again."
        }
    }
}

struct ShoppingIntentResult {
    let itemName: String
    let listName: String
}

actor ShoppingListIntentService {
    func addItem(named rawName: String, listId: String?) async throws -> ShoppingIntentResult {
        #if DEBUG
        print("🔈 Intent addItem called:", rawName, listId ?? "nil")
        #endif
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw ShoppingIntentError.missingItemName }

        let lists = try await availableLists()
        let targetList: ShoppingList

        if let listId, !listId.isEmpty {
            guard let match = lists.first(where: { $0.id == listId }) else {
                throw ShoppingIntentError.shoppingListNotFound
            }
            targetList = match
        } else if let first = lists.first {
            targetList = first
        } else {
            targetList = try await performWithAuthHandling {
                try await APIClient.shared.createShoppingList(name: "Default")
            }
        }

        try await performWithAuthHandling {
            _ = try await APIClient.shared.addShoppingItem(
                toList: targetList.id,
                name: trimmedName
            )
        }

        #if DEBUG
        print("✅ Intent added:", trimmedName, "to", targetList.name)
        #endif

        return ShoppingIntentResult(itemName: trimmedName, listName: targetList.name)
    }

    func availableLists() async throws -> [ShoppingList] {
        try await performWithAuthHandling {
            try await APIClient.shared.getShoppingLists()
        }
    }

    private func performWithAuthHandling<T>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch {
            #if DEBUG
            print("❌ Intent error:", error.localizedDescription)
            #endif
            if let apiError = error as? APIError,
               apiError.statusCode == 401 {
                throw ShoppingIntentError.unauthenticated
            }
            throw error
        }
    }
}
