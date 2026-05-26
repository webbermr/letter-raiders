import SwiftUI

enum BackgroundVariant: String, CaseIterable, Identifiable {
    case cosmos, synthwave, vapor, tron, nebula, crt

    var id: String { rawValue }

    var name: String {
        switch self {
        case .cosmos: return "Cosmos"
        case .synthwave: return "Synthwave"
        case .vapor: return "Vaporwave"
        case .tron: return "Arcade Grid"
        case .nebula: return "Nebula Storm"
        case .crt: return "CRT Boot"
        }
    }

    var blurb: String {
        switch self {
        case .cosmos: return "Deep nebula · default"
        case .synthwave: return "Sunset grid · retro '84"
        case .vapor: return "Pastel checker · palm"
        case .tron: return "Wireframe · pitch black"
        case .nebula: return "Warm clouds · twinkle"
        case .crt: return "Terminal · amber moon"
        }
    }

    var accent: Color {
        switch self {
        case .cosmos: return Theme.violet
        case .synthwave: return Theme.pink
        case .vapor: return Theme.cyan
        case .tron: return Theme.green
        case .nebula: return Color(hex: 0xFB923C)
        case .crt: return Color(hex: 0xFBBF24)
        }
    }
}

struct GameBackground: View {
    var variant: BackgroundVariant = .cosmos

    var body: some View {
        ZStack {
            switch variant {
            case .cosmos:    BgCosmos()
            case .synthwave: BgSynthwave()
            case .vapor:     BgVapor()
            case .tron:      BgTron()
            case .nebula:    BgNebula()
            case .crt:       BgCRT()
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Stars

private struct StarsLayer: View {
    let density: Double
    let tint: Color
    let seed: Int
    /// Downward scroll speed for the size-1 (far) star tier, in pt/s. Size-2
    /// (near) stars scroll faster, producing a parallax depth cue.
    let scrollSpeed: Double
    private let stars: [Star]

    init(density: Double = 1.0, tint: Color = .white, seed: Int = 11, scrollSpeed: Double = 8) {
        self.density = density
        self.tint = tint
        self.seed = seed
        self.scrollSpeed = scrollSpeed
        self.stars = Self.makeStars(density: density, seed: seed)
    }

    private static func makeStars(density: Double, seed: Int) -> [Star] {
        var s = seed
        func rnd() -> Double {
            s = (s &* 9301 &+ 49297) % 233280
            return Double(s) / 233280.0
        }
        let n = Int(70 * density)
        var out: [Star] = []
        out.reserveCapacity(n)
        for _ in 0..<n {
            out.append(Star(
                x: rnd(), y: rnd(),
                size: rnd() < 0.85 ? 1 : 2,
                opacity: 0.3 + rnd() * 0.7,
                twinklePhase: rnd() * .pi * 2
            ))
        }
        return out
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    let h = size.height
                    guard h > 0 else { return }
                    for st in stars {
                        // Parallax: nearer (size-2) stars drift ~2.5× faster.
                        let speed = scrollSpeed * (st.size == 2 ? 2.5 : 1.0)
                        let raw = st.y * h + CGFloat(t * speed)
                        let yMod = raw.truncatingRemainder(dividingBy: h)
                        let y = yMod < 0 ? yMod + h : yMod
                        // Subtle ±25% twinkle, phase-offset per star so they're not in sync.
                        let twinkle = 0.75 + 0.25 * sin(t * 1.6 + st.twinklePhase)
                        let rect = CGRect(
                            x: st.x * size.width - st.size / 2,
                            y: y - st.size / 2,
                            width: st.size, height: st.size
                        )
                        ctx.fill(Path(ellipseIn: rect), with: .color(tint.opacity(st.opacity * twinkle)))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    private struct Star {
        let x: Double
        let y: Double
        let size: CGFloat
        let opacity: Double
        let twinklePhase: Double
    }
}

// MARK: - Cosmos

private struct BgCosmos: View {
    var body: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(hex: 0x2A0F5E), location: 0),
                    .init(color: Color(hex: 0x0C0729), location: 0.45),
                    .init(color: Color(hex: 0x06031A), location: 1),
                ]),
                center: .init(x: 0.5, y: 0),
                startRadius: 0,
                endRadius: 800
            )
            .ignoresSafeArea()

            Ellipse()
                .fill(Theme.violet.opacity(0.35))
                .frame(width: 360, height: 360)
                .blur(radius: 60)
                .offset(x: -120, y: -180)

            Ellipse()
                .fill(Theme.cyan.opacity(0.18))
                .frame(width: 320, height: 260)
                .blur(radius: 70)
                .offset(x: 130, y: 50)

            StarsLayer(density: 1.1, tint: .white, seed: 11)
            StarsLayer(density: 0.6, tint: Color(hex: 0xC4B5FD), seed: 37)
        }
    }
}

// MARK: - Synthwave

private struct BgSynthwave: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(hex: 0x1A0033), location: 0),
                        .init(color: Color(hex: 0x3D0A55), location: 0.30),
                        .init(color: Color(hex: 0x7A1858), location: 0.55),
                        .init(color: Color(hex: 0xC2266A), location: 0.75),
                        .init(color: Color(hex: 0xFF5070), location: 0.90),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // sun disc
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color(hex: 0xFFD86B), Color(hex: 0xFF5070), Color(hex: 0xD63384)]),
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 240, height: 240)
                    .shadow(color: Color(hex: 0xFF5070).opacity(0.8), radius: 40)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.44)
                    .overlay(
                        // sun slits
                        VStack(spacing: 6) {
                            ForEach(0..<6, id: \.self) { i in
                                Rectangle()
                                    .fill(Color(hex: 0x1A0033))
                                    .frame(width: max(20, 260 - CGFloat(i) * 32), height: max(1, 6 - CGFloat(i) * 0.6))
                            }
                        }
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.50)
                    )

                // mountain silhouette
                MountainShape()
                    .fill(Color(hex: 0x1A0033))
                    .frame(height: 80)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.68 - 20)

                // perspective grid
                PerspectiveGrid(color: Theme.pink, lineSpacing: 22)
                    .frame(width: geo.size.width, height: geo.size.height * 0.38)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.81)
                    .mask(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black]),
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                // bottom dimmer
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: Theme.void.opacity(0.55), location: 0.7),
                        .init(color: Theme.void.opacity(0.85), location: 1.0),
                    ]),
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: geo.size.height * 0.65)
                .position(x: geo.size.width / 2, y: geo.size.height * 0.675)
            }
        }
        .ignoresSafeArea()
    }
}

private struct MountainShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let h = rect.height
        let w = rect.width
        let pts: [CGPoint] = [
            CGPoint(x: 0, y: h),
            CGPoint(x: w * 0.10, y: h * 0.62),
            CGPoint(x: w * 0.21, y: h * 0.81),
            CGPoint(x: w * 0.33, y: h * 0.44),
            CGPoint(x: w * 0.46, y: h * 0.75),
            CGPoint(x: w * 0.59, y: h * 0.38),
            CGPoint(x: w * 0.74, y: h * 0.69),
            CGPoint(x: w * 0.87, y: h * 0.50),
            CGPoint(x: w, y: h * 0.88),
            CGPoint(x: w, y: h),
        ]
        p.addLines(pts)
        p.closeSubpath()
        return p
    }
}

private struct PerspectiveGrid: View {
    var color: Color
    var lineSpacing: CGFloat = 22

    var body: some View {
        ZStack {
            // horizontal lines, vertical lines
            GeometryReader { geo in
                Canvas { ctx, size in
                    let lineWidth: CGFloat = 1
                    for i in stride(from: 0 as CGFloat, through: size.height, by: lineSpacing) {
                        let rect = CGRect(x: 0, y: i, width: size.width, height: lineWidth)
                        ctx.fill(Path(rect), with: .color(color.opacity(0.35)))
                    }
                    for j in stride(from: 0 as CGFloat, through: size.width, by: lineSpacing) {
                        let rect = CGRect(x: j, y: 0, width: lineWidth, height: size.height)
                        ctx.fill(Path(rect), with: .color(color.opacity(0.35)))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .rotation3DEffect(.degrees(60), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.6)
        .shadow(color: color.opacity(0.5), radius: 6)
    }
}

// MARK: - Vaporwave

private struct BgVapor: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(hex: 0x0B1D3A), location: 0),
                        .init(color: Color(hex: 0x1E3A8A), location: 0.20),
                        .init(color: Color(hex: 0x6D28D9), location: 0.45),
                        .init(color: Color(hex: 0xDB2777), location: 0.70),
                        .init(color: Color(hex: 0xFB7185), location: 0.90),
                    ]),
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                // pastel sun
                Circle()
                    .fill(RadialGradient(
                        gradient: Gradient(colors: [Color(hex: 0xFEF3C7), Color(hex: 0xFBCFE8), Color(hex: 0xF0ABFC)]),
                        center: .center, startRadius: 0, endRadius: 120
                    ))
                    .frame(width: 180, height: 180)
                    .shadow(color: Color(hex: 0xF472B6).opacity(0.6), radius: 50)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.32)

                // palm silhouettes
                PalmShape()
                    .stroke(Color(hex: 0x0B1D3A), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 110, height: 220)
                    .position(x: 60, y: geo.size.height * 0.55)

                PalmShape()
                    .stroke(Color(hex: 0x0B1D3A), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 130, height: 240)
                    .position(x: geo.size.width - 60, y: geo.size.height * 0.52)

                // checker floor
                CheckerFloor()
                    .frame(width: geo.size.width * 2, height: geo.size.height * 0.34)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.83)
                    .rotation3DEffect(.degrees(60), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.5)
                    .mask(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black]),
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                StarsLayer(density: 0.45, tint: Color(hex: 0xFBCFE8), seed: 37)

                LinearGradient(
                    gradient: Gradient(colors: [.clear, Theme.void.opacity(0.5)]),
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: geo.size.height * 0.55)
                .position(x: geo.size.width / 2, y: geo.size.height * 0.725)
            }
        }
        .ignoresSafeArea()
    }
}

private struct PalmShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        // trunk
        p.move(to: CGPoint(x: w * 0.5, y: h))
        p.addQuadCurve(to: CGPoint(x: w * 0.45, y: h * 0.27),
                       control: CGPoint(x: w * 0.52, y: h * 0.64))
        p.addQuadCurve(to: CGPoint(x: w * 0.45, y: h * 0.04),
                       control: CGPoint(x: w * 0.42, y: h * 0.14))
        // fronds
        let top = CGPoint(x: w * 0.45, y: h * 0.04)
        p.move(to: top); p.addQuadCurve(to: CGPoint(x: w * 0.03, y: h * 0.13), control: CGPoint(x: w * 0.20, y: h * 0.06))
        p.move(to: top); p.addQuadCurve(to: CGPoint(x: w * 0.87, y: h * 0.10), control: CGPoint(x: w * 0.65, y: h * 0.06))
        p.move(to: top); p.addQuadCurve(to: CGPoint(x: w * 0.12, y: 0), control: CGPoint(x: w * 0.23, y: -h * 0.03))
        p.move(to: top); p.addQuadCurve(to: CGPoint(x: w * 0.87, y: -h * 0.02), control: CGPoint(x: w * 0.65, y: -h * 0.04))
        return p
    }
}

private struct CheckerFloor: View {
    var body: some View {
        Canvas { ctx, size in
            let cell: CGFloat = 56
            let cols = Int(size.width / cell) + 1
            let rows = Int(size.height / cell) + 1
            for r in 0..<rows {
                for c in 0..<cols {
                    let isPink = (r + c) % 2 == 0
                    let color = isPink ? Theme.pinkSoft.opacity(0.9) : Theme.cyan.opacity(0.9)
                    ctx.fill(
                        Path(CGRect(x: CGFloat(c) * cell, y: CGFloat(r) * cell, width: cell, height: cell)),
                        with: .color(color)
                    )
                }
            }
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(colors: [Theme.void.opacity(0.2), Theme.void.opacity(0.85)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
        }
    }
}

// MARK: - Tron / Arcade Grid

private struct BgTron: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(hex: 0x020208).ignoresSafeArea()

                RadialGradient(
                    gradient: Gradient(colors: [Theme.green.opacity(0.25), .clear]),
                    center: .init(x: 0.5, y: 1), startRadius: 0, endRadius: 600
                )

                // top wireframe
                WireframeGrid(color: Theme.green.opacity(0.35))
                    .frame(width: geo.size.width, height: geo.size.height * 0.55)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.275)
                    .rotation3DEffect(.degrees(-60), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.6)
                    .mask(
                        LinearGradient(
                            gradient: Gradient(colors: [.black, .clear]),
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                // bottom wireframe
                WireframeGrid(color: Theme.green.opacity(0.45))
                    .frame(width: geo.size.width, height: geo.size.height * 0.55)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.725)
                    .rotation3DEffect(.degrees(60), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.6)
                    .mask(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black]),
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                // horizon line
                Rectangle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.clear, Theme.green, .clear]),
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(height: 2)
                    .shadow(color: Theme.green, radius: 6)
                    .shadow(color: Theme.green, radius: 12)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.5)
            }
        }
        .ignoresSafeArea()
    }
}

private struct WireframeGrid: View {
    var color: Color
    var spacing: CGFloat = 30

    var body: some View {
        Canvas { ctx, size in
            let lw: CGFloat = 1
            for i in stride(from: 0 as CGFloat, through: size.height, by: spacing) {
                ctx.fill(Path(CGRect(x: 0, y: i, width: size.width, height: lw)), with: .color(color))
            }
            for j in stride(from: 0 as CGFloat, through: size.width, by: spacing) {
                ctx.fill(Path(CGRect(x: j, y: 0, width: lw, height: size.height)), with: .color(color))
            }
        }
    }
}

// MARK: - Nebula Storm

private struct BgNebula: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(hex: 0x4A1530), location: 0),
                        .init(color: Color(hex: 0x1F0A2E), location: 0.45),
                        .init(color: Color(hex: 0x08051A), location: 1),
                    ]),
                    center: .init(x: 0.3, y: 0.2), startRadius: 0, endRadius: 700
                )
                .ignoresSafeArea()

                Ellipse()
                    .fill(Color(hex: 0xFB923C).opacity(0.45))
                    .frame(width: 380, height: 280)
                    .blur(radius: 90)
                    .position(x: 60, y: 130)

                Ellipse()
                    .fill(Color(hex: 0xF472B6).opacity(0.40))
                    .frame(width: 360, height: 260)
                    .blur(radius: 100)
                    .position(x: geo.size.width - 60, y: 180)

                Ellipse()
                    .fill(Color(hex: 0xD946EF).opacity(0.30))
                    .frame(width: 360, height: 240)
                    .blur(radius: 100)
                    .position(x: geo.size.width / 2, y: geo.size.height - 200)

                Ellipse()
                    .fill(Theme.cyan.opacity(0.18))
                    .frame(width: 240, height: 200)
                    .blur(radius: 80)
                    .position(x: geo.size.width - 40, y: geo.size.height - 120)

                StarsLayer(density: 1.4, tint: .white, seed: 11)
                StarsLayer(density: 0.7, tint: Color(hex: 0xFBCFE8), seed: 37)
                StarsLayer(density: 0.4, tint: Color(hex: 0xFEF3C7), seed: 73)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - CRT Boot

private struct BgCRT: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(hex: 0x0E2A3A), location: 0),
                        .init(color: Color(hex: 0x061620), location: 0.5),
                        .init(color: Color(hex: 0x02080D), location: 1),
                    ]),
                    center: .center, startRadius: 0, endRadius: 600
                )
                .ignoresSafeArea()

                // amber moon
                Circle()
                    .fill(RadialGradient(
                        gradient: Gradient(colors: [Color(hex: 0xFDE68A), Color(hex: 0xFBBF24), Color(hex: 0xB45309)]),
                        center: .init(x: 0.35, y: 0.35), startRadius: 5, endRadius: 100
                    ))
                    .frame(width: 130, height: 130)
                    .shadow(color: Color(hex: 0xFBBF24).opacity(0.5), radius: 40)
                    .shadow(color: Color(hex: 0xFBBF24).opacity(0.25), radius: 90)
                    .position(x: geo.size.width * 0.62, y: geo.size.height * 0.22)

                // horizon glow
                Rectangle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [.clear, Color(hex: 0xFBBF24).opacity(0.6), .clear]),
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(height: 1)
                    .shadow(color: Color(hex: 0xFBBF24).opacity(0.5), radius: 6)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.7)

                // terminal grid
                WireframeGrid(color: Theme.cyan.opacity(0.25), spacing: 26)
                    .frame(width: geo.size.width, height: geo.size.height * 0.32)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.84)
                    .rotation3DEffect(.degrees(60), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.5)
                    .mask(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black]),
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                // CRT scanlines
                ScanlineOverlay(opacity: 0.25)

                // vignette
                RadialGradient(
                    gradient: Gradient(colors: [.clear, Color.black.opacity(0.55)]),
                    center: .center, startRadius: 200, endRadius: 500
                )
                .ignoresSafeArea()

                StarsLayer(density: 0.35, tint: Color(hex: 0x7DD3FC), seed: 37)
            }
        }
        .ignoresSafeArea()
    }
}

struct ScanlineOverlay: View {
    var opacity: Double = 0.018
    var body: some View {
        Canvas { ctx, size in
            let stride: CGFloat = 3
            for y in Swift.stride(from: 0 as CGFloat, through: size.height, by: stride) {
                ctx.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(Color.white.opacity(opacity))
                )
            }
        }
        .blendMode(.overlay)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
