//
//  WorkoutCardView.swift
//  FasterFoods
//
//  Created by Codex on 02/06/24.
//

import SwiftUI

struct WorkoutCardView: View {
    let remainingText: String
    let doneText: String
    let recommendationHighlight: String
    let recommendationIconName: String
    let progress: Double
    let state: WorkoutState
    let onTap: (() -> Void)?

    init(
        remainingText: String,
        doneText: String,
        recommendationHighlight: String,
        recommendationIconName: String,
        progress: Double,
        state: WorkoutState,
        onTap: (() -> Void)? = nil
    ) {
        self.remainingText = remainingText
        self.doneText = doneText
        self.recommendationHighlight = recommendationHighlight
        self.recommendationIconName = recommendationIconName
        self.progress = progress
        self.state = state
        self.onTap = onTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Workout")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Text(state.statusLabel)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(state.accentColor.opacity(0.15))
                    .cornerRadius(8)
            }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Minutes left")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(remainingText)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)

                    Text("\(doneText) done")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                        .frame(width: 70, height: 70)

                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(
                            state.accentColor,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 70, height: 70)
                }
                .padding(.trailing, 8)
            }

            if !recommendationHighlight.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(
                        systemName: recommendationIconName.isEmpty
                            ? "figure.walk" : recommendationIconName
                    )
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.secondary)

                    let leading = Text("We recommend ")
                        .foregroundStyle(.primary)
                    let highlight = Text(recommendationHighlight)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                    let trailing = Text(" today. It should give you a nice boost of energy.")
                        .foregroundStyle(.primary)

                    (leading + highlight + trailing)
                        .font(.body)
                        .lineLimit(3)
                }
                .padding(.top, 10)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(
            GeometryReader { proxy in
                let fillWidth = proxy.size.width * CGFloat(min(max(progress, 0), 1))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    RoundedRectangle(cornerRadius: 16)
                        .fill(state.accentColor.opacity(0.2))
                        .frame(width: fillWidth)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .animation(.easeInOut, value: progress)
        .contentShape(Rectangle())
        .onTapGesture {
            guard let onTap else { return }
            onTap()
        }
    }
}
