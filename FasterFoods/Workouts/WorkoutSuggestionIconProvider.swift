import SwiftUI

enum WorkoutSuggestionIconProvider {
    static func systemImageName(
        for suggestion: String,
        quickPicks: [WorkoutQuickPickDefinition],
        recommendations: [ShoppingRecommendation]
    ) -> String {
        if let pick = quickPicks.first(where: { $0.label == suggestion }) {
            return systemImageName(activityID: pick.activityID, categoryID: pick.categoryID)
        }

        if let rec = recommendations.first(
            where: { ($0.quickPickDefinition?.label ?? $0.title) == suggestion }),
            let quickPick = rec.quickPickDefinition
        {
            return systemImageName(
                activityID: quickPick.activityID, categoryID: quickPick.categoryID)
        }

        return "figure.walk"
    }

    static func systemImageName(activityID: String, categoryID: String) -> String {
        switch activityID {
        case WorkoutActivityDefinition.Constants.cardio:
            switch categoryID {
            case "outdoor-run", "trail-run", "track-run":
                return "figure.run"
            case "indoor-run":
                return "treadmill"
            case "walking":
                return "figure.walk"
            case "hiking":
                return "figure.hiking"
            default:
                return "figure.run"
            }
        case WorkoutActivityDefinition.Constants.cycling:
            return "bicycle"
        case WorkoutActivityDefinition.Constants.gymStrength:
            switch categoryID {
            case "flexibility":
                return "figure.flexibility"
            case "hiit":
                return "figure.highintensity.intervaltraining"
            default:
                return "dumbbell"
            }
        case WorkoutActivityDefinition.Constants.mindBody:
            switch categoryID {
            case "yoga":
                return "figure.yoga"
            case "tai-chi", "mindful-cooldown":
                return "figure.mind.and.body"
            case "pilates":
                return "figure.pilates"
            default:
                return "figure.mind.and.body"
            }
        case WorkoutActivityDefinition.Constants.waterSports:
            switch categoryID {
            case "pool-swim", "open-water-swim":
                return "figure.pool.swim"
            case "rowing":
                return "figure.rowing"
            case "surfing":
                return "figure.surfing"
            case "paddleboarding":
                return "figure.stand.paddle"
            case "kayaking":
                return "figure.kayaking"
            default:
                return "drop"
            }
        case WorkoutActivityDefinition.Constants.winterSports:
            switch categoryID {
            case "snowboarding":
                return "figure.snowboarding"
            case "skiing", "cross-country-skiing":
                return "figure.skiing.downhill"
            default:
                return "snowflake"
            }
        case WorkoutActivityDefinition.Constants.combatMixed:
            switch categoryID {
            case "boxing", "kickboxing":
                return "figure.boxing"
            case "martial-arts":
                return "figure.martial.arts"
            case "dance-cardio":
                return "figure.dance"
            default:
                return "figure.martial.arts"
            }
        case WorkoutActivityDefinition.Constants.teamField:
            switch categoryID {
            case "football":
                return "figure.american.football"
            case "basketball":
                return "figure.basketball"
            case "volleyball":
                return "figure.volleyball"
            case "hockey":
                return "figure.hockey"
            case "cricket":
                return "figure.cricket"
            case "rugby":
                return "figure.rugby"
            default:
                return "figure.team.sports"
            }
        case WorkoutActivityDefinition.Constants.racketPrecision:
            switch categoryID {
            case "tennis":
                return "figure.tennis"
            case "badminton":
                return "figure.badminton"
            case "table-tennis":
                return "figure.table.tennis"
            case "golf":
                return "figure.golf"
            case "pickleball":
                return "figure.pickleball"
            default:
                return "figure.racket.sports"
            }
        case WorkoutActivityDefinition.Constants.others:
            switch categoryID {
            case "climbing":
                return "figure.climbing"
            case "dance":
                return "figure.dance"
            case "fitness-gaming":
                return "gamecontroller"
            case WorkoutActivityDefinition.Constants.healthKitImport:
                return "heart"
            default:
                return "figure.walk"
            }
        default:
            return "figure.walk"
        }
    }
}
