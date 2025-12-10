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
                if let attributed = makeGamePlanAttributedString(
                    from: previewMarkdown,
                    paragraphSpacing: 8
                ) {
                    Text(attributed)
                } else {
                    Text(previewMarkdown)
                }
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

struct GamePlanContent {
    let previewMarkdown: String
    let markdown: String
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
                let preview = buildPreview(from: content, maxLength: maxPreviewLength)
                let spacedPreview = addParagraphSpacing(to: preview)
                let spacedContent = addParagraphSpacing(to: content)
                if !spacedPreview.isEmpty {
                    let result = GamePlanContent(
                        previewMarkdown: spacedPreview,
                        markdown: spacedContent
                    )
                    cachedContent = result
                    return result
                }
            }
        }
        return nil
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

func makeGamePlanAttributedString(
    from markdown: String,
    paragraphSpacing: CGFloat
) -> AttributedString? {
    guard
        var attributed = try? AttributedString(
            markdown: markdown,
            options: .init(
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        )
    else { return nil }

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.paragraphSpacing = paragraphSpacing

    let mutable = NSMutableAttributedString(attributedString: NSAttributedString(attributed))
    let range = NSRange(location: 0, length: mutable.length)
    mutable.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: range)

    return AttributedString(mutable)
}
