import Foundation

@MainActor
final class ChatAssistantViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isAwaitingInput = false
    @Published private(set) var isAdvancing = false

    private let script: AssistantScript
    private let queue: AssistantMessageQueueing?
    private var stepCursor = 0
    private var advanceTask: Task<Void, Never>?

    init(script: AssistantScript, queue: AssistantMessageQueueing? = MockAssistantMessageQueue()) {
        self.script = script
        self.queue = queue
    }

    var isComplete: Bool {
        !isAwaitingInput && stepCursor >= script.steps.count
    }

    func start() {
        advanceTask?.cancel()
        messages = []
        stepCursor = 0
        isAwaitingInput = false
        isAdvancing = false
        advanceTask = Task { await advanceScript() }
    }

    func sendUserInput(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(ChatMessage(role: .user, text: trimmed))
        isAwaitingInput = false
        advanceTask?.cancel()
        advanceTask = Task { await handleUserReply(trimmed) }
    }

    private func handleUserReply(_ text: String) async {
        if let queue {
            isAdvancing = true
            let response = await queue.send(message: text)
            appendAssistantMessage(response)
            isAdvancing = false
        }
        await advanceScript()
    }

    private func advanceScript() async {
        while stepCursor < script.steps.count {
            let step = script.steps[stepCursor]
            stepCursor += 1
            isAdvancing = true
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            appendAssistantMessage(step.text)
            isAdvancing = false

            if step.requiresInput {
                isAwaitingInput = true
                return
            }
        }
    }

    private func appendAssistantMessage(_ text: String) {
        messages.append(ChatMessage(role: .assistant, text: text))
    }
}
