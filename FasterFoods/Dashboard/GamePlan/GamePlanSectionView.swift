import SwiftUI

struct GamePlanSectionView: View {
    @EnvironmentObject private var app: AppState
    @State private var showExpandedGamePlan = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Game Plan", systemImage: "map")
                .font(.headline)
                .foregroundStyle(.primary)

            if let content = app.gamePlanContent {
                GamePlanView(
                    previewMarkdown: content.previewMarkdown,
                    onReadMore: { showExpandedGamePlan = true }
                )
                .padding(.trailing, 12)
            } else if app.gamePlanStatus.isPreparing {
                GamePlanPlaceholderView(
                    message: "We're preparing your plan."
                )
                .padding(.trailing, 12)
            } else {
                Text("Start setting goals to unlock your personalized game plan.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showExpandedGamePlan) {
            if let content = app.gamePlanContent {
                ExpandedGamePlanView(markdown: content.markdown)
            }
        }
    }
}
