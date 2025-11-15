import Foundation

enum SharedContainer {
    static let identifier = "group.co.fasterfoods.shared"

    static var userDefaults: UserDefaults = {
        guard let defaults = UserDefaults(suiteName: identifier) else {
            assertionFailure("Unable to create shared UserDefaults – falling back to standard.")
            return .standard
        }
        return defaults
    }()
}
