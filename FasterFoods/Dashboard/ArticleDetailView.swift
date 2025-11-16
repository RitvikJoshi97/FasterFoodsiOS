import SwiftUI

struct ArticleDetailView: View {
    let article: ArticleTopic
    private let allArticles: [ArticleTopic]
    
    @State private var markdownText: String = ""
    @State private var isLoading: Bool = true
    @State private var heroImageURL: URL?
    
    init(article: ArticleTopic, allArticles: [ArticleTopic] = ArticleLoader.allTopics()) {
        self.article = article
        self.allArticles = allArticles
        _heroImageURL = State(initialValue: article.randomImageURL)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroImage
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(article.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.leading)
                    
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if markdownText.isEmpty {
                        Text("Content for this article isn't available yet.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    } else {
                        let processed = ArticleReferencePreprocessor.process(markdownText)
                        ArticleMarkdownView(
                            markdownText: processed.cleanedMarkdown,
                            references: processed.references,
                            allArticles: allArticles
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadArticleContent()
        }
    }
    
    private var heroImage: some View {
        ZStack {
            AsyncImage(url: heroImageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Color.gray.opacity(0.2)
                case .empty:
                    Color.gray.opacity(0.1)
                @unknown default:
                    Color.gray.opacity(0.1)
                }
            }
            
            LinearGradient(
                colors: [
                    Color.black.opacity(0.35),
                    Color.black.opacity(0.05)
                ],
                startPoint: .bottom,
                endPoint: .center
            )
        }
    }
    
    private func loadArticleContent() async {
        await MainActor.run { isLoading = true }
        let possibleURLs = [
            Bundle.main.url(forResource: article.markdownResourceName, withExtension: "md", subdirectory: "Articles"),
            Bundle.main.url(forResource: article.markdownResourceName, withExtension: "md")
        ].compactMap { $0 }
        
        let text: String = {
            for url in possibleURLs {
                if let contents = try? String(contentsOf: url, encoding: .utf8) {
                    return contents
                }
            }
            return ""
        }()
        
        await MainActor.run {
            markdownText = text
            isLoading = false
        }
    }
}

// MARK: - Reference Preprocessing

struct ArticleReferencePreprocessor {
    struct Result {
        let cleanedMarkdown: String
        let references: [String: MarkdownLinkReference]
    }
    
    static func process(_ markdown: String) -> Result {
        let footnotes = extractFootnotes(from: markdown)
        let withoutFootnotes = removeFootnoteLines(from: markdown)
        return replaceReferencePlaceholders(in: withoutFootnotes, footnotes: footnotes)
    }
    
    private static func extractFootnotes(from markdown: String) -> [String: URL] {
        var dictionary: [String: URL] = [:]
        let lines = markdown.components(separatedBy: .newlines)
        
        for line in lines {
            guard line.hasPrefix("["), let closingIndex = line.firstIndex(of: "]"), line.contains("]:") else {
                continue
            }
            let number = String(line[line.index(after: line.startIndex)..<closingIndex])
            let remainder = line[closingIndex...].dropFirst(2).trimmingCharacters(in: .whitespaces)
            if let url = URL(string: remainder) {
                dictionary[number] = url
            }
        }
        return dictionary
    }
    
    private static func removeFootnoteLines(from markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        let filtered = lines.filter { line in
            guard line.hasPrefix("[") else { return true }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.matches(regex: #"^\[\d+\]:"#)
        }
        return filtered.joined(separator: "\n")
    }
    
    private static func replaceReferencePlaceholders(in text: String,
                                                     footnotes: [String: URL]) -> Result {
        let pattern = #"\[(?<title>[^\]]+)\]\[(?<number>\d+)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return Result(cleanedMarkdown: text, references: [:])
        }
        
        let nsText = text as NSString
        var resultsText = ""
        var references: [String: MarkdownLinkReference] = [:]
        var cursor = 0
        var placeholderIndex = 0
        
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            let range = match.range
            let prefixRange = NSRange(location: cursor, length: range.location - cursor)
            resultsText += nsText.substring(with: prefixRange)
            
            let title = nsText.substring(with: match.range(withName: "title")).trimmingCharacters(in: .whitespacesAndNewlines)
            let number = nsText.substring(with: match.range(withName: "number"))
            
            guard let url = footnotes[number] else {
                resultsText += nsText.substring(with: range)
                cursor = range.location + range.length
                continue
            }
            
            let placeholder = "⟦ref:\(placeholderIndex)⟧"
            references[placeholder] = MarkdownLinkReference(
                title: title,
                article: nil,
                url: url
            )
            resultsText += placeholder
            
            cursor = range.location + range.length
            placeholderIndex += 1
        }
        
        if cursor < nsText.length {
            let suffixRange = NSRange(location: cursor, length: nsText.length - cursor)
            resultsText += nsText.substring(with: suffixRange)
        }
        
        let residualPattern = #":contentReference\[.*?\]\{.*?\}"#
        let cleaned = resultsText.replacingOccurrences(of: residualPattern, with: "", options: .regularExpression)
        return Result(cleanedMarkdown: cleaned, references: references)
    }
}

private extension String {
    func matches(regex: String) -> Bool {
        range(of: regex, options: .regularExpression) != nil
    }
}

// MARK: - Markdown Rendering

struct ArticleMarkdownView: View {
    private let blocks: [ArticleBlock]
    private let articleTopics: [ArticleTopic]
    private let references: [String: MarkdownLinkReference]
    
    init(markdownText: String, references: [String: MarkdownLinkReference], allArticles: [ArticleTopic]) {
        self.blocks = ArticleMarkdownParser.parse(markdownText)
        self.references = references
        self.articleTopics = allArticles
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(blocks) { block in
                switch block.kind {
                case .heading(let level, let text):
                    InlineMarkdownText(text, articles: articleTopics, references: references)
                        .font(font(for: level))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .paragraph(let text):
                    InlineMarkdownText(text, articles: articleTopics, references: references)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .bulletList(let items):
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(items.enumerated()), id: \.offset) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Color.secondary)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)
                                InlineMarkdownText(entry.element, articles: articleTopics, references: references)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                case .quote(let text):
                    InlineMarkdownText(text, articles: articleTopics, references: references)
                        .font(.body.italic())
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    private func font(for level: Int) -> Font {
        switch level {
        case 1:
            return .title3
        case 2:
            return .headline
        default:
            return .subheadline
        }
    }
}

// MARK: - Parser

struct ArticleBlock: Identifiable {
    enum Kind {
        case heading(level: Int, text: String)
        case paragraph(String)
        case bulletList([String])
        case quote(String)
    }
    
    let id = UUID()
    let kind: Kind
}

enum ArticleMarkdownParser {
    static func parse(_ markdown: String) -> [ArticleBlock] {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        
        var blocks: [ArticleBlock] = []
        var paragraphLines: [String] = []
        var bulletLines: [String] = []
        
        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            let text = paragraphLines.joined(separator: " ")
            blocks.append(ArticleBlock(kind: .paragraph(text)))
            paragraphLines.removeAll()
        }
        
        func flushBulletList() {
            guard !bulletLines.isEmpty else { return }
            blocks.append(ArticleBlock(kind: .bulletList(bulletLines)))
            bulletLines.removeAll()
        }
        
        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty {
                flushParagraph()
                flushBulletList()
                continue
            }
            
            if let headingLevel = headingLevel(for: trimmed) {
                flushParagraph()
                flushBulletList()
                let textStart = trimmed.index(trimmed.startIndex, offsetBy: min(headingLevel, trimmed.count))
                let content = trimmed[textStart...].trimmingCharacters(in: .whitespaces)
                blocks.append(ArticleBlock(kind: .heading(level: headingLevel, text: content)))
                continue
            }
            
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flushParagraph()
                let item = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
                bulletLines.append(item)
                continue
            }
            
            if trimmed.hasPrefix(">") {
                flushParagraph()
                flushBulletList()
                let quote = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                blocks.append(ArticleBlock(kind: .quote(quote)))
                continue
            }
            
            paragraphLines.append(trimmed)
        }
        
        flushParagraph()
        flushBulletList()
        
        if blocks.isEmpty {
            return [ArticleBlock(kind: .paragraph(markdown))]
        }
        
        return blocks
    }
    
    private static func headingLevel(for line: String) -> Int? {
        guard line.first == "#" else { return nil }
        let level = line.prefix { $0 == "#" }.count
        return level
    }
}

// MARK: - Inline Text Rendering

struct InlineMarkdownText: View {
    private let segments: [InlineSegment]
    
    init(_ text: String, articles: [ArticleTopic], references: [String: MarkdownLinkReference]) {
        self.segments = InlineSegmentParser.segments(from: text, articles: articles, references: references)
    }
    
    var body: some View {
        InlineWrapLayout(spacing: 0, lineSpacing: 6) {
            ForEach(segments) { segment in
                switch segment.kind {
                case .text(let attributed):
                    Text(attributed)
                        .fixedSize()
                case .space:
                    Text(" ")
                case .link(let attributed, let reference):
                    InlineLinkCluster(text: attributed, reference: reference)
                case .reference(let reference):
                    InfoLinkButton(reference: reference)
                }
            }
        }
    }
}

struct InlineSegment: Identifiable {
    enum Kind {
        case text(AttributedString)
        case space
        case link(text: AttributedString, reference: MarkdownLinkReference)
        case reference(MarkdownLinkReference)
    }
    
    let id = UUID()
    let kind: Kind
}

enum InlineSegmentParser {
    static func segments(from text: String,
                         articles: [ArticleTopic],
                         references: [String: MarkdownLinkReference]) -> [InlineSegment] {
        guard !text.isEmpty else { return [] }
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        guard let attributed = try? AttributedString(markdown: text, options: options) else {
            return [InlineSegment(kind: .text(AttributedString(text)))]
        }
        
        var segments: [InlineSegment] = []
        for run in attributed.runs {
            let substring = AttributedString(attributed[run.range])
            if let url = run.link {
                let reference = reference(
                    for: url,
                    fallbackTitle: substring.plainString,
                    articles: articles
                )
                segments.append(InlineSegment(kind: .link(text: substring, reference: reference)))
            } else {
                segments.append(contentsOf: tokenize(substring, references: references))
            }
        }
        return segments
    }
    
    private static func reference(for url: URL, fallbackTitle: String, articles: [ArticleTopic]) -> MarkdownLinkReference {
        if url.scheme == nil || url.scheme?.isEmpty == true {
            let relative = url.relativeString
            if let article = resolveArticle(from: relative, within: articles) {
                return MarkdownLinkReference(title: article.title, article: article, url: nil)
            }
        }
        return MarkdownLinkReference(title: fallbackTitle, article: nil, url: url)
    }
    
    private static func resolveArticle(from path: String, within articles: [ArticleTopic]) -> ArticleTopic? {
        let components = path.split(separator: "/")
        guard let last = components.last else { return nil }
        let filename = String(last)
        let normalized = filename.lowercased()
        let resourceName = normalized.replacingOccurrences(of: ".md", with: "")
        
        return articles.first {
            $0.link.lowercased() == normalized ||
            $0.markdownResourceName.lowercased() == resourceName
        }
    }
    
    private static func tokenize(_ attributed: AttributedString,
                                 references: [String: MarkdownLinkReference]) -> [InlineSegment] {
        var tokens: [InlineSegment] = []
        let characters = attributed.characters
        var index = characters.startIndex
        
        while index < characters.endIndex {
            let character = characters[index]
            if character.isNewline {
                tokens.append(InlineSegment(kind: .space))
                index = characters.index(after: index)
                continue
            }
            
            if character.isWhitespace {
                tokens.append(InlineSegment(kind: .space))
                index = characters.index(after: index)
            } else {
                var end = index
                while end < characters.endIndex,
                      characters[end] != " ",
                      !characters[end].isNewline {
                    end = characters.index(after: end)
                }
                let word = AttributedString(attributed[index..<end])
                tokens.append(contentsOf: tokenizeWord(word, references: references))
                index = end
            }
        }
        
        return tokens
    }
    
    private static func tokenizeWord(_ word: AttributedString,
                                     references: [String: MarkdownLinkReference]) -> [InlineSegment] {
        let plain = word.plainString
        guard !plain.isEmpty else { return [] }
        
        if let direct = references[plain] {
            return [InlineSegment(kind: .reference(direct))]
        }
        
        guard let (key, reference) = references.first(where: { plain.contains($0.key) }),
              let plainRange = plain.range(of: key),
              let lower = AttributedString.Index(plainRange.lowerBound, within: word),
              let upper = AttributedString.Index(plainRange.upperBound, within: word) else {
            return [InlineSegment(kind: .text(word))]
        }
        
        var segments: [InlineSegment] = []
        if lower > word.startIndex {
            let prefix = AttributedString(word[word.startIndex..<lower])
            segments.append(contentsOf: tokenizeWord(prefix, references: references))
        }
        
        segments.append(InlineSegment(kind: .reference(reference)))
        
        if upper < word.endIndex {
            let suffix = AttributedString(word[upper..<word.endIndex])
            segments.append(contentsOf: tokenizeWord(suffix, references: references))
        }
        
        return segments
    }
}

extension AttributedString {
    fileprivate var plainString: String {
        String(characters)
    }
}

struct InlineLinkCluster: View {
    let text: AttributedString
    let reference: MarkdownLinkReference
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
            InfoLinkButton(reference: reference)
                .alignmentGuide(.firstTextBaseline) { dimension in
                    dimension[VerticalAlignment.center]
                }
        }
    }
}

struct InfoLinkButton: View {
    let reference: MarkdownLinkReference
    
    @State private var isPresenting = false
    @State private var presentedArticle: ArticleTopic?
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                isPresenting = true
            }
        } label: {
            ReferenceBadge()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reference: \(reference.title)")
        .fullScreenCover(isPresented: $isPresenting) {
            ReferenceDetailOverlay(
                reference: reference,
                onDismiss: { isPresenting = false },
                onOpenArticle: { article in
                    presentedArticle = article
                    isPresenting = false
                },
                onOpenURL: { url in
                    openURL(url)
                    isPresenting = false
                }
            )
        }
        .sheet(item: $presentedArticle) { article in
            NavigationStack {
                ArticleDetailView(article: article)
            }
        }
    }
}

struct MarkdownLinkReference: Identifiable {
    let id = UUID()
    let title: String
    let article: ArticleTopic?
    let url: URL?
}

private struct ReferenceBadge: View {
    var body: some View {
        Text("i")
            .font(.caption.bold())
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(
                Circle()
                    .fill(Color.accentColor)
            )
            .accessibilityHidden(true)
    }
}

private struct ReferenceDetailOverlay: View {
    let reference: MarkdownLinkReference
    let onDismiss: () -> Void
    let onOpenArticle: (ArticleTopic) -> Void
    let onOpenURL: (URL) -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 20) {
                Text(reference.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                actionButton
                
                Button("Close") {
                    onDismiss()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .shadow(color: .black.opacity(0.2), radius: 18, x: 0, y: 10)
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        if let article = reference.article {
            Button {
                onOpenArticle(article)
            } label: {
                Text("Read article")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }
        } else if let url = reference.url {
            Button {
                onOpenURL(url)
            } label: {
                Text("Read more on \(sourceName(for: url))")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }
        } else {
            Text("Reference unavailable")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private func sourceName(for url: URL) -> String {
        let host = url.host?.replacingOccurrences(of: "www.", with: "") ?? ""
        return host.isEmpty ? url.absoluteString : host
    }
}

struct InlineWrapLayout: Layout {
    var spacing: CGFloat = 0
    var lineSpacing: CGFloat = 6
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let maxWidth = proposal.width ?? .infinity
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var measuredWidth: CGFloat = 0
        
        for subview in subviews {
            var fittingWidth = maxWidth.isFinite ? maxWidth - lineWidth : nil
            if fittingWidth == .some(.zero) { fittingWidth = nil }
            var size = subview.sizeThatFits(ProposedViewSize(width: fittingWidth, height: nil))
            
            if maxWidth.isFinite && lineWidth > 0 && lineWidth + size.width > maxWidth {
                totalHeight += lineHeight + lineSpacing
                measuredWidth = max(measuredWidth, lineWidth)
                lineWidth = 0
                lineHeight = 0
                size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            }
            
            lineWidth += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        
        let finalLineWidth = max(lineWidth - spacing, 0)
        measuredWidth = max(measuredWidth, finalLineWidth)
        totalHeight += lineHeight
        
        return CGSize(
            width: maxWidth.isFinite ? maxWidth : measuredWidth,
            height: totalHeight
        )
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var origin = CGPoint(x: bounds.minX, y: bounds.minY)
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            var fittingWidth = maxWidth - (origin.x - bounds.minX)
            if fittingWidth <= 0 { fittingWidth = maxWidth }
            var size = subview.sizeThatFits(ProposedViewSize(width: fittingWidth, height: nil))
            
            if origin.x > bounds.minX && origin.x + size.width > bounds.maxX {
                origin.x = bounds.minX
                origin.y += lineHeight + lineSpacing
                lineHeight = 0
                size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            }
            
            subview.place(
                at: CGPoint(x: origin.x, y: origin.y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            
            origin.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
