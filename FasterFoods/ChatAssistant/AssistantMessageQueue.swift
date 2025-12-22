import Foundation

protocol AssistantMessageQueueing {
    func send(message: String) async -> String
}

struct MockAssistantMessageQueue: AssistantMessageQueueing {
    func send(message: String) async -> String {
        try? await Task.sleep(nanoseconds: 300_000_000)
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Thanks! I am ready for the next question."
        }
        return "Got it. Thanks for sharing."
    }
}
