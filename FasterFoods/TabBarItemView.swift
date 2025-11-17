import SwiftUI

struct TabBarItemView: View {
    let icon: String
    let title: String
    let tab: TabIdentifier
    @Binding var selection: TabIdentifier
    @Environment(\.colorScheme) private var colorScheme

    private var isSelected: Bool {
        selection == tab
    }

    private var activeColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var inactiveColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : Color.gray.opacity(0.7)
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                selection = tab
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .symbolVariant(isSelected ? .fill : .none)
                .shadow(color: isSelected ? activeColor.opacity(colorScheme == .dark ? 0.9 : 0.5) : Color.white.opacity(colorScheme == .dark ? 0.25 : 0.1), radius: isSelected ? 12 : 4)
                .foregroundStyle(isSelected ? activeColor : inactiveColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
                .accessibilityLabel(Text(title))
        }
        .buttonStyle(.plain)
    }
}
