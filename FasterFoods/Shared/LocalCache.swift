import Foundation

struct CachedSnapshot: Codable {
    let schemaVersion: Int
    let cachedAt: Date
    var user: User?
    var settings: UserSettings?
    var pantryItems: [PantryItem]
    var shoppingLists: [ShoppingList]
    var foodLogItems: [FoodLogItem]
    var workoutItems: [WorkoutLogItem]
    var customMetrics: [CustomMetric]

    init(
        schemaVersion: Int = 1,
        cachedAt: Date = Date(),
        user: User? = nil,
        settings: UserSettings? = nil,
        pantryItems: [PantryItem] = [],
        shoppingLists: [ShoppingList] = [],
        foodLogItems: [FoodLogItem] = [],
        workoutItems: [WorkoutLogItem] = [],
        customMetrics: [CustomMetric] = []
    ) {
        self.schemaVersion = schemaVersion
        self.cachedAt = cachedAt
        self.user = user
        self.settings = settings
        self.pantryItems = pantryItems
        self.shoppingLists = shoppingLists
        self.foodLogItems = foodLogItems
        self.workoutItems = workoutItems
        self.customMetrics = customMetrics
    }
}

actor LocalCache {
    static let shared = LocalCache()

    private let fileName = "offline_snapshot.json"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager = FileManager.default

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadSnapshot() -> CachedSnapshot? {
        let url = cacheURL()
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(CachedSnapshot.self, from: data)
    }

    func saveSnapshot(_ snapshot: CachedSnapshot) {
        let url = cacheURL()
        do {
            let directory = url.deletingLastPathComponent()
            try fileManager.createDirectory(
                at: directory, withIntermediateDirectories: true, attributes: nil)
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("⚠️ Failed to save offline cache: \(error)")
        }
    }

    func clear() {
        let url = cacheURL()
        do {
            try fileManager.removeItem(at: url)
        } catch {
            // ignore missing cache
        }
    }

    private func cacheURL() -> URL {
        if let url = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: SharedContainer.identifier)
        {
            return
                url
                .appendingPathComponent("OfflineCache", isDirectory: true)
                .appendingPathComponent(fileName)
        }

        let base =
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return
            base
            .appendingPathComponent("OfflineCache", isDirectory: true)
            .appendingPathComponent(fileName)
    }
}
