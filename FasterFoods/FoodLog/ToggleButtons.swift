import SwiftUI

struct ToggleButtons<Option: Hashable>: View {
    var title: String?
    let options: [(Option, String)]
    @Binding var selection: Option

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.0) { _, pair in
                    let option = pair.0
                    let label = pair.1
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selection = option
                        }
                    } label: {
                        Text(label)
                            .font(.footnote)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity)
                            .background(selection == option ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08))
                            .foregroundStyle(selection == option ? Color.accentColor : Color.primary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}
