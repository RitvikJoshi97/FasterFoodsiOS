//
//  WorkoutCardView.swift
//  FasterFoods
//
//  Created by Codex on 02/06/24.
//

import SwiftUI

struct WorkoutCardView: View {
    let durationText: String
    let subtitleText: String
    let progress: Double
    let state: WorkoutState
    let onTap: (() -> Void)?

    init(
        durationText: String,
        subtitleText: String,
        progress: Double,
        state: WorkoutState,
        onTap: (() -> Void)? = nil
    ) {
        self.durationText = durationText
        self.subtitleText = subtitleText
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(durationText)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.primary)

                    Text(subtitleText)
                        .font(.subheadline)
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
            }

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(state.accentColor.opacity(0.1))
        )
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .animation(.easeInOut, value: progress)
        .contentShape(Rectangle())
        .onTapGesture {
            guard let onTap else { return }
            onTap()
        }
    }
}
