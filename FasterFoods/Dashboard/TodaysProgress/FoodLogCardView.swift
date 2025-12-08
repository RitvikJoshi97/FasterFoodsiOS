//
//  FoodLogCardView.swift
//  FasterFoods
//
//  Created by Codex on 02/06/24.
//

import SwiftUI

struct FoodLogCardView: View {
    let summary: FoodLogSummary
    let onTap: (() -> Void)?

    init(
        summary: FoodLogSummary,
        onTap: (() -> Void)? = nil
    ) {
        self.summary = summary
        self.onTap = onTap
    }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            // Left column: heading + recommendation, then calories
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Food Log")
                        .font(.headline)
                    if !summary.recommendation.isEmpty {
                        Text("Today's suggestion")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(summary.recommendation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(4)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(summary.calories) kcal")
                        .font(.headline.weight(.bold))
                    Text("logged today")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right column: macros up top, graph below
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(summary.macros) { macro in
                        MacroRingView(macro: macro)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                FoodLogHistoryGraphsView(mode: .day, items: summary.todayItems)
                    .frame(width: 170, height: 95, alignment: .top)
                    .scaleEffect(y: 0.62, anchor: .top)
                    .clipped()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 190)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.1))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            guard let onTap else { return }
            onTap()
        }
    }
}

private struct MacroRingView: View {
    let macro: MacroRingData

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 5)
                    .frame(width: 32, height: 32)

                Circle()
                    .trim(from: 0, to: CGFloat(macro.progress))
                    .stroke(
                        macro.color,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 32, height: 32)

                Text("\(Int(macro.progress * 100))%")
                    .font(.system(size: 9, weight: .bold))
                    .fontWeight(.semibold)
            }

            VStack(spacing: 2) {
                Text(macro.label)
                    .font(.caption2)
                    .fontWeight(.medium)
                Text(macro.formattedValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
