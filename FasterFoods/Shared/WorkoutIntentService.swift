import Foundation

enum WorkoutIntentError: LocalizedError {
    case unauthenticated
    case missingWorkoutName

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "Please log in to FasterFoods, then try again."
        case .missingWorkoutName:
            return "I couldn't work out what to log. Please say the workout name."
        }
    }
}

struct WorkoutIntentResult {
    let itemName: String
    let durationMinutes: Int
}

actor WorkoutIntentService {
    func addWorkout(named rawName: String, durationMinutes: Int?, calories: Int?) async throws
        -> WorkoutIntentResult
    {
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw WorkoutIntentError.missingWorkoutName }

        let clampedDuration = max(durationMinutes ?? Defaults.fallbackDurationMinutes, 1)
        let now = Date()
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let request = WorkoutCreateRequest(
            name: trimmedName,
            activity: Defaults.defaultActivityID,
            category: Defaults.defaultCategoryID,
            duration: String(clampedDuration),
            calories: calories.map { String($0) },
            parameters: Defaults.defaultParameters,
            datetime: isoFormatter.string(from: now)
        )

        try await performWithAuthHandling {
            _ = try await APIClient.shared.createWorkoutItem(request)
        }

        return WorkoutIntentResult(itemName: trimmedName, durationMinutes: clampedDuration)
    }

    private func performWithAuthHandling<T>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch {
            #if DEBUG
                print("❌ Workout intent error:", error.localizedDescription)
            #endif
            if let apiError = error as? APIError,
                apiError.statusCode == 401
            {
                throw WorkoutIntentError.unauthenticated
            }
            throw error
        }
    }
}

private enum Defaults {
    static let defaultActivityID = "gym-strength"
    static let defaultCategoryID = "traditional-strength"
    static let fallbackDurationMinutes = 30

    static let defaultParameters: [String: AnyCodableValue] = [
        "Exercises": .int(1),
        "Sets": .int(3),
        "Reps": .string("8-12"),
    ]
}
