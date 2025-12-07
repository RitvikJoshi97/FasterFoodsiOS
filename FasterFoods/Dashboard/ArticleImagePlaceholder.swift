import SwiftUI

struct ArticleImagePlaceholder: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: gradientColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            LinearGradient(
                gradient: Gradient(colors: [baseColor.opacity(overlayOpacity), .clear]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var gradientColors: [Color] {
        var colors = [baseColor]
        if colorScheme == .dark {
            colors.append(contentsOf: darkPalette)
        } else {
            colors.append(contentsOf: lightPalette)
        }
        return colors
    }

    private var baseColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private var overlayOpacity: Double {
        colorScheme == .dark ? 0.7 : 0.5
    }

    private var lightPalette: [Color] {
        [
            Color(red: 0.94, green: 0.98, blue: 1.0),
            Color(red: 0.86, green: 0.95, blue: 0.99),
            Color(red: 0.88, green: 0.93, blue: 0.97),
        ]
    }

    private var darkPalette: [Color] {
        [
            Color(red: 0.10, green: 0.13, blue: 0.18),
            Color(red: 0.18, green: 0.22, blue: 0.30),
            Color(red: 0.24, green: 0.30, blue: 0.38),
        ]
    }
}
