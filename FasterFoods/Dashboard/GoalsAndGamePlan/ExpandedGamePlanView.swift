import SwiftUI

struct ExpandedGamePlanView: View {
    let markdown: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if let attributed = makeGamePlanAttributedString(
                        from: markdown,
                        paragraphSpacing: 12
                    ) {
                        Text(attributed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(markdown)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .lineSpacing(8)
                .textSelection(.enabled)
                .padding()
            }
            .navigationTitle("Game Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
