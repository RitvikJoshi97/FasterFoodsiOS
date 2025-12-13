import Foundation

enum FoodLogIntentError: LocalizedError {
    case unauthenticated
    case missingItemName

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "Please log in to FasterFoods, then try again."
        case .missingItemName:
            return "I couldn't work out what to log. Please say the meal or food name."
        }
    }
}

struct FoodLogIntentResult {
    let itemName: String
    let mealName: String
}

actor FoodLogIntentService {
    func addItem(named rawName: String, calories: String?) async throws -> FoodLogIntentResult {
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw FoodLogIntentError.missingItemName }

        let now = Date()
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let mealTime = Self.mealTime(for: now)
        let mealName = Self.mealName(for: mealTime)

        let request = FoodLogCreateRequest(
            name: trimmedName,
            meal: mealName,
            calories: calories?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            datetime: isoFormatter.string(from: now),
            loggingLevel: .beginner,
            portionSize: nil,
            mealTime: mealTime.rawValue,
            mood: nil,
            protein: nil,
            fat: nil,
            mealCategory: nil,
            digestionFeedback: nil,
            hydration: nil,
            hungerFullness: nil,
            hungerSatisfaction: nil,
            physicalEmptiness: nil,
            couldEatMore: nil,
            stomachSensations: nil,
            chestThroatSensations: nil,
            headSensations: nil,
            overallBodySensations: nil,
            muscleTone: nil,
            energyLevel: nil,
            breathingChanges: nil,
            postureDesire: nil,
            emotionsAfterEating: nil,
            emotionLocation: nil,
            memoriesThoughts: nil,
            tasteEnjoyment: nil,
            lingeringTaste: nil,
            bodySatisfaction: nil,
            digestiveSensations: nil,
            digestionComfort: nil,
            energyChanges: nil,
            bodySignals: nil,
            mindBodyConnection: nil,
            relationshipWithFood: nil
        )

        try await performWithAuthHandling {
            _ = try await APIClient.shared.createFoodLogItem(request)
        }

        return FoodLogIntentResult(itemName: trimmedName, mealName: mealName)
    }

    private func performWithAuthHandling<T>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch {
            #if DEBUG
                print("❌ Food log intent error:", error.localizedDescription)
            #endif
            if let apiError = error as? APIError,
                apiError.statusCode == 401
            {
                throw FoodLogIntentError.unauthenticated
            }
            throw error
        }
    }

    private enum MealTime: String {
        case morning, afternoon, evening
    }

    private static func mealTime(for date: Date) -> MealTime {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        default: return .evening
        }
    }

    private static func mealName(for time: MealTime) -> String {
        switch time {
        case .morning: return "breakfast"
        case .afternoon: return "lunch"
        case .evening: return "dinner"
        }
    }
}

extension String {
    fileprivate var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
