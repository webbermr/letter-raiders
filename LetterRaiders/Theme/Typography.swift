import SwiftUI
import CoreText

enum FontRegistration {
    /// No-op now: every TTF in `Fonts/` is listed in `Info.plist`'s
    /// `UIAppFonts`, so iOS auto-registers them at launch. The previous
    /// `CTFontManagerRegisterFontsForURL` calls re-registered them a second
    /// time at .process scope and produced "GSFont: file already registered"
    /// warnings. Kept as a stub so existing callers don't need to change.
    static func register() {}
}

enum AppFont {
    // Audiowide — single-weight neon-arcade display face. Used everywhere
    // (display AND mono call sites) for a consistent retro look. The
    // `.weight()` modifiers are no-ops for synthetic bolding only.
    static let displayName = "Audiowide-Regular"
    static let monoName = "Audiowide-Regular"
    /// SpaceGrotesk — kept exclusively for letter tiles so the large glyph on
    /// each tile stays legible at a glance (Audiowide's stylised letterforms
    /// get hard to read inside a small tile).
    static let tileName = "SpaceGrotesk"

    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(displayName, size: size).weight(weight)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(monoName, size: size).weight(weight)
    }

    /// Tile-only font. Use for the glyph and value-pip on letter tiles.
    /// `weight` is accepted but intentionally NOT applied — SpaceGrotesk is a
    /// variable-axis font, and SwiftUI's `.weight()` modifier on
    /// `Font.custom` can't drive the `wght` axis (logs a "Unable to update
    /// Font Descriptor's weight" warning per render). The parameter stays so
    /// callers don't need to change; the visual is identical to before
    /// because the previous `.weight()` call was silently failing too.
    static func tile(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        _ = weight  // intentionally unused; see comment above
        return Font.custom(tileName, size: size)
    }
}

struct EyebrowText: View {
    let text: String
    var color: Color = Theme.ink3
    var body: some View {
        Text(text.uppercased())
            .font(AppFont.mono(11, weight: .regular))
            .tracking(2.4)
            .foregroundColor(color)
    }
}
