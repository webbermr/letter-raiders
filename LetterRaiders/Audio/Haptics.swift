import SwiftUI
import UIKit

/// Thin wrapper over UIKit's haptic generators. Every call checks the
/// `haptics` UserDefaults flag (toggleable in Settings) so the player can
/// silence the lot in one place. No-op on devices without the Taptic engine.
enum Haptics {
    static var enabled: Bool {
        UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true
    }

    /// Physical "thud" feedback for collisions / impacts. `intensity` 0...1
    /// lets us scale the same style by event weight (small capture = 0.5,
    /// big crash = 1.0).
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light,
                       intensity: CGFloat = 1.0) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: intensity)
    }

    /// "Success / warning / error" semantic feedback. Use for word submission
    /// results, ship destroyed, new personal best, etc. — not for tile taps.
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    /// Light "click" feedback for UI selections — tile taps, button presses,
    /// rack reshuffle. The cheapest haptic; safe to spam.
    static func select() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
