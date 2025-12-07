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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(summary.calories) kcal")
                        .font(.system(size: 32, weight: .bold))
                    Text("logged today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    ForEach(summary.macros) { macro in
                        MacroRingView(macro: macro)
                    }
                }
            }

            Spacer()

            Text(summary.recommendation)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.1))
        )
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
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 36, height: 36)

                Circle()
                    .trim(from: 0, to: CGFloat(macro.progress))
                    .stroke(
                        macro.color,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 36, height: 36)

                Text("\(Int(macro.progress * 100))%")
                    .font(.system(size: 10, weight: .bold))
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
