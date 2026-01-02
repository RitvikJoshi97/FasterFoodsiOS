import Foundation

struct AssistantMessageResponse {
    let message: String
    let isFinal: Bool
}

protocol AssistantMessageQueueing {
    func send(message: String) async -> AssistantMessageResponse
}

struct MockAssistantMessageQueue: AssistantMessageQueueing {
    func send(message: String) async -> AssistantMessageResponse {
        try? await Task.sleep(nanoseconds: 300_000_000)
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let response: String
        if trimmed.isEmpty {
            response = "Thanks! I am ready for the next question."
        } else {
            response = "Got it. Thanks for sharing."
        }
        return AssistantMessageResponse(message: response, isFinal: false)
    }
}

actor OnboardingMessageQueue: AssistantMessageQueueing {
    private var conversationId: String?
    private let completionMessage: String

    init(
        conversationId: String? = nil,
        completionMessage: String = AssistantScript.onboardingCompletionMessage
    ) {
        self.conversationId = conversationId
        self.completionMessage = completionMessage
    }

    func send(message: String) async -> AssistantMessageResponse {
        do {
            let response = try await APIClient.shared.sendOnboardingMessage(
                message: message,
                conversationId: conversationId
            )
            conversationId = response.conversationId
            let trimmed = response.message.trimmingCharacters(in: .whitespacesAndNewlines)
            let isFinal = trimmed == completionMessage
            return AssistantMessageResponse(message: response.message, isFinal: isFinal)
        } catch let apiError as APIError {
            let fallback: String
            if apiError.isNetworkError {
                fallback = "No internet connection. Please try again."
            } else {
                fallback = apiError.message
            }
            return AssistantMessageResponse(message: fallback, isFinal: false)
        } catch {
            return AssistantMessageResponse(
                message: "Sorry, something went wrong. Please try again.",
                isFinal: false
            )
        }
    }
}
