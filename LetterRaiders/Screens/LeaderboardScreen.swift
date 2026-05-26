import SwiftUI

struct LeaderboardScreen: View {
    var tab: LBTab = .global
    var onBack: () -> Void = {}
    @State private var current: LBTab

    init(tab: LBTab = .global, onBack: @escaping () -> Void = {}) {
        self.tab = tab
        self.onBack = onBack
        _current = State(initialValue: tab)
    }

    enum LBTab: String, CaseIterable, Identifiable {
        case global, friends, weekly
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    private let ranks: [(rank: Int, name: String, score: Int, wave: Int, isYou: Bool, color: Color?)] = [
        (1, "kit/maru",       412800, 24, false, Theme.pinkSoft),
        (2, "vega.zeroth",    388200, 22, false, Theme.cyan),
        (3, "_alpha_.io",     351040, 19, false, Theme.violet),
        (4, "haru.ono",       312220, 18, false, nil),
        (5, "rover_404",      287610, 17, false, nil),
        (6, "neon_drift",     244120, 15, false, nil),
        (7, "yui.kobayashi",  220840, 14, false, nil),
        (8, "Cmdr Nyx",       142860, 11, true,  nil),
        (9, "wraith_signal",  138970, 10, false, nil),
        (10, "blue.sun",      126200,  9, false, nil),
        (11, "echo.spark",    119540,  9, false, nil),
    ]

    var body: some View {
        PhoneShell {
            VStack(spacing: 0) {
                PageHeader(title: "Leaderboard", onBack: onBack) {
                    Button {} label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 38, height: 38)
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.white.opacity(0.06)).overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)

                tabs.padding(.horizontal, 20)

                podium.padding(.top, 20).padding(.horizontal, 20)

                listCard.padding(.top, 16).padding(.horizontal, 16)

                Spacer()
            }
        }
    }

    private var tabs: some View {
        HStack(spacing: 4) {
            ForEach(LBTab.allCases) { t in
                Button {
                    current = t
                } label: {
                    let on = current == t
                    Text(t.label)
                        .font(AppFont.display(13, weight: .semibold))
                        .foregroundColor(on ? .white : Color.white.opacity(0.6))
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule()
                                .fill(on
                                      ? AnyShapeStyle(LinearGradient(colors: [Theme.pink, Theme.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
                                      : AnyShapeStyle(Color.clear))
                                .shadow(color: on ? Theme.pink.opacity(0.35) : .clear, radius: 6, y: 6)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.05))
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    private var podium: some View {
        HStack(alignment: .bottom, spacing: 10) {
            podiumColumn(entry: ranks[1], rank: 2, height: 86)
            podiumColumn(entry: ranks[0], rank: 1, height: 114, isCrown: true)
            podiumColumn(entry: ranks[2], rank: 3, height: 68)
        }
    }

    private func podiumColumn(entry: (rank: Int, name: String, score: Int, wave: Int, isYou: Bool, color: Color?),
                              rank: Int, height: CGFloat, isCrown: Bool = false) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .top) {
                Circle()
                    .fill(
                        entry.color.map { c in
                            AnyShapeStyle(LinearGradient(colors: [c, c.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        } ?? AnyShapeStyle(LinearGradient(colors: [Theme.pink, Theme.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(entry.name.prefix(2).uppercased())
                            .font(AppFont.mono(16, weight: .bold))
                            .foregroundColor(Theme.void)
                    )
                    .shadow(color: (entry.color ?? Theme.pink).opacity(0.5), radius: 14)

                if isCrown {
                    Image(systemName: "crown.fill")
                        .foregroundColor(Theme.yellow)
                        .font(.system(size: 18))
                        .offset(y: -22)
                        .shadow(color: Theme.yellow.opacity(0.7), radius: 6)
                }
            }
            Text(entry.name).font(AppFont.display(12, weight: .semibold))
            Text("\(Double(entry.score) / 1000, specifier: "%.1f")k")
                .font(AppFont.mono(11, weight: .regular))
                .foregroundColor(Color.white.opacity(0.55))

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    rank == 1
                    ? AnyShapeStyle(LinearGradient(colors: [Theme.yellow.opacity(0.4), Theme.yellow.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(LinearGradient(colors: [Theme.violet.opacity(0.3), Theme.violet.opacity(0.04)], startPoint: .top, endPoint: .bottom))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .frame(height: height)
                .overlay(
                    Text("\(rank)")
                        .font(AppFont.mono(26, weight: .bold))
                        .foregroundColor(rank == 1 ? Theme.yellow : Color.white.opacity(0.7))
                        .shadow(color: rank == 1 ? Theme.yellow.opacity(0.6) : .clear, radius: 8)
                )
        }
        .frame(maxWidth: .infinity)
    }

    private var listCard: some View {
        VStack(spacing: 4) {
            ForEach(ranks.dropFirst(3).prefix(8), id: \.rank) { r in
                HStack(spacing: 12) {
                    Text("\(r.rank)")
                        .font(AppFont.mono(12, weight: .semibold))
                        .foregroundColor(r.isYou ? Theme.pinkSoft : Color.white.opacity(0.4))
                        .frame(width: 24)
                    Circle()
                        .fill(r.isYou ? AnyShapeStyle(LinearGradient(colors: [Theme.pink, Theme.violet], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.white.opacity(0.08)))
                        .frame(width: 28, height: 28)
                        .overlay(Text(r.name.prefix(2).uppercased()).font(AppFont.mono(10, weight: .semibold)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(r.isYou ? "\(r.name) (you)" : r.name)
                            .font(AppFont.display(13, weight: r.isYou ? .bold : .medium))
                            .lineLimit(1)
                        Text("WAVE \(r.wave)")
                            .font(AppFont.mono(10, weight: .regular))
                            .tracking(0.6)
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    Spacer()
                    Text("\(r.score)")
                        .font(AppFont.mono(13, weight: .bold))
                        .foregroundColor(r.isYou ? .white : Color.white.opacity(0.85))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(r.isYou
                              ? AnyShapeStyle(LinearGradient(colors: [Theme.pink.opacity(0.15), Theme.violet.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                              : AnyShapeStyle(Color.clear))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(r.isYou ? Theme.pink.opacity(0.35) : .clear, lineWidth: 1))
                )
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Theme.void.opacity(0.6))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }
}
