import SwiftUI

struct ChatAssistantView: View {
    @EnvironmentObject private var app: AppState

    let title: String
    let script: AssistantScript
    let dismissLabel: String
    let onComplete: () -> Void
    let onDismiss: () -> Void

    @StateObject private var viewModel: ChatAssistantViewModel
    @State private var userInput = ""
    @State private var hasStarted = false
    @FocusState private var inputFocused: Bool

    init(
        title: String,
        script: AssistantScript,
        queue: AssistantMessageQueueing? = MockAssistantMessageQueue(),
        bootstrapMessage: String? = nil,
        dismissLabel: String = "Close",
        onComplete: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.script = script
        self.dismissLabel = dismissLabel
        self.onComplete = onComplete
        self.onDismiss = onDismiss
        _viewModel = StateObject(
            wrappedValue: ChatAssistantViewModel(
                script: script,
                queue: queue,
                bootstrapMessage: bootstrapMessage
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                messageRow(message)
                                    .id(message.id)
                            }
                            if viewModel.isAdvancing {
                                typingIndicator()
                                    .id("typing-indicator")
                            }
                            Color.clear
                                .frame(height: 1)
                                .id("chat-bottom")
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                    .onChange(of: viewModel.messages.count) { _, _ in
                        scrollToBottom(using: proxy)
                    }
                    .onChange(of: viewModel.isAdvancing) { _, _ in
                        scrollToBottom(using: proxy)
                    }
                    .onChange(of: viewModel.isAwaitingInput) { _, _ in
                        scrollToBottom(using: proxy)
                    }
                }

                Divider()
                footerControls
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(dismissLabel) {
                        onDismiss()
                    }
                }
            }
            .onAppear {
                guard !hasStarted else { return }
                hasStarted = true
                viewModel.start()
                inputFocused = true
            }
            .onChange(of: viewModel.isComplete) { _, newValue in
                guard newValue, app.assistantMode == .onboarding else { return }
                app.markOnboardingComplete()
                app.beginGamePlanPolling()
            }
        }
    }

    private var footerControls: some View {
        VStack(spacing: 12) {
            if viewModel.isComplete {
                Button(app.assistantMode == .onboarding ? "Continue" : "Finish") {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 12) {
                    TextField(
                        "Type your response...",
                        text: $userInput,
                        axis: .vertical
                    )
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .focused($inputFocused)

                    Button("Send") {
                        sendUserInput()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .onChange(of: viewModel.isAwaitingInput) { _, newValue in
            if newValue {
                inputFocused = true
            }
        }
    }

    private func sendUserInput() {
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        userInput = ""
        viewModel.sendUserInput(trimmed)
        inputFocused = true
    }

    @ViewBuilder
    private func messageRow(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == .assistant {
                messageBubble(
                    text: message.text,
                    background: Color(.secondarySystemGroupedBackground),
                    foreground: .primary,
                    alignment: .leading
                )
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                messageBubble(
                    text: message.text,
                    background: Color.accentColor.opacity(0.18),
                    foreground: .primary,
                    alignment: .trailing
                )
            }
        }
    }

    private func messageBubble(
        text: String,
        background: Color,
        foreground: Color,
        alignment: Alignment
    ) -> some View {
        Text(text)
            .foregroundStyle(foreground)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(background)
            )
            .frame(maxWidth: 280, alignment: alignment)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private func typingIndicator() -> some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .frame(width: 6, height: 6)
                Circle()
                    .frame(width: 6, height: 6)
                Circle()
                    .frame(width: 6, height: 6)
            }
            .foregroundStyle(.secondary)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            Spacer(minLength: 40)
        }
    }

    private func scrollToBottom(using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("chat-bottom", anchor: .bottom)
            }
        }
    }
}
