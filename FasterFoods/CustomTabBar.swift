import SwiftUI

struct CustomTabBar: View {
    @Binding var selection: TabIdentifier
    let isAddMenuPresented: Bool
    let onAddOpen: () -> Void
    let onAddClose: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var inactiveBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.28)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.25) : Color.white.opacity(0.35)
    }

    private var floatingIconColor: Color {
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
                        .fill(inactiveBackground)
                        .blur(radius: 22)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                        .blendMode(.plusLighter)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 20, y: 10)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addButton: some View {
        Button {
            HapticSoundPlayer.shared.playPrimaryTap()
            if isAddMenuPresented {
                onAddClose()
            } else {
                onAddOpen()
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(isAddMenuPresented ? Color.secondary : floatingIconColor)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .background(
                            Circle()
                                .fill(isAddMenuPresented ? inactiveBackground : Color.white.opacity(colorScheme == .dark ? 0.25 : 0.65))
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.9),
                                            Color.white.opacity(0.35)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.2
                                )
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 16, y: 8)
                )
        }
        .buttonStyle(GlassFloatingButtonStyle())
        .contentShape(Rectangle())
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: AddButtonFramePreferenceKey.self, value: geo.frame(in: .global))
            }
        )
    }
}

struct GlassFloatingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
    }
}
