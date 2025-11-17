import SwiftUI

struct CustomTabBar: View {
    @Binding var selection: TabIdentifier
    let addAction: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var activeColor: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            barBody
            addButton
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var barBody: some View {
        HStack(spacing: 10) {
            TabBarItemView(icon: "speedometer", title: "Dashboard", tab: .dashboard, selection: $selection)
            TabBarItemView(icon: "calendar", title: "Calendar", tab: .calendar, selection: $selection)
            TabBarItemView(icon: "cart", title: "Shopping", tab: .shopping, selection: $selection)
            TabBarItemView(icon: "archivebox", title: "Pantry", tab: .pantry, selection: $selection)
        }
        .frame(height: 58)
        .padding(.horizontal, 20)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    Capsule(style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.18) : Color.white.opacity(0.55))
                        .blur(radius: 14)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.25 : 0.35), lineWidth: 1)
                        .blendMode(.plusLighter)
                )
                .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.2 : 0.45), radius: 24, y: 8)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addButton: some View {
        Button(action: addAction) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(activeColor)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .background(
                            Circle()
                                .fill(colorScheme == .dark ? Color.white.opacity(0.35) : Color.white.opacity(0.75))
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.98),
                                            Color.white.opacity(0.45)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.2
                                )
                        )
                        .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.25 : 0.5), radius: 18, y: 6)
                )
        }
        .buttonStyle(GlassFloatingButtonStyle())
        .contentShape(Rectangle())
    }
}

struct GlassFloatingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
    }
}
