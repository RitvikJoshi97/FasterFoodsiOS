import SwiftUI

enum ToastStyle {
    case success
    case error

    var background: Color {
        Color.white
    }

    var foreground: Color { .accentColor }

    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let style: ToastStyle
}

final class ToastService: ObservableObject {
    @Published private(set) var toast: ToastMessage?

    private var hideTask: Task<Void, Never>?

    @MainActor
    func show(_ text: String, style: ToastStyle = .success, duration: TimeInterval = 2.4) {
        hideTask?.cancel()
        let message = ToastMessage(text: text, style: style)
        withAnimation(.easeIn(duration: 0.22)) {
            toast = message
        }

        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            await MainActor.run {
                if self?.toast?.id == message.id {
                    withAnimation(.easeOut(duration: 0.22)) {
                        self?.toast = nil
                    }
                }
            }
        }
    }

    @MainActor
    func hide() {
        hideTask?.cancel()
        withAnimation(.easeOut(duration: 0.22)) {
            toast = nil
        }
    }
}

private struct ToastPresenter: ViewModifier {
    @EnvironmentObject private var toastService: ToastService

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            toastOverlay
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let toast = toastService.toast {
            VStack {
                HStack(spacing: 10) {
                    Image(systemName: toast.style.icon)
                        .foregroundStyle(toast.style.foreground)
                    Text(toast.text)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(toast.style.foreground)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(toast.style.background)
                        .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: toastService.toast)
        }
    }
}

extension View {
    func toastHost(using service: ToastService = ToastService()) -> some View {
        self
            .modifier(ToastPresenter())
            .environmentObject(service)
    }
}
