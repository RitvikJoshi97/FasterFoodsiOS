import Foundation

@MainActor
final class ChatAssistantViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isAwaitingInput = false
    @Published private(set) var isAdvancing = false
    @Published private(set) var isComplete = false

    private let script: AssistantScript
    private let queue: AssistantMessageQueueing?
    private let bootstrapMessage: String?
    private let introMessages: [String]
    private var stepCursor = 0
    private var advanceTask: Task<Void, Never>?
    private var hasNotifiedCompletion = false

    init(
        script: AssistantScript,
        queue: AssistantMessageQueueing? = MockAssistantMessageQueue(),
        bootstrapMessage: String? = nil,
        introMessages: [String] = []
    ) {
        self.script = script
        self.queue = queue
        self.bootstrapMessage = bootstrapMessage
        self.introMessages = introMessages
    }

    private var usesScript: Bool {
        !script.steps.isEmpty
    }

    func start() {
        advanceTask?.cancel()
        messages = []
        stepCursor = 0
        isAwaitingInput = false
        isAdvancing = false
        isComplete = false
        hasNotifiedCompletion = false
        if let bootstrapMessage, !usesScript {
            if introMessages.isEmpty {
                advanceTask = Task { await startBootstrap(message: bootstrapMessage) }
            } else {
                advanceTask = Task {
                    await playIntroMessages()
                    await startBootstrap(message: bootstrapMessage)
                }
            }
        } else {
            advanceTask = Task { await advanceScript() }
        }
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
            appendAssistantMessage(response.message)
            isAdvancing = false
            if response.isFinal {
                markComplete()
                return
            }
        }
        await advanceScript()
        if !usesScript && !isComplete {
            isAwaitingInput = true
        }
    }

    private func advanceScript() async {
        guard usesScript else {
            isAwaitingInput = true
            return
        }
        while stepCursor < script.steps.count {
            let step = script.steps[stepCursor]
            stepCursor += 1
            isAdvancing = true
            if !messages.isEmpty {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
            appendAssistantMessage(step.text)
            isAdvancing = false

            if step.requiresInput {
                isAwaitingInput = true
                return
            }
        }
        markComplete()
    }

    private func playIntroMessages() async {
        for message in introMessages {
            isAdvancing = true
            if !messages.isEmpty {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
            appendAssistantMessage(message)
            isAdvancing = false
        }
    }

    private func startBootstrap(message: String) async {
        guard let queue else {
            isAwaitingInput = true
            return
        }
        isAdvancing = true
        let response = await queue.send(message: message)
        appendAssistantMessage(response.message)
        isAdvancing = false
        if response.isFinal {
            markComplete()
            return
        }
        isAwaitingInput = true
    }

    private func appendAssistantMessage(_ text: String) {
        messages.append(ChatMessage(role: .assistant, text: text))
    }

    private func markComplete() {
        guard !hasNotifiedCompletion else { return }
        hasNotifiedCompletion = true
        isAwaitingInput = false
        isComplete = true
    }
}
