import AppIntents

struct ShoppingListEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Shopping List")
    )

    static var defaultQuery = ShoppingListQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: name)
        )
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    init(_ list: ShoppingList) {
        self.init(id: list.id, name: list.name)
    }
}

struct ShoppingListQuery: EntityQuery {
    func entities(for identifiers: [ShoppingListEntity.ID]) async throws -> [ShoppingListEntity] {
        let lists = try await fetchLists()
        return lists.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ShoppingListEntity] {
        try await fetchLists()
    }

    private func fetchLists() async throws -> [ShoppingListEntity] {
        let service = ShoppingListIntentService()
        let lists = try await service.availableLists()
        return lists.map(ShoppingListEntity.init)
    }
}
