import UIKit
import AudioToolbox

final class HapticSoundPlayer {
    static let shared = HapticSoundPlayer()

    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)

    private init() {}

    func playSelectionTap() {
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
        playClickSound()
    }

    func playPrimaryTap() {
        impactGenerator.prepare()
        impactGenerator.impactOccurred(intensity: 0.85)
        playClickSound()
    }

    private func playClickSound() {
#if os(iOS)
        AudioServicesPlaySystemSound(1105)
#endif
    }
}
