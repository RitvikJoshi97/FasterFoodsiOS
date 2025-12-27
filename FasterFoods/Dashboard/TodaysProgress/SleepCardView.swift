//
//  SleepCardView.swift
//  FasterFoods
//
//  Created by Codex on 02/06/24.
//

import SwiftUI

struct SleepCardView: View {
    let onTap: (() -> Void)?

    init(onTap: (() -> Void)? = nil) {
        self.onTap = onTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sleep")
                .font(.title3)
                .fontWeight(.semibold)

            Text("7h sleep yesterday")
                .font(.system(size: 26, weight: .bold))

            Text("Recommended sleep: 8h for today")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.12))
        )
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            guard let onTap else { return }
            onTap()
        }
    }
}
