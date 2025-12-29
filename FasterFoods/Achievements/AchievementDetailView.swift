import SwiftUI
import UIKit

struct AchievementDetailView: View {
    let achievement: Achievement
    @State private var shareImage: UIImage?
    @State private var isSharing = false
    @State private var showShareOptions = false
    @State private var pendingShareBackground: ShareAchievementBackground?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            AchievementBadgeView(achievement: achievement, itemSize: 140)

            VStack(spacing: 8) {
                Text(achievement.title)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(achievement.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.vertical, 24)
        .navigationTitle("Achievement")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if achievement.isCompleted {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showShareOptions = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share achievement")
                }
            }
        }
        .sheet(isPresented: $showShareOptions) {
            ShareOptionsSheet(achievement: achievement) { option in
                pendingShareBackground = option
            }
        }
        .sheet(isPresented: $isSharing) {
            if let shareImage {
                ShareSheet(
                    activityItems: [
                        shareImage,
                        "I unlocked the \(achievement.title) achievement!",
                    ]
                )
            }
        }
        .onChange(of: showShareOptions) { _, isPresented in
            guard !isPresented, let pendingShareBackground else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                shareImage = renderShareImage(background: pendingShareBackground)
                isSharing = shareImage != nil
                self.pendingShareBackground = nil
            }
        }
    }

    private func renderShareImage(background: ShareAchievementBackground) -> UIImage? {
        let shareSize = CGSize(width: 360, height: 520)
        let shareView = ShareAchievementView(
            achievement: achievement,
            background: background,
            size: shareSize
        )
        if #available(iOS 16.0, *) {
            let renderer = ImageRenderer(content: shareView)
            renderer.scale = UIScreen.main.scale
            renderer.proposedSize = .init(shareSize)
            return renderer.uiImage
        }

        let controller = UIHostingController(rootView: shareView)
        let view = controller.view
        view?.bounds = CGRect(origin: .zero, size: shareSize)
        view?.backgroundColor = UIColor.clear
        view?.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: shareSize, format: format)
        return renderer.image { context in
            view?.layer.render(in: context.cgContext)
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ShareOptionsSheet: View {
    let achievement: Achievement
    let onSelect: (ShareAchievementBackground) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedBackground: ShareAchievementBackground?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                let previewSize = sharePreviewSize(for: UIScreen.main.bounds.size)
                let horizontalInset = max(
                    (UIScreen.main.bounds.size.width - previewSize.width) / 2, 0)

                Text("Choose a background")
                    .font(.headline)

                sharePreviewScroller(previewSize: previewSize, horizontalInset: horizontalInset)

                Button("Share") {
                    guard let selectedBackground else { return }
                    onSelect(selectedBackground)
                    dismiss()
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    selectedBackground == nil
                        ? Color.gray.opacity(0.2) : Color.accentColor.opacity(0.2)
                )
                .foregroundStyle(selectedBackground == nil ? Color.secondary : Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(selectedBackground == nil)

                Spacer()
            }
            .padding()
            .navigationTitle("Share Your Achievements")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            if selectedBackground == nil {
                selectedBackground = colorScheme == .dark ? .dark : .light
            }
        }
    }

    @ViewBuilder
    private func sharePreviewScroller(
        previewSize: CGSize,
        horizontalInset: CGFloat
    ) -> some View {
        if #available(iOS 17.0, *) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(ShareAchievementBackground.allCases) { option in
                        Button {
                            selectedBackground = option
                        } label: {
                            ShareAchievementPreview(
                                achievement: achievement,
                                background: option,
                                isSelected: selectedBackground == option,
                                size: previewSize
                            )
                        }
                        .buttonStyle(.plain)
                        .id(option)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $selectedBackground)
            .contentMargins(.horizontal, horizontalInset, for: .scrollContent)
            .padding(.vertical, 6)
            .frame(height: previewSize.height + 12)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(ShareAchievementBackground.allCases) { option in
                        Button {
                            selectedBackground = option
                        } label: {
                            ShareAchievementPreview(
                                achievement: achievement,
                                background: option,
                                isSelected: selectedBackground == option,
                                size: previewSize
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, horizontalInset)
            }
            .padding(.vertical, 6)
            .frame(height: previewSize.height + 12)
        }
    }

    private func sharePreviewSize(for screenSize: CGSize) -> CGSize {
        let aspectRatio = CGFloat(520.0 / 360.0)
        var previewWidth = screenSize.width * 0.72
        var previewHeight = previewWidth * aspectRatio
        let maxHeight = screenSize.height * 0.7
        if previewHeight > maxHeight {
            previewHeight = maxHeight
            previewWidth = previewHeight / aspectRatio
        }
        return CGSize(width: previewWidth, height: previewHeight)
    }
}

private struct ShareAchievementPreview: View {
    let achievement: Achievement
    let background: ShareAchievementBackground
    let isSelected: Bool
    let size: CGSize

    var body: some View {
        ShareAchievementView(
            achievement: achievement,
            background: background,
            size: size
        )
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isSelected ? Color(red: 0.65, green: 0.9, blue: 0.72) : .clear, lineWidth: 4)
        )
    }
}
