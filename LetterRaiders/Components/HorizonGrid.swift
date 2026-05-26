import SwiftUI

struct HorizonGrid: View {
    var opacity: Double = 0.4

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { ctx, size in
                    // Horizontal lines (perspective)
                    for y in stride(from: 0 as CGFloat, through: size.height, by: 18) {
                        ctx.fill(
                            Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                            with: .color(Theme.pink.opacity(0.35))
                        )
                    }
                    // Vertical lines
                    for x in stride(from: 0 as CGFloat, through: size.width, by: 23) {
                        ctx.fill(
                            Path(CGRect(x: x, y: 0, width: 1, height: size.height)),
                            with: .color(Theme.pink.opacity(0.5))
                        )
                    }
                    // Horizon glow tint
                    ctx.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .linearGradient(
                            Gradient(colors: [.clear, Theme.pink.opacity(0.18), Theme.pink.opacity(0.25)]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: 0, y: size.height)
                        )
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height * 0.45)
            .position(x: geo.size.width / 2, y: geo.size.height * 0.775)
            .rotation3DEffect(.degrees(60), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.6)
            .mask(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black]),
                    startPoint: .top, endPoint: .bottom
                )
            )
            .opacity(opacity)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
