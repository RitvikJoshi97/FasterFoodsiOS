import AppIntents

struct FreeformItemEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Food or workout item")
    )

    static var defaultQuery = FreeformItemQuery()

    let id: String
    let title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: title))
    }

    init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

struct FreeformItemQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [FreeformItemEntity.ID]) async throws -> [FreeformItemEntity] {
        identifiers.map { FreeformItemEntity(id: $0, title: $0) }
    }

    func suggestedEntities() async throws -> [FreeformItemEntity] {
        []
    }

    func entities(matching string: String) async throws -> [FreeformItemEntity] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return [FreeformItemEntity(id: trimmed, title: trimmed)]
    }
}
