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
        VStack(alignment: .leading, spacing: 12) {
            Text("Food Log")
                .font(.title3)
                .fontWeight(.semibold)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spare calories")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text("\(summary.caloriesRemaining) kcal")
                        .font(.system(size: 36, weight: .bold))
                    Text(loggedText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                HStack(spacing: 12) {
                    ForEach(summary.macros) { macro in
                        MacroRingView(macro: macro)
                    }
                }
            }

            // FoodLogHistoryGraphsView(mode: .day, items: summary.todayItems)
            //     .frame(height: 95, alignment: .top)
            //     .scaleEffect(y: 0.62, anchor: .top)
            //     .clipped()

            if !summary.recommendation.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    // Text("Today's suggestion")
                    //     .font(.caption)
                    //     .foregroundStyle(.secondary)
                    Text(summary.recommendation)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 190)
        .background(
            GeometryReader { proxy in
                let fillWidth = proxy.size.width * CGFloat(min(max(summary.progress, 0), 1))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: fillWidth)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .animation(.easeInOut, value: summary.progress)
        .contentShape(Rectangle())
        .onTapGesture {
            guard let onTap else { return }
            onTap()
        }
    }

    private var loggedText: String {
        if summary.calorieGoal > 0 {
            return "\(summary.calories) / \(summary.calorieGoal) kcal logged"
        }
        return "\(summary.calories) kcal logged"
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
