import SwiftUI

enum Theme {
    // Surfaces
    static let void = Color(hex: 0x06031A)
    static let deep = Color(hex: 0x0C0729)
    static let space = Color(hex: 0x160A3A)
    static let rise = Color(hex: 0x1F0F4D)

    // Glass / hairlines
    static let glass = Color.white.opacity(0.04)
    static let glass2 = Color.white.opacity(0.07)
    static let hairline = Color.white.opacity(0.08)
    static let hairline2 = Color.white.opacity(0.14)

    // Neon spectrum
    static let pink = Color(hex: 0xFF2E88)
    static let pinkSoft = Color(hex: 0xFF6DB1)
    static let cyan = Color(hex: 0x22D3EE)
    static let cyanSoft = Color(hex: 0x67E8F9)
    static let violet = Color(hex: 0xA855F7)
    static let violetSoft = Color(hex: 0xC084FC)
    static let lime = Color(hex: 0xC6FF3D)
    static let yellow = Color(hex: 0xFDE047)
    static let amber = Color(hex: 0xFF9F43)
    static let red = Color(hex: 0xFF3B5C)
    static let green = Color(hex: 0x34E89E)

    // Text
    static let ink = Color.white
    static let ink2 = Color.white.opacity(0.78)
    static let ink3 = Color.white.opacity(0.55)
    static let ink4 = Color.white.opacity(0.32)

    // Gradients
    static let cosmos = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color(hex: 0x2A0F5E), location: 0.0),
            .init(color: Color(hex: 0x0C0729), location: 0.45),
            .init(color: Color(hex: 0x06031A), location: 1.0),
        ]),
        startPoint: .top,
        endPoint: .bottom
    )

    static let pinkCyan = LinearGradient(
        gradient: Gradient(colors: [pink, violet, cyan]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let pinkViolet = LinearGradient(
        gradient: Gradient(colors: [pink, violet]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let violetCyan = LinearGradient(
        gradient: Gradient(colors: [violet, cyan]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
