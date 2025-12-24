import Foundation

enum AssistantMode {
    case onboarding
    case assistant
}

struct AssistantScript {
    struct Step: Identifiable {
        enum Kind {
            case assistant(String)
            case prompt(String)
        }

        let id = UUID()
        let kind: Kind

        var text: String {
            switch kind {
            case .assistant(let text), .prompt(let text):
                return text
            }
        }

        var requiresInput: Bool {
            if case .prompt = kind {
                return true
            }
            return false
        }
    }

    let steps: [Step]
}

extension AssistantScript {
    static let onboardingBootstrapMessage = "Hi"
    static let onboardingCompletionMessage =
        "Perfect, I think we've got a starting point. We'll start making a game plan for you and we'll let you know when we have it ready. Explore the app a little! Come on in, help yourself!"

    static func empty() -> AssistantScript {
        AssistantScript(steps: [])
    }

    static func onboarding() -> AssistantScript {
        AssistantScript(
            steps: [
                .init(
                    kind: .assistant(
                        "Hey there! Welcome to FasterFoods! Let me explain how FasterFoods works.\n\nWe help you track food, habits, and daily progress so we can recommend smarter meals, grocery lists, and simple health wins."
                    )
                ),
                .init(
                    kind: .assistant(
                        "I have a few questions for you related to your general health if you would not mind."
                    )
                ),
                .init(kind: .prompt("What kind of goals do you have in mind?")),
                .init(
                    kind: .prompt(
                        "Ah, okay, I get it. What about your food habits? Do you have any restrictions on foods you do not want to eat?"
                    )
                ),
                .init(
                    kind: .prompt(
                        "Any allergies or ingredients you want us to avoid completely?"
                    )
                ),
                .init(
                    kind: .prompt(
                        "How often do you cook at home versus eat out in a typical week?"
                    )
                ),
                .init(
                    kind: .assistant(
                        onboardingCompletionMessage
                    )
                ),
            ]
        )
    }

    static func sampleAssistant() -> AssistantScript {
        AssistantScript(
            steps: [
                .init(
                    kind: .assistant(
                        "Hey! This is FasterFoods Help. Tell me what you are trying to do and I will point you in the right direction."
                    )
                ),
                .init(kind: .prompt("What can I help you with?")),
            ]
        )
    }
}

struct ChatMessage: Identifiable {
    enum Role {
        case assistant
        case user
    }

    let id = UUID()
    let role: Role
    let text: String
}
