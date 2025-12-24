import Foundation
import SwiftUI

struct GamePlanView: View {
    let previewMarkdown: String
    let onReadMore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Game Plan", systemImage: "map")
                .font(.subheadline)
                .fontWeight(.semibold)

            Group {
                Text(previewMarkdown)
            }
            .font(.footnote)
            .multilineTextAlignment(.leading)
            .lineLimit(6)
            .lineSpacing(4)
            .foregroundStyle(.primary)

            Button(action: onReadMore) {
                HStack(spacing: 6) {
                    Text("Read more")
                    Image(systemName: "arrow.up.forward.circle.fill")
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.2), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.green.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.green.opacity(0.25), lineWidth: 1)
        )
    }
}

struct GamePlanPlaceholderView: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Game Plan", systemImage: "map")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)

            ProgressView()
                .progressViewStyle(.circular)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.green.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
    }
}

struct GamePlanContent {
    let previewMarkdown: String
    let markdown: String
}

extension GamePlanContent {
    static func from(markdown: String, maxPreviewLength: Int = 360) -> GamePlanContent? {
        let preview = buildPreview(from: markdown, maxLength: maxPreviewLength)
        let spacedPreview = addParagraphSpacing(to: preview)
        let spacedContent = addParagraphSpacing(to: markdown)
        guard !spacedPreview.isEmpty else { return nil }
        return GamePlanContent(previewMarkdown: spacedPreview, markdown: spacedContent)
    }

    private static func addParagraphSpacing(to markdown: String) -> String {
        markdown.replacingOccurrences(of: "\n\n", with: "\n\n\n")
    }

    private static func buildPreview(from markdown: String, maxLength: Int) -> String {
        let sections = markdown.components(separatedBy: "\n\n")
        var collected: [String] = []
        var runningCount = 0

        for section in sections {
            let trimmed = section.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.hasPrefix("#") || trimmed == "---" { continue }
            if trimmed.lowercased().hasPrefix("table of contents") { continue }
            collected.append(trimmed)
            runningCount += trimmed.count
            if runningCount >= maxLength { break }
        }

        var preview = collected.joined(separator: "\n\n")
        guard !preview.isEmpty else { return "" }

        if preview.count > maxLength {
            var truncated = String(preview.prefix(maxLength))
            if let lastNewline = truncated.lastIndex(of: "\n") {
                truncated = String(truncated[..<lastNewline])
            } else if let lastSpace = truncated.lastIndex(of: " ") {
                truncated = String(truncated[..<lastSpace])
            }
            preview = truncated + "..."
        }

        return preview
    }
}

enum GamePlanLoader {
    private static var cachedContent: GamePlanContent?

    static func load(maxPreviewLength: Int = 360) -> GamePlanContent? {
        if let cachedContent {
            return cachedContent
        }

        let possibleURLs: [URL?] = [
            Bundle.main.url(forResource: "gameplan", withExtension: "md", subdirectory: "GamePlan"),
            Bundle.main.url(forResource: "gameplan", withExtension: "md"),
        ]

        for url in possibleURLs.compactMap({ $0 }) {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                if let result = GamePlanContent.from(
                    markdown: content,
                    maxPreviewLength: maxPreviewLength
                ) {
                    cachedContent = result
                    return result
                }
            }
        }
        return nil
    }
}
