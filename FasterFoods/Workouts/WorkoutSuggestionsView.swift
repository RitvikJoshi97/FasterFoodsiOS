import SwiftUI

struct WorkoutSuggestionsCard: View {
    @ObservedObject var viewModel: WorkoutsViewModel
    let recommendations: [ShoppingRecommendation]
    let isLoadingRecommendations: Bool
    let onRefreshRecommendations: () -> Void
    let onDismissRecommendation: (String) -> Void
    let onAddWorkout: () -> Void
    @State private var highlightedSuggestion: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            recommendationHeadline
                .font(.body)

            WorkoutSuggestionsSection(
                viewModel: viewModel,
                recommendations: recommendations,
                isLoadingRecommendations: isLoadingRecommendations,
                onRefreshRecommendations: onRefreshRecommendations,
                onDismissRecommendation: onDismissRecommendation,
                onAddWorkout: onAddWorkout,
                highlightedSuggestion: highlightedSuggestion
            )

            HStack(spacing: 12) {
                Button(action: applyHighlightedSuggestion) {
                    Text(highlightedButtonTitle)
                        .font(.subheadline)
                        .lineLimit(1)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(
                    CapsuleCornerShape(
                        outerRadius: 16,
                        innerRadius: 2,
                        innerEdge: .trailing
                    )
                )
                .disabled(highlightedSuggestion.isEmpty)

                Button(action: onAddWorkout) {
                    Label("Log Workout", systemImage: "plus")
                        .font(.subheadline)
                        .lineLimit(1)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
                .clipShape(
                    CapsuleCornerShape(
                        outerRadius: 16,
                        innerRadius: 2,
                        innerEdge: .leading
                    )
                )
            }
        }
        .padding(.vertical, 4)
        .onAppear(perform: updateHighlight)
        .onChange(of: viewModel.quickPicks.map(\.id)) { _ in updateHighlight() }
        .onChange(of: recommendations.map(\.id)) { _ in updateHighlight() }
    }

    @ViewBuilder
    private var recommendationHeadline: some View {
        if highlightedSuggestion.isEmpty {
            Text("Log a workout to keep your momentum going.")
                .foregroundStyle(.secondary)
        } else {
            RecommendationWrappedText(
                systemImageName: systemImageName(for: highlightedSuggestion),
                highlightedText: highlightedSuggestion
            )
        }
    }

    private var highlightedButtonTitle: String {
        highlightedSuggestion.isEmpty ? "Suggested Workout" : "\(highlightedSuggestion)"
    }

    private func updateHighlight() {
        let titles = suggestionTitles
        guard !titles.isEmpty else {
            highlightedSuggestion = ""
            return
        }
        if !titles.contains(highlightedSuggestion) {
            highlightedSuggestion = titles.randomElement() ?? ""
        }
    }

    private var suggestionTitles: [String] {
        let quickPickTitles = viewModel.quickPicks.map(\.label)
        let recommendationTitles = recommendations.compactMap { recommendation in
            recommendation.quickPickDefinition?.label ?? recommendation.title
        }
        return quickPickTitles + recommendationTitles
    }

    private func applyHighlightedSuggestion() {
        guard !highlightedSuggestion.isEmpty else { return }
        if let pick = viewModel.quickPicks.first(where: { $0.label == highlightedSuggestion }) {
            viewModel.applyQuickPick(pick)
            onAddWorkout()
            return
        }

        if let rec = recommendations.first(where: { $0.title == highlightedSuggestion }),
            let quickPick = rec.quickPickDefinition
        {
            viewModel.applyQuickPick(quickPick)
            onAddWorkout()
        }
    }

    private func systemImageName(for suggestion: String) -> String {
        if let pick = viewModel.quickPicks.first(where: { $0.label == suggestion }) {
            return systemImageName(activityID: pick.activityID, categoryID: pick.categoryID)
        }

        if let rec = recommendations.first(
            where: { ($0.quickPickDefinition?.label ?? $0.title) == suggestion }),
            let quickPick = rec.quickPickDefinition
        {
            return systemImageName(
                activityID: quickPick.activityID, categoryID: quickPick.categoryID)
        }

        return "figure.walk"
    }

    private func systemImageName(activityID: String, categoryID: String) -> String {
        switch activityID {
        case WorkoutActivityDefinition.Constants.cardio:
            switch categoryID {
            case "outdoor-run", "trail-run", "track-run":
                return "figure.run"
            case "indoor-run":
                return "treadmill"
            case "walking":
                return "figure.walk"
            case "hiking":
                return "figure.hiking"
            default:
                return "figure.run"
            }
        case WorkoutActivityDefinition.Constants.cycling:
            return "bicycle"
        case WorkoutActivityDefinition.Constants.gymStrength:
            switch categoryID {
            case "flexibility":
                return "figure.flexibility"
            case "hiit":
                return "figure.highintensity.intervaltraining"
            default:
                return "dumbbell"
            }
        case WorkoutActivityDefinition.Constants.mindBody:
            switch categoryID {
            case "yoga":
                return "figure.yoga"
            case "tai-chi", "mindful-cooldown":
                return "figure.mind.and.body"
            case "pilates":
                return "figure.pilates"
            default:
                return "figure.mind.and.body"
            }
        case WorkoutActivityDefinition.Constants.waterSports:
            switch categoryID {
            case "pool-swim", "open-water-swim":
                return "figure.pool.swim"
            case "rowing":
                return "figure.rowing"
            case "surfing":
                return "figure.surfing"
            case "paddleboarding":
                return "figure.stand.paddle"
            case "kayaking":
                return "figure.kayaking"
            default:
                return "drop"
            }
        case WorkoutActivityDefinition.Constants.winterSports:
            switch categoryID {
            case "snowboarding":
                return "figure.snowboarding"
            case "skiing", "cross-country-skiing":
                return "figure.skiing.downhill"
            default:
                return "snowflake"
            }
        case WorkoutActivityDefinition.Constants.combatMixed:
            switch categoryID {
            case "boxing", "kickboxing":
                return "figure.boxing"
            case "martial-arts":
                return "figure.martial.arts"
            case "dance-cardio":
                return "figure.dance"
            default:
                return "figure.martial.arts"
            }
        case WorkoutActivityDefinition.Constants.teamField:
            switch categoryID {
            case "football":
                return "figure.american.football"
            case "basketball":
                return "figure.basketball"
            case "volleyball":
                return "figure.volleyball"
            case "hockey":
                return "figure.hockey"
            case "cricket":
                return "figure.cricket"
            case "rugby":
                return "figure.rugby"
            default:
                return "figure.team.sports"
            }
        case WorkoutActivityDefinition.Constants.racketPrecision:
            switch categoryID {
            case "tennis":
                return "figure.tennis"
            case "badminton":
                return "figure.badminton"
            case "table-tennis":
                return "figure.table.tennis"
            case "golf":
                return "figure.golf"
            case "pickleball":
                return "figure.pickleball"
            default:
                return "figure.racket.sports"
            }
        case WorkoutActivityDefinition.Constants.others:
            switch categoryID {
            case "climbing":
                return "figure.climbing"
            case "dance":
                return "figure.dance"
            case "fitness-gaming":
                return "gamecontroller"
            case WorkoutActivityDefinition.Constants.healthKitImport:
                return "heart"
            default:
                return "figure.walk"
            }
        default:
            return "figure.walk"
        }
    }
}

private struct RecommendationWrappedText: View {
    let systemImageName: String
    let highlightedText: String
    @State private var height: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            RecommendationWrappedTextView(
                width: proxy.size.width,
                height: $height,
                systemImageName: systemImageName,
                highlightedText: highlightedText
            )
            .frame(height: height)
        }
        .frame(height: height)
    }
}

private struct CapsuleCornerShape: Shape {
    enum Edge {
        case leading
        case trailing
    }

    let outerRadius: CGFloat
    let innerRadius: CGFloat
    let innerEdge: Edge

    func path(in rect: CGRect) -> Path {
        let leadingRadius = innerEdge == .leading ? innerRadius : outerRadius
        let trailingRadius = innerEdge == .trailing ? innerRadius : outerRadius
        let radii = RectangleCornerRadii(
            topLeading: leadingRadius,
            bottomLeading: leadingRadius,
            bottomTrailing: trailingRadius,
            topTrailing: trailingRadius
        )
        return Path(roundedRect: rect, cornerRadii: radii)
    }
}

private struct RecommendationWrappedTextView: UIViewRepresentable {
    let width: CGFloat
    @Binding var height: CGFloat
    let systemImageName: String
    let highlightedText: String

    func makeUIView(context: Context) -> RecommendationWrappedTextContainer {
        RecommendationWrappedTextContainer()
    }

    func updateUIView(_ uiView: RecommendationWrappedTextContainer, context: Context) {
        uiView.update(
            systemImageName: systemImageName,
            highlightedText: highlightedText
        )
        let targetSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        let size = uiView.sizeThatFits(targetSize)
        if abs(size.height - height) > 0.5 {
            DispatchQueue.main.async {
                height = size.height
            }
        }
    }
}

private final class RecommendationWrappedTextContainer: UIView {
    private let imageView = UIImageView()
    private let textView = UITextView()

    private let imageSize = CGSize(width: 56, height: 56)
    private let imagePadding: CGFloat = 12

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear

        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor.secondaryLabel
        imageView.translatesAutoresizingMaskIntoConstraints = false

        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.isSelectable = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(textView)
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.widthAnchor.constraint(equalToConstant: imageSize.width),
            imageView.heightAnchor.constraint(equalToConstant: imageSize.height),

            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func update(systemImageName: String, highlightedText: String) {
        let configuration = UIImage.SymbolConfiguration(pointSize: 40, weight: .semibold)
        imageView.image = UIImage(systemName: systemImageName, withConfiguration: configuration)

        let baseFont = UIFont.preferredFont(forTextStyle: .body)
        let boldFont = UIFont.boldSystemFont(ofSize: baseFont.pointSize)
        let accentColor = UIColor.tintColor
        let primaryColor = UIColor.label

        let text = NSMutableAttributedString(
            string: "We recommend ",
            attributes: [
                .font: baseFont,
                .foregroundColor: primaryColor,
            ]
        )
        let highlighted = NSAttributedString(
            string: highlightedText,
            attributes: [
                .font: boldFont,
                .foregroundColor: accentColor,
            ]
        )
        let tail = NSAttributedString(
            string: " today. It should give you a nice boost of energy.",
            attributes: [
                .font: baseFont,
                .foregroundColor: primaryColor,
            ]
        )
        text.append(highlighted)
        text.append(tail)
        textView.attributedText = text

        setNeedsLayout()
        layoutIfNeeded()

        let imageFrame = convert(imageView.frame, to: textView)
        let paddedFrame = imageFrame.insetBy(dx: -imagePadding, dy: -4)
        textView.textContainer.exclusionPaths = [UIBezierPath(rect: paddedFrame)]
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let targetSize = CGSize(width: size.width, height: .greatestFiniteMagnitude)
        let measuredSize = textView.sizeThatFits(targetSize)
        return CGSize(width: size.width, height: max(measuredSize.height, imageSize.height))
    }
}

private struct WorkoutSuggestionsSection: View {
    @ObservedObject var viewModel: WorkoutsViewModel
    let recommendations: [ShoppingRecommendation]
    let isLoadingRecommendations: Bool
    let onRefreshRecommendations: () -> Void
    let onDismissRecommendation: (String) -> Void
    let onAddWorkout: () -> Void
    let highlightedSuggestion: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Other suggestions")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.quickPicks) { pick in
                        suggestionChip(
                            title: pick.label,
                            backgroundColor: Color(.systemGray6),
                            isHighlighted: highlightedSuggestion == pick.label
                        ) {
                            viewModel.applyQuickPick(pick)
                            onAddWorkout()
                        }
                    }

                    ForEach(recommendations) { rec in
                        let label = rec.quickPickDefinition?.label ?? rec.title
                        suggestionChip(
                            title: label,
                            backgroundColor: Color.accentColor.opacity(0.12),
                            showDismiss: true,
                            dismissAction: { onDismissRecommendation(rec.id) },
                            isHighlighted: highlightedSuggestion == label
                        ) {
                            if let quickPick = rec.quickPickDefinition {
                                viewModel.applyQuickPick(quickPick)
                                onAddWorkout()
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }

            // if recommendations.isEmpty && !isLoadingRecommendations {
            //     Text("No AI suggestions yet. Tap refresh to fetch new ideas!")
            //         .font(.footnote)
            //         .foregroundStyle(.secondary)
            // }
        }
    }

    private func suggestionChip(
        title: String,
        subtitle: String? = nil,
        backgroundColor: Color,
        showDismiss: Bool = false,
        dismissAction: (() -> Void)? = nil,
        isHighlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isHighlighted ? .primary : Color.secondary)
                    Spacer(minLength: 4)
                    if showDismiss, let dismissAction {
                        Button(action: dismissAction) {
                            Image(systemName: "xmark.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isHighlighted ? Color.primary.opacity(0.75) : .secondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: 220, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(.plain)
    }
}

extension ShoppingRecommendation {
    fileprivate var quickPickDefinition: WorkoutQuickPickDefinition? {
        guard let metadata else { return nil }
        let activity =
            metadata["activityID"] ?? metadata["activity_id"]
            ?? WorkoutActivityDefinition.Constants.cardio
        let category =
            metadata["categoryID"] ?? metadata["category_id"]
            ?? WorkoutActivityDefinition.Constants.cardio
        let duration =
            metadata["duration"] ?? metadata["durationMinutes"] ?? metadata["duration_minutes"]
        let calories = metadata["calories"]
        let filteredParameters = metadata.filter { key, _ in
            ![
                "activityID", "activity_id", "categoryID", "category_id", "duration",
                "durationMinutes",
                "duration_minutes", "calories",
            ].contains(key)
        }

        return WorkoutQuickPickDefinition(
            label: title,
            activityID: activity,
            categoryID: category,
            duration: duration,
            calories: calories,
            parameterPrefill: filteredParameters
        )
    }
}
