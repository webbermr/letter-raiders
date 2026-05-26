import SwiftUI

enum TabId: String, CaseIterable {
    // `ranks` enum case is reused for the Badges tab so existing call
    // sites keep compiling — only the user-facing label + icon swapped.
    // (The old chart.bar.fill ranks/leaderboard view is hidden for now.)
    case play, daily, ships, ranks

    var label: String {
        switch self {
        case .play: return "Play"
        case .daily: return "Daily"
        case .ships: return "Hangar"
        case .ranks: return "Badges"
        }
    }

    var systemImage: String {
        switch self {
        case .play: return "play.fill"
        case .daily: return "calendar"
        case .ships: return "airplane"
        case .ranks: return "rosette"
        }
    }
}

struct TabBar: View {
    var active: TabId
    var onChange: (TabId) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TabId.allCases, id: \.self) { item in
                Button {
                    GameAudio.shared.play("ui_tap")
                    onChange(item)
                } label: {
                    let on = item == active
                    VStack(spacing: 4) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 20, weight: .semibold))
                        Text(item.label.uppercased())
                            .font(AppFont.display(11, weight: .semibold))
                            .tracking(0.6)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(on ? .white : Color.white.opacity(0.5))
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                on
                                ? AnyShapeStyle(LinearGradient(colors: [Theme.pink.opacity(0.18), Theme.violet.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(Color.clear)
                            )
                    )
                    .shadow(color: on ? Theme.pink.opacity(0.6) : .clear, radius: 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Theme.deep.opacity(0.7))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.4), radius: 10, y: 10)
    }
}

struct PageHeader<Right: View>: View {
    let title: String
    var onBack: (() -> Void)?
    @ViewBuilder var right: () -> Right

    var body: some View {
        HStack {
            Group {
                if let onBack {
                    Button {
                        GameAudio.shared.play("ui_back")
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(
                                Circle().fill(Color.white.opacity(0.06))
                                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                            )
                    }
                } else {
                    Color.clear.frame(width: 38, height: 38)
                }
            }
            Spacer()
            Text(title)
                .font(AppFont.display(17, weight: .bold))
            Spacer()
            HStack { right() }
                .frame(minWidth: 38, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

extension PageHeader where Right == EmptyView {
    init(title: String, onBack: (() -> Void)? = nil) {
        self.init(title: title, onBack: onBack, right: { EmptyView() })
    }
}
