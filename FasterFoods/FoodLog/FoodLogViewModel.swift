import SwiftUI

final class FoodLogViewModel: ObservableObject {
    enum MealTime: String, CaseIterable, Identifiable {
        case morning, afternoon, evening
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .morning: return "sunrise.fill"
            case .afternoon: return "sun.max.fill"
            case .evening: return "moon.stars.fill"
            }
        }
        var label: String {
            switch self {
            case .morning: return "Morning"
            case .afternoon: return "Afternoon"
            case .evening: return "Evening"
            }
        }
    }

    enum PortionSize: String, CaseIterable, Identifiable {
        case small, medium, large
        var id: String { rawValue }
        var label: String {
            switch self {
            case .small: return "Small"
            case .medium: return "Medium"
            case .large: return "Large"
            }
        }
    }

    enum Mood: String, CaseIterable, Identifiable {
        case notGreat = "not great"
        case okay = "okay"
        case amazing = "amazing"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .notGreat: return "Not Great"
            case .okay: return "Okay"
            case .amazing: return "Amazing"
            }
        }
    }

    enum MealCategory: String, CaseIterable, Identifiable {
        case highProtein = "High-protein"
        case vegan = "Vegan"
        case cheatMeal = "Cheat meal"
        var id: String { rawValue }
    }

    @Published var itemName: String = ""
    @Published var mealTime: MealTime = .morning
    @Published var portionSize: PortionSize = .medium
    @Published var mood: Mood = .okay
    @Published var calories: String = ""
    @Published var carbohydrates: String = ""
    @Published var protein: String = ""
    @Published var fat: String = ""
    @Published var mealCategory: MealCategory = .highProtein
    @Published var digestionFeedback: String = ""
    @Published var hydration: String = ""
    @Published var hungerFullness: Double = 5
    @Published var hungerSatisfaction: String = ""
    @Published var physicalEmptiness: String = ""
    @Published var couldEatMore: String = "maybe"
    @Published var stomachSensations: String = ""
    @Published var chestThroatSensations: String = ""
    @Published var headSensations: String = ""
    @Published var overallBodySensations: String = ""
    @Published var muscleTone: String = ""
    @Published var energyLevel: String = "balanced"
    @Published var breathingChanges: String = ""
    @Published var postureDesire: String = ""
    @Published var emotionsAfterEating: String = ""
    @Published var emotionLocation: String = ""
    @Published var memoriesThoughts: String = ""
    @Published var tasteEnjoyment: String = "neutral"
    @Published var lingeringTaste: String = ""
    @Published var bodySatisfaction: String = "neutral"
    @Published var digestiveSensations: String = ""
    @Published var digestionComfort: String = "neutral"
    @Published var energyChanges: String = ""
    @Published var bodySignals: String = ""
    @Published var mindBodyConnection: String = ""
    @Published var relationshipWithFood: String = ""

    var canLogEntry: Bool {
        !itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func applySuggestion(_ suggestion: String) {
        itemName = suggestion
    }

    func reset(for level: FoodLoggingLevel) {
        itemName = ""
        calories = ""
        carbohydrates = ""
        protein = ""
        fat = ""
        digestionFeedback = ""
        hydration = ""
        hungerFullness = 5
        hungerSatisfaction = ""
        physicalEmptiness = ""
        couldEatMore = "maybe"
        stomachSensations = ""
        chestThroatSensations = ""
        headSensations = ""
        overallBodySensations = ""
        muscleTone = ""
        energyLevel = "balanced"
        breathingChanges = ""
        postureDesire = ""
        emotionsAfterEating = ""
        emotionLocation = ""
        memoriesThoughts = ""
        tasteEnjoyment = "neutral"
        lingeringTaste = ""
        bodySatisfaction = "neutral"
        digestiveSensations = ""
        digestionComfort = "neutral"
        energyChanges = ""
        bodySignals = ""
        mindBodyConnection = ""
        relationshipWithFood = ""
        portionSize = .medium
        mood = .okay
        mealCategory = .highProtein

        if level == .beginner {
            carbohydrates = ""
            protein = ""
            fat = ""
        }
    }

    func adjustMealTime(basedOn date: Date) {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: mealTime = .morning
        case 12..<17: mealTime = .afternoon
        default: mealTime = .evening
        }
    }

    func request(for level: FoodLoggingLevel, date: Date) -> FoodLogCreateRequest {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let datetime = isoFormatter.string(from: date)

        return FoodLogCreateRequest(
            name: itemName,
            meal: mealName(for: mealTime),
            calories: calories.isEmpty ? nil : calories,
            carbohydrates: (level != .beginner && !carbohydrates.isEmpty) ? carbohydrates : nil,
            datetime: datetime,
            loggingLevel: level,
            portionSize: portionSize.rawValue,
            mealTime: mealTime.rawValue,
            mood: mood.rawValue,
            protein: (level != .beginner && !protein.isEmpty) ? protein : nil,
            fat: (level != .beginner && !fat.isEmpty) ? fat : nil,
            mealCategory: (level != .beginner) ? mealCategory.rawValue : nil,
            digestionFeedback: level == .advanced && !digestionFeedback.isEmpty
                ? digestionFeedback : nil,
            hydration: level == .advanced && !hydration.isEmpty ? hydration : nil,
            hungerFullness: level == .advanced ? Int(hungerFullness) : nil,
            hungerSatisfaction: level == .advanced && !hungerSatisfaction.isEmpty
                ? hungerSatisfaction : nil,
            physicalEmptiness: level == .advanced && !physicalEmptiness.isEmpty
                ? physicalEmptiness : nil,
            couldEatMore: level == .advanced ? couldEatMore : nil,
            stomachSensations: level == .advanced && !stomachSensations.isEmpty
                ? stomachSensations : nil,
            chestThroatSensations: level == .advanced && !chestThroatSensations.isEmpty
                ? chestThroatSensations : nil,
            headSensations: level == .advanced && !headSensations.isEmpty ? headSensations : nil,
            overallBodySensations: level == .advanced && !overallBodySensations.isEmpty
                ? overallBodySensations : nil,
            muscleTone: level == .advanced && !muscleTone.isEmpty ? muscleTone : nil,
            energyLevel: level == .advanced ? energyLevel : nil,
            breathingChanges: level == .advanced && !breathingChanges.isEmpty
                ? breathingChanges : nil,
            postureDesire: level == .advanced && !postureDesire.isEmpty ? postureDesire : nil,
            emotionsAfterEating: level == .advanced && !emotionsAfterEating.isEmpty
                ? emotionsAfterEating : nil,
            emotionLocation: level == .advanced && !emotionLocation.isEmpty ? emotionLocation : nil,
            memoriesThoughts: level == .advanced && !memoriesThoughts.isEmpty
                ? memoriesThoughts : nil,
            tasteEnjoyment: level == .advanced ? tasteEnjoyment : nil,
            lingeringTaste: level == .advanced && !lingeringTaste.isEmpty ? lingeringTaste : nil,
            bodySatisfaction: level == .advanced ? bodySatisfaction : nil,
            digestiveSensations: level == .advanced && !digestiveSensations.isEmpty
                ? digestiveSensations : nil,
            digestionComfort: level == .advanced ? digestionComfort : nil,
            energyChanges: level == .advanced && !energyChanges.isEmpty ? energyChanges : nil,
            bodySignals: level == .advanced && !bodySignals.isEmpty ? bodySignals : nil,
            mindBodyConnection: level == .advanced && !mindBodyConnection.isEmpty
                ? mindBodyConnection : nil,
            relationshipWithFood: level == .advanced && !relationshipWithFood.isEmpty
                ? relationshipWithFood : nil
        )
    }

    private func mealName(for time: MealTime) -> String {
        switch time {
        case .morning: return "breakfast"
        case .afternoon: return "lunch"
        case .evening: return "dinner"
        }
    }
}
