import SwiftUI

struct PhoneShell<Content: View>: View {
    // The faux iOS chrome (status bar + home indicator) is off by default —
    // the real device already provides both, and removing them reclaims screen
    // real estate. Leave the IOSStatusBar / IOSHomeIndicator types in place in
    // case a designer preview ever wants them back.
    var statusbar: Bool = false
    var home: Bool = false
    var time: String = "9:41"
    var statusbarDark: Bool = false
    var homeDark: Bool = false
    var hasBg: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            if hasBg {
                Color.black.ignoresSafeArea()
            } else {
                Theme.cosmos.ignoresSafeArea()
                Starfield()
                    .allowsHitTesting(false)
            }

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if statusbar {
                IOSStatusBar(time: time, dark: statusbarDark)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .allowsHitTesting(false)
            }

            if home {
                VStack {
                    Spacer()
                    IOSHomeIndicator(dark: homeDark)
                        .padding(.bottom, 8)
                }
                .allowsHitTesting(false)
            }
        }
    }
}

struct Starfield: View {
    /// Two parallax layers of stars that drift downward and twinkle.
    /// Generated once (deterministic seed) — animated via TimelineView so the
    /// per-frame cost is just a Canvas redraw, no SwiftUI diffing.
    private struct Star {
        let x: CGFloat        // normalized 0..1
        let baseY: CGFloat    // normalized 0..1
        let size: CGFloat
        let baseAlpha: Double
        let twinkleSpeed: Double  // radians per second
        let twinklePhase: Double
        let driftSpeed: CGFloat   // normalized y/sec — back layer slower
    }

    private static let stars: [Star] = {
        var rng = SeededRNG(seed: 1729)
        var out: [Star] = []
        // Back layer — small, dim, slow.
        for _ in 0..<55 {
            out.append(Star(
                x: rng.unit(),
                baseY: rng.unit(),
                size: 1.0,
                baseAlpha: 0.25 + rng.unit() * 0.35,
                twinkleSpeed: 1.0 + rng.unit() * 1.6,
                twinklePhase: rng.unit() * .pi * 2,
                driftSpeed: 0.018 + CGFloat(rng.unit()) * 0.008
            ))
        }
        // Foreground layer — slightly bigger/brighter, faster.
        for _ in 0..<25 {
            out.append(Star(
                x: rng.unit(),
                baseY: rng.unit(),
                size: 1.5 + CGFloat(rng.unit()) * 0.6,
                baseAlpha: 0.55 + rng.unit() * 0.4,
                twinkleSpeed: 1.4 + rng.unit() * 2.2,
                twinklePhase: rng.unit() * .pi * 2,
                driftSpeed: 0.05 + CGFloat(rng.unit()) * 0.025
            ))
        }
        return out
    }()

    var body: some View {
        // TimelineView gives us a wall-clock `date` on every animation frame
        // without rebuilding the SwiftUI view tree.
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for star in Self.stars {
                    // Drift downward; wrap at the bottom for an infinite field.
                    let yNorm = (star.baseY + CGFloat(t) * star.driftSpeed)
                        .truncatingRemainder(dividingBy: 1.0)
                    let twinkle = (sin(t * star.twinkleSpeed + star.twinklePhase) + 1) / 2   // 0..1
                    let alpha = star.baseAlpha * (0.55 + 0.45 * twinkle)
                    let r = star.size
                    let rect = CGRect(
                        x: star.x * size.width - r,
                        y: yNorm * size.height - r,
                        width: r * 2,
                        height: r * 2
                    )
                    ctx.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(alpha)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// Tiny LCG so the star layout is the same every launch (less visually noisy
/// than re-rolling positions when a view reappears).
private struct SeededRNG {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func unit() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}

struct IOSStatusBar: View {
    var time: String = "9:41"
    var dark: Bool = false

    var body: some View {
        HStack {
            Text(time)
                .font(AppFont.display(17, weight: .semibold))
                .foregroundColor(dark ? .black : .white)
            Spacer()
            HStack(spacing: 6) {
                signal
                wifi
                battery
            }
            .foregroundColor(dark ? .black : .white)
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
        .frame(height: 54, alignment: .top)
    }

    private var signal: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach([4, 6, 8, 11], id: \.self) { h in
                RoundedRectangle(cornerRadius: 0.6)
                    .frame(width: 3, height: CGFloat(h))
            }
        }
    }

    private var wifi: some View {
        Image(systemName: "wifi")
            .font(.system(size: 13, weight: .semibold))
    }

    private var battery: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2.6)
                .stroke(Color.primary.opacity(0.4), lineWidth: 1)
                .frame(width: 22, height: 11)
            RoundedRectangle(cornerRadius: 1.6)
                .frame(width: 19, height: 8)
                .padding(.leading, 1.5)
            RoundedRectangle(cornerRadius: 0.6)
                .opacity(0.4)
                .frame(width: 1.6, height: 4)
                .offset(x: 24)
        }
        .frame(width: 27, height: 12)
    }
}

struct IOSHomeIndicator: View {
    var dark: Bool = false
    var body: some View {
        Capsule()
            .fill(dark ? Color.black : Color.white.opacity(0.9))
            .frame(width: 134, height: 5)
    }
}
