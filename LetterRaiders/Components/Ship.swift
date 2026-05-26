import SwiftUI

struct Ship: View {
    var size: CGFloat = 32
    var color: Color = Theme.cyan
    var accent: Color = Theme.pink
    var glow: Bool = true

    var body: some View {
        Canvas { context, canvasSize in
            // Drawing on a 24×24 design grid scaled to fit.
            let s = canvasSize.width / 24
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { .init(x: x * s, y: y * s) }
            let shadowColor = Color(hex: 0x06031A)

            // ── Wings (drawn first so the hull sits on top) ──────────────
            var leftWing = Path()
            leftWing.move(to: pt(10, 11))      // wing root, leading edge
            leftWing.addLine(to: pt(1, 17))    // wing tip
            leftWing.addLine(to: pt(3, 19.5))  // trailing tip
            leftWing.addLine(to: pt(9, 18))    // wing root, trailing edge
            leftWing.closeSubpath()
            context.fill(leftWing, with: .color(color))

            var rightWing = Path()
            rightWing.move(to: pt(14, 11))
            rightWing.addLine(to: pt(23, 17))
            rightWing.addLine(to: pt(21, 19.5))
            rightWing.addLine(to: pt(15, 18))
            rightWing.closeSubpath()
            context.fill(rightWing, with: .color(color))

            // Inner wing shading for depth
            var leftShade = Path()
            leftShade.move(to: pt(9.5, 12.5))
            leftShade.addLine(to: pt(4, 17))
            leftShade.addLine(to: pt(8.7, 17.4))
            leftShade.closeSubpath()
            context.fill(leftShade, with: .color(shadowColor.opacity(0.4)))

            var rightShade = Path()
            rightShade.move(to: pt(14.5, 12.5))
            rightShade.addLine(to: pt(20, 17))
            rightShade.addLine(to: pt(15.3, 17.4))
            rightShade.closeSubpath()
            context.fill(rightShade, with: .color(shadowColor.opacity(0.4)))

            // Wing-tip accent strips (running lights)
            context.fill(
                Path(roundedRect: CGRect(x: 0, y: 16.5 * s, width: 2 * s, height: 1.4 * s), cornerRadius: 0.4 * s),
                with: .color(accent)
            )
            context.fill(
                Path(roundedRect: CGRect(x: 22 * s, y: 16.5 * s, width: 2 * s, height: 1.4 * s), cornerRadius: 0.4 * s),
                with: .color(accent)
            )

            // ── Main hull ────────────────────────────────────────────────
            var hull = Path()
            hull.move(to: pt(12, 1.5))                                          // nose tip
            hull.addQuadCurve(to: pt(14.5, 8), control: pt(13.8, 3.5))          // upper-right curve
            hull.addLine(to: pt(15, 13))                                         // widest point
            hull.addLine(to: pt(14, 19))                                         // narrow toward engines
            hull.addLine(to: pt(14.5, 21.5))                                     // right engine outer
            hull.addLine(to: pt(13.4, 22))                                       // right engine bottom
            hull.addLine(to: pt(12, 20.8))                                       // dip between engines
            hull.addLine(to: pt(10.6, 22))                                       // left engine bottom
            hull.addLine(to: pt(9.5, 21.5))                                      // left engine outer
            hull.addLine(to: pt(10, 19))
            hull.addLine(to: pt(9, 13))
            hull.addLine(to: pt(9.5, 8))
            hull.addQuadCurve(to: pt(12, 1.5), control: pt(10.2, 3.5))           // upper-left curve
            hull.closeSubpath()
            context.fill(hull, with: .color(color))

            // Hull centre spine — subtle vertical shadow stripe
            context.fill(
                Path(CGRect(x: 11.65 * s, y: 6 * s, width: 0.7 * s, height: 13 * s)),
                with: .color(shadowColor.opacity(0.35))
            )

            // ── Cockpit canopy ───────────────────────────────────────────
            var canopy = Path()
            canopy.move(to: pt(12, 4.8))
            canopy.addQuadCurve(to: pt(13.4, 10.6), control: pt(13.2, 6.4))
            canopy.addQuadCurve(to: pt(10.6, 10.6), control: pt(12, 11.5))
            canopy.addQuadCurve(to: pt(12, 4.8), control: pt(10.8, 6.4))
            canopy.closeSubpath()
            context.fill(canopy, with: .color(Color.white.opacity(0.55)))
            // Specular highlight on the canopy
            context.fill(
                Path(roundedRect: CGRect(x: 11.3 * s, y: 5.8 * s, width: 1.2 * s, height: 1.6 * s), cornerRadius: 0.4 * s),
                with: .color(Color.white.opacity(0.85))
            )

            // ── Twin engine glow ─────────────────────────────────────────
            for x0 in [9.6 as CGFloat, 13.4] {
                let bell = CGRect(x: x0 * s, y: 21 * s, width: 1.0 * s, height: 2.4 * s)
                context.fill(
                    Path(roundedRect: bell, cornerRadius: 0.4 * s),
                    with: .linearGradient(
                        Gradient(stops: [
                            .init(color: .white, location: 0.0),
                            .init(color: accent, location: 0.45),
                            .init(color: accent.opacity(0.0), location: 1.0),
                        ]),
                        startPoint: CGPoint(x: bell.midX, y: bell.minY),
                        endPoint:   CGPoint(x: bell.midX, y: bell.maxY)
                    )
                )
            }

            // ── Forward cannon ───────────────────────────────────────────
            context.fill(
                Path(roundedRect: CGRect(x: 11.7 * s, y: 0, width: 0.6 * s, height: 2 * s), cornerRadius: 0.2 * s),
                with: .color(accent)
            )
        }
        .frame(width: size, height: size)
        .shadow(color: glow ? color.opacity(0.7) : .clear, radius: glow ? 4 : 0)
        .shadow(color: glow ? color.opacity(0.4) : .clear, radius: glow ? 12 : 0)
        .shadow(color: glow ? accent.opacity(0.45) : .clear, radius: glow ? 8 : 0)
    }
}

struct Bullet: View {
    var color: Color = Theme.cyan
    var width: CGFloat = 4
    var height: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(LinearGradient(
                gradient: Gradient(colors: [color, .white]),
                startPoint: .top, endPoint: .bottom
            ))
            .frame(width: width, height: height)
            .shadow(color: color, radius: 4)
            .shadow(color: color.opacity(0.66), radius: 10)
    }
}

struct Bomb: View {
    var color: Color = Theme.red
    var width: CGFloat = 5
    var height: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(LinearGradient(
                gradient: Gradient(colors: [.white, color]),
                startPoint: .top, endPoint: .bottom
            ))
            .frame(width: width, height: height)
            .shadow(color: color, radius: 4)
            .shadow(color: color.opacity(0.66), radius: 10)
    }
}
