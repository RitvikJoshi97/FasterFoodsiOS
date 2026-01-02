import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let firstName: String
    let lastName: String
    let email: String
    let role: String
    let plan: String
    let avatarUrl: String?
}

enum ThemePreference: String, Codable, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }
    var label: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum UnitSystem: String, Codable, CaseIterable, Identifiable {
    case imperial
    case metric

    var id: String { rawValue }
    var label: String {
        switch self {
        case .imperial: return "Imperial"
        case .metric: return "Metric"
        }
    }
}

struct UserSettings: Codable {
    var theme: ThemePreference
    var unitSystem: UnitSystem
    var notificationsEnabled: Bool
    var language: String
    var foodLoggingLevel: FoodLoggingLevel

    enum CodingKeys: String, CodingKey {
        case theme
        case unitSystem
        case notificationsEnabled
        case language
        case foodLoggingLevel
        case darkMode
    }

    init(
        theme: ThemePreference = .light,
        unitSystem: UnitSystem = .imperial,
        notificationsEnabled: Bool = true,
        language: String = "en",
        foodLoggingLevel: FoodLoggingLevel = .beginner
    ) {
        self.theme = theme
        self.unitSystem = unitSystem
        self.notificationsEnabled = notificationsEnabled
        self.language = language
        self.foodLoggingLevel = foodLoggingLevel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let explicitTheme = try container.decodeIfPresent(String.self, forKey: .theme),
            let resolvedTheme = ThemePreference(rawValue: explicitTheme)
        {
            theme = resolvedTheme
        } else if let legacyDarkMode = try container.decodeIfPresent(Bool.self, forKey: .darkMode) {
            theme = legacyDarkMode ? .dark : .light
        } else {
            theme = .light
        }

        if let rawUnit = try container.decodeIfPresent(String.self, forKey: .unitSystem),
            let resolvedUnit = UnitSystem(rawValue: rawUnit)
        {
            unitSystem = resolvedUnit
        } else {
            unitSystem = .imperial
        }

        notificationsEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        language = try container.decodeIfPresent(String.self, forKey: .language) ?? "en"

        if let rawLevel = try container.decodeIfPresent(String.self, forKey: .foodLoggingLevel),
            let level = FoodLoggingLevel(rawValue: rawLevel)
        {
            foodLoggingLevel = level
        } else {
            foodLoggingLevel = .beginner
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(theme.rawValue, forKey: .theme)
        try container.encode(unitSystem.rawValue, forKey: .unitSystem)
        try container.encode(notificationsEnabled, forKey: .notificationsEnabled)
        try container.encode(language, forKey: .language)
        try container.encode(foodLoggingLevel.rawValue, forKey: .foodLoggingLevel)
    }
}

struct LoginPopup: Codable {
    let showPopup: Bool
    let popupMessage: String
    let popupType: String?
}

struct LoginResponse: Codable {
    let token: String
    let firstName: String
    let lastName: String
    let lastLogin: String?
    let settings: UserSettings?
    let showPopup: Bool
    let popupMessage: String
    let popupType: String?
}

struct GroceryItem: Codable, Identifiable {
    let id: Int
    let item: String
    let macros: [String: DoubleOrString]
    let userId: Int
    let createdAt: String
}

struct ProcessedItem: Codable, Identifiable {
    let id: Int
    let userId: Int
    let type: String
    let item: String
    let macros: [String: DoubleOrString]?
    let nutritionInfo: [String: DoubleOrString]?
    let createdAt: String
}

struct SharedItem: Codable, Identifiable {
    let id: Int
    let originalItemId: Int
    let sharedByUserId: Int?
    let sharedToUserId: Int?
    let item: String
    let macros: [String: DoubleOrString]
    let verified: Bool
    let createdAt: String
}

struct FamilyMember: Codable, Identifiable {
    let id: Int
    let firstName: String
    let lastName: String
    let email: String
    let avatarUrl: String?
}

struct FamilyMembersResponse: Codable {
    let familyMembers: [FamilyMember]
}

struct SharedItemsResponse: Codable {
    let sharedItems: [SharedItem]
}

struct ShoppingList: Codable, Identifiable {
    let id: String
    var name: String
    var userId: Int?
    var items: [ShoppingItem]
    var createdAt: String?
    var updatedAt: String?

    init(
        id: String, name: String, userId: Int? = nil, items: [ShoppingItem] = [],
        createdAt: String? = nil, updatedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.userId = userId
        self.items = items
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case userId
        case items
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Untitled List"
        self.userId = try container.decodeIfPresent(Int.self, forKey: .userId)
        self.items = try container.decodeIfPresent([ShoppingItem].self, forKey: .items) ?? []
        self.createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        self.updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encode(items, forKey: .items)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

struct ShoppingItem: Codable, Identifiable {
    let id: String
    var name: String
    var quantity: String?
    var unit: String?
    var list: String?
    var checked: Bool
    var addedAt: Double?
    var checkedAt: Double?
    var shoppingListId: String?
    var createdAt: String?
    var updatedAt: String?

    init(
        id: String, name: String, quantity: String? = nil, unit: String? = nil, list: String? = nil,
        checked: Bool = false, addedAt: Double? = nil, checkedAt: Double? = nil,
        shoppingListId: String? = nil, createdAt: String? = nil, updatedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.list = list
        self.checked = checked
        self.addedAt = addedAt
        self.checkedAt = checkedAt
        self.shoppingListId = shoppingListId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case quantity
        case unit
        case list
        case checked
        case addedAt
        case checkedAt
        case shoppingListId
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Item"
        self.quantity = container.decodeFlexibleOptionalString(forKey: .quantity)
        self.unit = container.decodeFlexibleOptionalString(forKey: .unit)
        self.list = container.decodeFlexibleOptionalString(forKey: .list)
        self.checked = container.decodeFlexibleBool(forKey: .checked) ?? false
        self.addedAt = container.decodeFlexibleDouble(forKey: .addedAt)
        self.checkedAt = container.decodeFlexibleDouble(forKey: .checkedAt)
        self.shoppingListId = container.decodeFlexibleOptionalString(forKey: .shoppingListId)
        self.createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        self.updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(quantity, forKey: .quantity)
        try container.encodeIfPresent(unit, forKey: .unit)
        try container.encodeIfPresent(list, forKey: .list)
        try container.encode(checked, forKey: .checked)
        try container.encodeIfPresent(addedAt, forKey: .addedAt)
        try container.encodeIfPresent(checkedAt, forKey: .checkedAt)
        try container.encodeIfPresent(shoppingListId, forKey: .shoppingListId)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

struct PantryItem: Codable, Identifiable {
    let id: String
    var name: String
    var quantity: String?
    var unit: String?
    var expiryDate: String?
    var addedOn: String?
    var checked: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case quantity
        case unit
        case expiryDate
        case addedOn
        case checked
    }

    init(
        id: String, name: String, quantity: String? = nil, unit: String? = nil,
        expiryDate: String? = nil, addedOn: String? = nil, checked: Bool = false
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.expiryDate = expiryDate
        self.addedOn = addedOn
        self.checked = checked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id)
        self.name = container.decodeFlexibleOptionalString(forKey: .name) ?? "Item"
        self.quantity = container.decodeFlexibleOptionalString(forKey: .quantity)
        self.unit = container.decodeFlexibleOptionalString(forKey: .unit)
        self.expiryDate = container.decodeFlexibleOptionalString(forKey: .expiryDate)
        self.addedOn = container.decodeFlexibleOptionalString(forKey: .addedOn)
        self.checked = container.decodeFlexibleBool(forKey: .checked) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(quantity, forKey: .quantity)
        try container.encodeIfPresent(unit, forKey: .unit)
        try container.encodeIfPresent(expiryDate, forKey: .expiryDate)
        try container.encodeIfPresent(addedOn, forKey: .addedOn)
        try container.encode(checked, forKey: .checked)
    }
}

enum FoodLoggingLevel: String, Codable, CaseIterable {
    case beginner
    case intermediate
    case advanced
}

struct FoodLogItem: Codable, Identifiable {
    let id: String
    var name: String
    var meal: String
    var calories: String?
    var carbohydrates: String?
    var datetime: String
    var loggingLevel: FoodLoggingLevel
    var portionSize: String?
    var mealTime: String?
    var mood: String?
    var protein: String?
    var fat: String?
    var mealCategory: String?
    var digestionFeedback: String?
    var hydration: String?
    var hungerFullness: Int?
    var hungerSatisfaction: String?
    var physicalEmptiness: String?
    var couldEatMore: String?
    var stomachSensations: String?
    var chestThroatSensations: String?
    var headSensations: String?
    var overallBodySensations: String?
    var muscleTone: String?
    var energyLevel: String?
    var breathingChanges: String?
    var postureDesire: String?
    var emotionsAfterEating: String?
    var emotionLocation: String?
    var memoriesThoughts: String?
    var tasteEnjoyment: String?
    var lingeringTaste: String?
    var bodySatisfaction: String?
    var digestiveSensations: String?
    var digestionComfort: String?
    var energyChanges: String?
    var bodySignals: String?
    var mindBodyConnection: String?
    var relationshipWithFood: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case meal
        case calories
        case carbohydrates
        case datetime
        case loggingLevel
        case portionSize
        case mealTime
        case mood
        case protein
        case fat
        case mealCategory
        case digestionFeedback
        case hydration
        case hungerFullness
        case hungerSatisfaction
        case physicalEmptiness
        case couldEatMore
        case stomachSensations
        case chestThroatSensations
        case headSensations
        case overallBodySensations
        case muscleTone
        case energyLevel
        case breathingChanges
        case postureDesire
        case emotionsAfterEating
        case emotionLocation
        case memoriesThoughts
        case tasteEnjoyment
        case lingeringTaste
        case bodySatisfaction
        case digestiveSensations
        case digestionComfort
        case energyChanges
        case bodySignals
        case mindBodyConnection
        case relationshipWithFood
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id)
        name = container.decodeFlexibleOptionalString(forKey: .name) ?? "Meal"
        meal = container.decodeFlexibleOptionalString(forKey: .meal) ?? "meal"
        calories = container.decodeFlexibleOptionalString(forKey: .calories)
        carbohydrates = container.decodeFlexibleOptionalString(forKey: .carbohydrates)
        datetime =
            container.decodeFlexibleOptionalString(forKey: .datetime)
            ?? ISO8601DateFormatter().string(from: Date())
        loggingLevel =
            (try? container.decode(FoodLoggingLevel.self, forKey: .loggingLevel)) ?? .beginner
        portionSize = container.decodeFlexibleOptionalString(forKey: .portionSize)
        mealTime = container.decodeFlexibleOptionalString(forKey: .mealTime)
        mood = container.decodeFlexibleOptionalString(forKey: .mood)
        protein = container.decodeFlexibleOptionalString(forKey: .protein)
        fat = container.decodeFlexibleOptionalString(forKey: .fat)
        mealCategory = container.decodeFlexibleOptionalString(forKey: .mealCategory)
        digestionFeedback = container.decodeFlexibleOptionalString(forKey: .digestionFeedback)
        hydration = container.decodeFlexibleOptionalString(forKey: .hydration)
        hungerFullness = container.decodeFlexibleDouble(forKey: .hungerFullness).flatMap { Int($0) }
        hungerSatisfaction = container.decodeFlexibleOptionalString(forKey: .hungerSatisfaction)
        physicalEmptiness = container.decodeFlexibleOptionalString(forKey: .physicalEmptiness)
        couldEatMore = container.decodeFlexibleOptionalString(forKey: .couldEatMore)
        stomachSensations = container.decodeFlexibleOptionalString(forKey: .stomachSensations)
        chestThroatSensations = container.decodeFlexibleOptionalString(
            forKey: .chestThroatSensations)
        headSensations = container.decodeFlexibleOptionalString(forKey: .headSensations)
        overallBodySensations = container.decodeFlexibleOptionalString(
            forKey: .overallBodySensations)
        muscleTone = container.decodeFlexibleOptionalString(forKey: .muscleTone)
        energyLevel = container.decodeFlexibleOptionalString(forKey: .energyLevel)
        breathingChanges = container.decodeFlexibleOptionalString(forKey: .breathingChanges)
        postureDesire = container.decodeFlexibleOptionalString(forKey: .postureDesire)
        emotionsAfterEating = container.decodeFlexibleOptionalString(forKey: .emotionsAfterEating)
        emotionLocation = container.decodeFlexibleOptionalString(forKey: .emotionLocation)
        memoriesThoughts = container.decodeFlexibleOptionalString(forKey: .memoriesThoughts)
        tasteEnjoyment = container.decodeFlexibleOptionalString(forKey: .tasteEnjoyment)
        lingeringTaste = container.decodeFlexibleOptionalString(forKey: .lingeringTaste)
        bodySatisfaction = container.decodeFlexibleOptionalString(forKey: .bodySatisfaction)
        digestiveSensations = container.decodeFlexibleOptionalString(forKey: .digestiveSensations)
        digestionComfort = container.decodeFlexibleOptionalString(forKey: .digestionComfort)
        energyChanges = container.decodeFlexibleOptionalString(forKey: .energyChanges)
        bodySignals = container.decodeFlexibleOptionalString(forKey: .bodySignals)
        mindBodyConnection = container.decodeFlexibleOptionalString(forKey: .mindBodyConnection)
        relationshipWithFood = container.decodeFlexibleOptionalString(forKey: .relationshipWithFood)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(meal, forKey: .meal)
        try container.encodeIfPresent(calories, forKey: .calories)
        try container.encodeIfPresent(carbohydrates, forKey: .carbohydrates)
        try container.encode(datetime, forKey: .datetime)
        try container.encode(loggingLevel, forKey: .loggingLevel)
        try container.encodeIfPresent(portionSize, forKey: .portionSize)
        try container.encodeIfPresent(mealTime, forKey: .mealTime)
        try container.encodeIfPresent(mood, forKey: .mood)
        try container.encodeIfPresent(protein, forKey: .protein)
        try container.encodeIfPresent(fat, forKey: .fat)
        try container.encodeIfPresent(mealCategory, forKey: .mealCategory)
        try container.encodeIfPresent(digestionFeedback, forKey: .digestionFeedback)
        try container.encodeIfPresent(hydration, forKey: .hydration)
        try container.encodeIfPresent(hungerFullness, forKey: .hungerFullness)
        try container.encodeIfPresent(hungerSatisfaction, forKey: .hungerSatisfaction)
        try container.encodeIfPresent(physicalEmptiness, forKey: .physicalEmptiness)
        try container.encodeIfPresent(couldEatMore, forKey: .couldEatMore)
        try container.encodeIfPresent(stomachSensations, forKey: .stomachSensations)
        try container.encodeIfPresent(chestThroatSensations, forKey: .chestThroatSensations)
        try container.encodeIfPresent(headSensations, forKey: .headSensations)
        try container.encodeIfPresent(overallBodySensations, forKey: .overallBodySensations)
        try container.encodeIfPresent(muscleTone, forKey: .muscleTone)
        try container.encodeIfPresent(energyLevel, forKey: .energyLevel)
        try container.encodeIfPresent(breathingChanges, forKey: .breathingChanges)
        try container.encodeIfPresent(postureDesire, forKey: .postureDesire)
        try container.encodeIfPresent(emotionsAfterEating, forKey: .emotionsAfterEating)
        try container.encodeIfPresent(emotionLocation, forKey: .emotionLocation)
        try container.encodeIfPresent(memoriesThoughts, forKey: .memoriesThoughts)
        try container.encodeIfPresent(tasteEnjoyment, forKey: .tasteEnjoyment)
        try container.encodeIfPresent(lingeringTaste, forKey: .lingeringTaste)
        try container.encodeIfPresent(bodySatisfaction, forKey: .bodySatisfaction)
        try container.encodeIfPresent(digestiveSensations, forKey: .digestiveSensations)
        try container.encodeIfPresent(digestionComfort, forKey: .digestionComfort)
        try container.encodeIfPresent(energyChanges, forKey: .energyChanges)
        try container.encodeIfPresent(bodySignals, forKey: .bodySignals)
        try container.encodeIfPresent(mindBodyConnection, forKey: .mindBodyConnection)
        try container.encodeIfPresent(relationshipWithFood, forKey: .relationshipWithFood)
    }
}

struct FoodLogIngredient: Codable, Identifiable, Hashable {
    let id: String
    let barcode: String?
    let itemName: String
    let quantity: String?
    let unit: String?

    enum CodingKeys: String, CodingKey {
        case id
        case barcode
        case itemName
        case name
        case quantity
        case unit
    }

    init(
        id: String, barcode: String? = nil, itemName: String, quantity: String? = nil,
        unit: String? = nil
    ) {
        self.id = id
        self.barcode = barcode
        self.itemName = itemName
        self.quantity = quantity
        self.unit = unit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let idValue = try? container.decodeFlexibleString(forKey: .id) {
            id = idValue
        } else {
            id = UUID().uuidString
        }
        barcode = container.decodeFlexibleOptionalString(forKey: .barcode)
        itemName =
            container.decodeFlexibleOptionalString(forKey: .itemName)
            ?? container.decodeFlexibleOptionalString(forKey: .name)
            ?? "Ingredient"
        quantity = container.decodeFlexibleOptionalString(forKey: .quantity)
        unit = container.decodeFlexibleOptionalString(forKey: .unit)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(barcode, forKey: .barcode)
        try container.encode(itemName, forKey: .itemName)
        try container.encodeIfPresent(quantity, forKey: .quantity)
        try container.encodeIfPresent(unit, forKey: .unit)
    }
}

struct FoodLogIngredientCreateRequest: Codable, Hashable {
    var barcode: Int64?
    var itemName: String
    var quantity: String?
    var unit: String?
}

struct FoodLogCreateRequest: Codable {
    var name: String
    var meal: String
    var calories: String?
    var carbohydrates: String?
    var datetime: String
    var loggingLevel: FoodLoggingLevel
    var portionSize: String?
    var mealTime: String?
    var mood: String?
    var protein: String?
    var fat: String?
    var mealCategory: String?
    var digestionFeedback: String?
    var hydration: String?
    var hungerFullness: Int?
    var hungerSatisfaction: String?
    var physicalEmptiness: String?
    var couldEatMore: String?
    var stomachSensations: String?
    var chestThroatSensations: String?
    var headSensations: String?
    var overallBodySensations: String?
    var muscleTone: String?
    var energyLevel: String?
    var breathingChanges: String?
    var postureDesire: String?
    var emotionsAfterEating: String?
    var emotionLocation: String?
    var memoriesThoughts: String?
    var tasteEnjoyment: String?
    var lingeringTaste: String?
    var bodySatisfaction: String?
    var digestiveSensations: String?
    var digestionComfort: String?
    var energyChanges: String?
    var bodySignals: String?
    var mindBodyConnection: String?
    var relationshipWithFood: String?
}

struct FoodLogResponse: Codable {
    let items: [FoodLogItem]

    enum CodingKeys: String, CodingKey {
        case items
    }

    init(items: [FoodLogItem]) {
        self.items = items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.items = try container.decodeIfPresent([FoodLogItem].self, forKey: .items) ?? []
    }
}

extension FoodLogItem {
    init(id: String = UUID().uuidString, request: FoodLogCreateRequest) {
        self.id = id
        self.name = request.name
        self.meal = request.meal
        self.calories = request.calories
        self.carbohydrates = request.carbohydrates
        self.datetime = request.datetime
        self.loggingLevel = request.loggingLevel
        self.portionSize = request.portionSize
        self.mealTime = request.mealTime
        self.mood = request.mood
        self.protein = request.protein
        self.fat = request.fat
        self.mealCategory = request.mealCategory
        self.digestionFeedback = request.digestionFeedback
        self.hydration = request.hydration
        self.hungerFullness = request.hungerFullness
        self.hungerSatisfaction = request.hungerSatisfaction
        self.physicalEmptiness = request.physicalEmptiness
        self.couldEatMore = request.couldEatMore
        self.stomachSensations = request.stomachSensations
        self.chestThroatSensations = request.chestThroatSensations
        self.headSensations = request.headSensations
        self.overallBodySensations = request.overallBodySensations
        self.muscleTone = request.muscleTone
        self.energyLevel = request.energyLevel
        self.breathingChanges = request.breathingChanges
        self.postureDesire = request.postureDesire
        self.emotionsAfterEating = request.emotionsAfterEating
        self.emotionLocation = request.emotionLocation
        self.memoriesThoughts = request.memoriesThoughts
        self.tasteEnjoyment = request.tasteEnjoyment
        self.lingeringTaste = request.lingeringTaste
        self.bodySatisfaction = request.bodySatisfaction
        self.digestiveSensations = request.digestiveSensations
        self.digestionComfort = request.digestionComfort
        self.energyChanges = request.energyChanges
        self.bodySignals = request.bodySignals
        self.mindBodyConnection = request.mindBodyConnection
        self.relationshipWithFood = request.relationshipWithFood
    }
}

struct WorkoutLogItem: Codable, Identifiable {
    let id: String
    var name: String
    var activity: String
    var category: String
    var duration: String
    var calories: String?
    var parameters: [String: AnyCodableValue]
    var datetime: String
    var userId: Int?
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, activity, category, duration, calories, parameters, datetime, userId,
            createdAt, updatedAt
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        activity: String,
        category: String,
        duration: String,
        calories: String? = nil,
        parameters: [String: AnyCodableValue] = [:],
        datetime: String,
        userId: Int? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.activity = activity
        self.category = category
        self.duration = duration
        self.calories = calories
        self.parameters = parameters
        self.datetime = datetime
        self.userId = userId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// Helper to decode parameters with mixed types
enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: AnyCodableValue])
    case array([AnyCodableValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let object = try? container.decode([String: AnyCodableValue].self) {
            self = .object(object)
        } else if let array = try? container.decode([AnyCodableValue].self) {
            self = .array(array)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String {
        switch self {
        case .string(let value): return value
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        case .bool(let value): return String(value)
        case .object, .array, .null:
            if let data = try? JSONSerialization.data(withJSONObject: jsonValue, options: []),
                let string = String(data: data, encoding: .utf8)
            {
                return string
            }
            return ""
        }
    }

    var jsonValue: Any {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .bool(let value):
            return value
        case .object(let value):
            return value.mapValues { $0.jsonValue }
        case .array(let value):
            return value.map { $0.jsonValue }
        case .null:
            return NSNull()
        }
    }
}

struct WorkoutCreateRequest: Codable {
    var name: String
    var activity: String
    var category: String
    var duration: String
    var calories: String?
    var parameters: [String: AnyCodableValue]
    var datetime: String
}

struct CustomMetric: Codable, Identifiable {
    let id: String
    var name: String
    var value: String
    var unit: String
    var date: String
    var metricType: String
    var userId: Int?
    var createdAt: String?
    var updatedAt: String?

    init(
        id: String = UUID().uuidString,
        name: String,
        value: String,
        unit: String,
        date: String,
        metricType: String,
        userId: Int? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
        self.date = date
        self.metricType = metricType
        self.userId = userId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
struct ShoppingRecommendation: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let intent: String?
    let metadata: [String: String]?
    let context: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case intent
        case metadata
        case context
    }

    init(
        id: String, title: String, description: String, intent: String? = nil,
        metadata: [String: String]? = nil, context: [String: String]? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.intent = intent
        self.metadata = metadata
        self.context = context
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id)
        self.title = container.decodeFlexibleOptionalString(forKey: .title) ?? ""
        self.description = container.decodeFlexibleOptionalString(forKey: .description) ?? ""
        self.intent = container.decodeFlexibleOptionalString(forKey: .intent)
        self.metadata = try? container.decode([String: String].self, forKey: .metadata)
        self.context = try? container.decode([String: String].self, forKey: .context)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(intent, forKey: .intent)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfPresent(context, forKey: .context)
    }
}

struct ShoppingRecommendationEnvelope: Codable {
    let recommendations: [ShoppingRecommendation]?
    let data: [ShoppingRecommendation]?
}

// MARK: - Goal Models
struct Goal: Codable, Identifiable {
    let id: String
    let description: String
    let title: String?
    let source: String?
    let spec: [String: String]?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case description
        case title
        case source
        case spec
        case createdAt
        case updatedAt
    }

    init(
        id: String, description: String, title: String? = nil, source: String? = nil,
        spec: [String: String]? = nil, createdAt: String? = nil, updatedAt: String? = nil
    ) {
        self.id = id
        self.description = description
        self.title = title
        self.source = source
        self.spec = spec
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeFlexibleString(forKey: .id)
        self.description = container.decodeFlexibleOptionalString(forKey: .description) ?? ""
        self.title = container.decodeFlexibleOptionalString(forKey: .title)
        self.source = container.decodeFlexibleOptionalString(forKey: .source)
        self.spec = try? container.decode([String: String].self, forKey: .spec)
        self.createdAt = container.decodeFlexibleOptionalString(forKey: .createdAt)
        self.updatedAt = container.decodeFlexibleOptionalString(forKey: .updatedAt)
    }
}

struct GoalRecommendation: Codable, Identifiable {
    let id: String
    let title: String?
    let description: String
    let intent: String?
    let usageCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case intent
        case usageCount
    }

    init(
        id: String? = nil, title: String? = nil, description: String, intent: String? = nil,
        usageCount: Int? = nil
    ) {
        self.id = id ?? (title ?? description)
        self.title = title
        self.description = description
        self.intent = intent
        self.usageCount = usageCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let decodedTitle = try container.decodeIfPresent(String.self, forKey: .title)
        let decodedDescription =
            try container.decodeIfPresent(String.self, forKey: .description)
            ?? decodedTitle
            ?? ""
        let decodedId = try container.decodeIfPresent(String.self, forKey: .id)
        let decodedIntent = try container.decodeIfPresent(String.self, forKey: .intent)
        let decodedUsageCount = try container.decodeIfPresent(Int.self, forKey: .usageCount)

        // Ensure id is always set - use UUID if nothing else is available
        if let id = decodedId, !id.isEmpty {
            self.id = id
        } else if let title = decodedTitle, !title.isEmpty {
            self.id = title
        } else if !decodedDescription.isEmpty {
            self.id = decodedDescription
        } else {
            // Last resort: use UUID
            self.id = UUID().uuidString
        }

        self.title = decodedTitle
        self.description = decodedDescription
        self.intent = decodedIntent
        self.usageCount = decodedUsageCount
    }
}

struct GoalCreateRequest: Codable {
    let title: String?
    let description: String
    let source: String?
}

struct GoalResponse: Codable {
    let goals: [Goal]?
    let goal: Goal?
}

struct GoalRecommendationsResponse: Codable {
    let goals: [GoalRecommendation]?
}

struct OnboardingChatRequest: Codable {
    let conversationId: String?
    let message: String
}

struct OnboardingChatResponse: Codable {
    let conversationId: String
    let message: String
}

struct GamePlan: Codable, Identifiable {
    let id: String
    let userId: Int
    let conversationId: String?
    let internalPlan: GamePlanInternal?
    let external: String
    let internalVersion: String
    let externalVersion: String
    let revision: Int
    let status: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case conversationId
        case internalPlan = "internal"
        case external
        case internalVersion
        case externalVersion
        case revision
        case status
        case createdAt
        case updatedAt
    }
}

struct GamePlanInternal: Codable {
    let schemaVersion: String?
    let workout: [String: AnyCodableValue]?
    let food: [String: AnyCodableValue]?
    let shopping: [String: AnyCodableValue]?
    let other: [String: AnyCodableValue]?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case workout
        case food
        case shopping
        case other
    }
}

// Helper to decode numbers or strings for macros
enum DoubleOrString: Codable {
    case double(Double)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else {
            self = .string("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .double(let d): try container.encode(d)
        case .string(let s): try container.encode(s)
        }
    }

    var asDouble: Double? { if case .double(let d) = self { return d } else { return nil } }
    var asString: String? { if case .string(let s) = self { return s } else { return nil } }
}

extension KeyedDecodingContainer {
    fileprivate func decodeFlexibleString(forKey key: Key) throws -> String {
        if let stringValue = try? decode(String.self, forKey: key) {
            return stringValue
        }
        if let intValue = try? decode(Int.self, forKey: key) {
            return String(intValue)
        }
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return String(doubleValue)
        }
        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(
                codingPath: codingPath + [key], debugDescription: "Expected String-compatible value"
            ))
    }

    fileprivate func decodeFlexibleOptionalString(forKey key: Key) -> String? {
        if let stringValue = try? decode(String.self, forKey: key) {
            return stringValue
        }
        if let intValue = try? decode(Int.self, forKey: key) {
            return String(intValue)
        }
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return String(doubleValue)
        }
        return nil
    }

    fileprivate func decodeFlexibleDouble(forKey key: Key) -> Double? {
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return doubleValue
        }
        if let stringValue = try? decode(String.self, forKey: key),
            let doubleValue = Double(stringValue)
        {
            return doubleValue
        }
        if let intValue = try? decode(Int.self, forKey: key) {
            return Double(intValue)
        }
        return nil
    }

    fileprivate func decodeFlexibleBool(forKey key: Key) -> Bool? {
        if let boolValue = try? decode(Bool.self, forKey: key) {
            return boolValue
        }
        if let intValue = try? decode(Int.self, forKey: key) {
            return intValue != 0
        }
        if let stringValue = try? decode(String.self, forKey: key) {
            return (stringValue as NSString).boolValue
        }
        return nil
    }
}

struct ReceiptScanResult: Identifiable, Decodable, Equatable {
    let id: UUID
    let store: String
    let dateOnReceipt: String?
    let processingDate: String
    let items: [ReceiptScanItem]

    private enum CodingKeys: String, CodingKey {
        case store
        case dateOnReceipt = "date_on_receipt"
        case processingDate = "processing_date"
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        store = try container.decode(String.self, forKey: .store)
        dateOnReceipt = try container.decodeIfPresent(String.self, forKey: .dateOnReceipt)
        processingDate = try container.decode(String.self, forKey: .processingDate)
        items = try container.decode([ReceiptScanItem].self, forKey: .items)
    }
}

struct ReceiptScanItem: Identifiable, Decodable, Equatable {
    let id: UUID
    let name: String
    var estimatedName: String

    private enum CodingKeys: String, CodingKey {
        case name
        case estimatedName = "estimated_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        name = try container.decode(String.self, forKey: .name)
        estimatedName = try container.decode(String.self, forKey: .estimatedName)
    }
}
