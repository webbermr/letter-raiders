import SwiftUI

enum LetterTileState {
    case rack
    case word
    case falling
}

struct LetterTile: View {
    let letter: Character
    var value: Int? = nil
    var tier: Int = 1
    var size: CGFloat = 40
    var wild: Bool = false
    var state: LetterTileState = .rack
    var color: Color? = nil
    var selected: Bool = false
    var used: Bool = false
    var pulse: Double = 0   // 0..1, animates falling tile glow
    /// When false, the bottom-right value pip is suppressed. Used by the
    /// in-game rack strip where the values are noisy distraction.
    var showValue: Bool = true

    private var profile: TierProfile { TierTable.profile(tier) }
    private var baseColor: Color { color ?? (wild ? TierTable.wildColor : profile.color) }
    private var glowColor: Color { wild ? TierTable.wildGlow : profile.glow }
    private var displayValue: Int { value ?? LetterData.value(for: letter) }

    private var corner: CGFloat { max(6, size * 0.18) }
    private var innerLetterColor: Color { Color(hex: 0x0A0428) }

    private var primaryGlowRadius: CGFloat {
        switch state {
        case .falling: return 8 + pulse * 10
        case .word:    return 12
        case .rack:    return 8
        }
    }

    private var secondaryGlowRadius: CGFloat {
        switch state {
        case .falling: return 20 + pulse * 14
        case .word:    return 24
        case .rack:    return 16
        }
    }

    var body: some View {
        ZStack {
            background
                .overlay(
                    RoundedRectangle(cornerRadius: corner)
                        .stroke(shade(baseColor, 0.25), lineWidth: 1)
                )
                .overlay(highlightStrip, alignment: .top)
                .overlay(glyph)
                .overlay(valueLabel, alignment: .bottomTrailing)
        }
        .frame(width: size, height: size)
        .opacity(used ? 0.35 : 1.0)
        .offset(y: selected ? -4 : 0)
        .scaleEffect(selected ? 1.04 : 1.0)
        .shadow(color: baseColor, radius: primaryGlowRadius * 0.45)
        .shadow(color: glowColor.opacity(0.55), radius: secondaryGlowRadius * 0.45)
        .animation(.spring(response: 0.18, dampingFraction: 0.6), value: selected)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: corner)
            .fill(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: baseColor, location: 0),
                        .init(color: baseColor, location: 0.38),
                        .init(color: shade(baseColor, -0.18), location: 1),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    .blur(radius: 0.5)
                    .mask(
                        VStack {
                            Rectangle().frame(height: max(1, size * 0.1))
                            Spacer(minLength: 0)
                        }
                    )
            )
    }

    private var highlightStrip: some View {
        LinearGradient(
            gradient: Gradient(colors: [.clear, Color.white.opacity(0.65), .clear]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: max(2, size * 0.08))
        .clipShape(Capsule())
        .padding(.horizontal, size * 0.08)
        .padding(.top, 3)
    }

    private var glyph: some View {
        Text(String(letter))
            .font(AppFont.tile(size * (wild ? 0.7 : 0.58), weight: .heavy))
            .kerning(wild ? 0 : -size * 0.04 * 0.5)
            .foregroundColor(innerLetterColor)
    }

    @ViewBuilder private var valueLabel: some View {
        if !showValue {
            EmptyView()
        } else if wild {
            Text("★")
                .font(AppFont.tile(max(8, size * 0.22), weight: .bold))
                .foregroundColor(innerLetterColor)
                .padding(.trailing, max(3, size * 0.08))
                .padding(.bottom, max(2, size * 0.05))
        } else {
            Text("\(displayValue)")
                .font(AppFont.tile(max(8, size * 0.22), weight: .bold))
                .foregroundColor(innerLetterColor.opacity(0.7))
                .padding(.trailing, max(3, size * 0.08))
                .padding(.bottom, max(2, size * 0.05))
        }
    }

    private func shade(_ color: Color, _ amount: Double) -> Color {
        let resolved = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        let k: CGFloat = amount > 0 ? 1 : 0
        let mag = CGFloat(abs(amount))
        let nr = r + (k - r) * mag
        let ng = g + (k - g) * mag
        let nb = b + (k - b) * mag
        return Color(.sRGB, red: Double(nr), green: Double(ng), blue: Double(nb), opacity: Double(a))
    }
}
