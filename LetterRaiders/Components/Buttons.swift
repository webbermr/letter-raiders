import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var fontSize: CGFloat = 17
    var verticalPadding: CGFloat = 18
    /// Set `false` to suppress the global `ui_tap` SFX (e.g. for buttons
    /// inside the play stage that already trigger their own audio).
    var sound: Bool = true
    var action: () -> Void

    var body: some View {
        Button {
            if sound { GameAudio.shared.play("ui_tap") }
            action()
        } label: {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                }
                Text(title.uppercased())
                    .font(AppFont.display(fontSize, weight: .bold))
                    .tracking(0.04 * fontSize)
            }
            .foregroundColor(.white)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [Theme.pink, Theme.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                Capsule()
                    .stroke(Theme.pink.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: Theme.pink.opacity(0.35), radius: 12, y: 6)
            .shadow(color: Theme.violet.opacity(0.25), radius: 24, y: 14)
        }
        .buttonStyle(.plain)
    }
}

struct GhostButton: View {
    let title: String
    var icon: String? = nil
    var sound: Bool = true
    var action: () -> Void

    var body: some View {
        Button {
            if sound { GameAudio.shared.play("ui_tap") }
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(AppFont.display(15, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.04))
                    .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}
