import UIKit

/// Soft taps that match what the lava is doing.
@MainActor
final class Haptics {
    static let shared = Haptics()
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)

    func play(_ kind: String) {
        switch kind {
        case "light": light.impactOccurred(intensity: 0.5)          // a bubble pops
        case "soft": soft.impactOccurred(intensity: 0.8)            // two blobs merge: a squish
        case "rigid": rigid.impactOccurred(intensity: 0.45)         // a blob splits under your finger
        case "breathIn": soft.impactOccurred(intensity: 0.55)       // start of an in-breath
        case "breathOut": soft.impactOccurred(intensity: 0.3)       // start of an out-breath
        default: light.impactOccurred()
        }
    }
}
