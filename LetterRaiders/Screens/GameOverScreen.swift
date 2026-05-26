import SwiftUI

struct GameOverScreen: View {
    var score: Int = 87420
    var raid: Int = 8
    var bestWord: String = "QUARTZ"
    var lettersUsed: Int = 38
    var bestCombo: Int = 8
    var isNewHigh: Bool = true
    var missionFailed: Bool = false
    var failureReason: String = "Not enough letters captured"
    var prevHigh: Int = 81020
    /// True when the run that just ended was a daily puzzle the player WON.
    /// Drives the dedicated MISSION COMPLETE hero treatment.
    var dailySuccess: Bool = false
    var dailyPuzzleName: String? = nil
    var dailyReward: Int = 0
    /// XP the player banked over the just-finished run. Drives the
    /// rank-progress chip's "+N XP" label and gets visually folded into the
    /// progress bar so the player can see the bar tick up.
    var xpGainedThisRun: Int = 0
    /// Ranks gained this run. If > 0 we pop a celebration sheet on top of
    /// the game-over screen once the run is fully concluded.
    var ranksGainedThisRun: Int = 0
    /// IDs of badges unlocked during this run. Each one fires a celebration
    /// sheet after the rank-up sheet (if any) is dismissed.
    var newlyUnlockedBadgeIDs: [String] = []
    var onReplay: () -> Void = {}
    var onHome: () -> Void = {}
    var onShare: () -> Void = {}

    @AppStorage(Hangar.coinKey) private var coinBalance: Int = Hangar.startingCoins
    @AppStorage(PlayerProfile.xpKey) private var playerXP: Int = 0

    /// One-by-one celebration queue. On appear we enqueue the rank-up (if
    /// any) followed by each newly-unlocked badge; the sheet binds to
    /// `currentCelebration` and `advanceCelebration()` pops the next.
    @State private var celebrationQueue: [Celebration] = []
    @State private var currentCelebration: Celebration? = nil

    private enum Celebration: Identifiable {
        case rankUp(newRank: Int, ranksGained: Int)
        case badge(AchievementInfo)

        // `.sheet(item:)` needs Identifiable. Use a stable string id per
        // case so the same celebration doesn't accidentally re-fire.
        var id: String {
            switch self {
            case .rankUp(let r, _): return "rankUp.\(r)"
            case .badge(let info):  return "badge.\(info.id.rawValue)"
            }
        }
    }
    /// Drives the one-shot tile tumble on appear. Starts false; flips true
    /// inside .onAppear so the scattered tiles fall off-screen.
    @State private var tilesFallen: Bool = false
    /// Randomised hero-tile scatter generated when the screen mounts. 4–6
    /// tiles, random letters/sizes/positions/spin so the abort screen never
    /// looks identical twice.
    @State private var tileSpecs: [FallingTileSpec] = Self.randomTileSpecs()

    private var delta: Int { score - prevHigh }

    private struct FallingTileSpec: Identifiable {
        let id = UUID()
        let letter: Character
        let value: Int?
        let tier: Int
        let size: CGFloat
        let baseRot: Double
        let x: CGFloat
        let baseY: CGFloat
        let tumbleRot: Double
        let delay: Double
        let duration: Double
        let opacity: Double
        let wild: Bool
    }

    /// Generates a fresh scatter of 4–6 tiles. Picks letters from a high-tier
    /// pool (more visual variety in color) plus an occasional wildcard.
    private static func randomTileSpecs() -> [FallingTileSpec] {
        // Pool of higher-value letters — they cover tiers 3/4/5, so the
        // tile colors span the full neon palette instead of being all cyan.
        let letterPool: [Character] = ["Q", "Z", "X", "J", "K", "F", "H", "V", "W", "Y", "B", "M", "P"]
        let count = Int.random(in: 4...6)
        var specs: [FallingTileSpec] = []
        for i in 0..<count {
            let isWild = Double.random(in: 0..<1) < 0.22
            let letter: Character = isWild ? "★" : (letterPool.randomElement() ?? "Q")
            let info = isWild ? nil : LetterData.table[letter]
            let value = info?.value
            let tier = isWild ? 5 : (info?.tier ?? 3)
            specs.append(FallingTileSpec(
                letter: letter,
                value: value,
                tier: tier,
                size: CGFloat.random(in: 28...44),
                baseRot: Double.random(in: -22...22),
                x: CGFloat.random(in: -130...130),
                // Start near the very top of the screen — tiles barely peek
                // into view before the fall kicks them all the way down.
                baseY: CGFloat.random(in: -10...40),
                tumbleRot: Double.random(in: 360...720) * (Bool.random() ? 1 : -1),
                // Stagger the start times across the cascade so they don't
                // drop together; later tiles also fall slightly longer for
                // a more layered "shower" effect.
                delay: Double(i) * 0.09 + Double.random(in: 0...0.08),
                duration: Double.random(in: 1.45...1.70),
                opacity: Double.random(in: 0.40...0.70),
                wild: isWild
            ))
        }
        return specs
    }

    var body: some View {
        PhoneShell {
            // Fixed-height spacers below total enough that on the smaller SE
            // form factor (667pt) the PLAY AGAIN button can hide under the
            // home indicator. Wrapping in a ScrollView guarantees every CTA
            // remains reachable on every device — taller devices simply show
            // everything without ever needing to scroll. `showsIndicators:
            // false` keeps the chrome clean.
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)
                    heroBlock
                    Spacer().frame(height: 26)
                    statsGrid
                    Spacer().frame(height: 14)
                    rankProgress
                    Spacer().frame(height: 18)
                    ctaBlock
                    Spacer().frame(height: 40)
                }
                .frame(maxWidth: .infinity)
            }

            HorizonGrid(opacity: 0.35)

            VStack {
                // Tiles start at the very top of the screen and tumble all
                // the way down (and off the bottom) over the fall animation.
                ZStack {
                    ForEach(tileSpecs) { spec in
                        fallingTile(spec)
                    }
                }
                .frame(height: 80)
                Spacer()
            }
            .allowsHitTesting(false)
        }
        .onAppear(perform: onAppearCelebrate)
        // Celebration queue — shown on top of game over once the player
        // has had a moment to read their score. Plays through rank-up
        // first (if any), then one sheet per badge unlocked this run.
        .sheet(item: $currentCelebration) { celeb in
            switch celeb {
            case .rankUp(let newRank, let ranksGained):
                RankUpCelebrationView(newRank: newRank, ranksGained: ranksGained) {
                    advanceCelebration()
                }
            case .badge(let info):
                BadgeCelebrationView(badge: info) {
                    advanceCelebration()
                }
            }
        }
    }

    /// Pop the next item from the queue. Called by each celebration view's
    /// dismiss handler — keeps the chain rolling without nested presentation.
    private func advanceCelebration() {
        if celebrationQueue.isEmpty {
            currentCelebration = nil
        } else {
            currentCelebration = celebrationQueue.removeFirst()
        }
    }

    private var heroBlock: some View {
        VStack(spacing: 14) {
            if dailySuccess {
                // Daily puzzle won — celebratory green/cyan treatment.
                Text("MISSION COMPLETE")
                    .font(AppFont.mono(11, weight: .bold))
                    .tracking(2.4)
                    .foregroundColor(Theme.void)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [Theme.green, Theme.cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: Theme.green.opacity(0.55), radius: 22)
                    )
                Text("VICTORY")
                    .font(AppFont.mono(48, weight: .bold))
                    .kerning(-1.6)
                    .foregroundStyle(LinearGradient(colors: [Theme.green, Theme.cyan], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Theme.green.opacity(0.45), radius: 24)
                if let name = dailyPuzzleName {
                    Text("DAILY · \(name.uppercased())")
                        .font(AppFont.mono(11, weight: .regular))
                        .tracking(2.4)
                        .foregroundColor(Color.white.opacity(0.65))
                }
                Text("FINAL SCORE")
                    .font(AppFont.mono(10, weight: .regular))
                    .tracking(2.4)
                    .foregroundColor(Color.white.opacity(0.55))
                    .padding(.top, 6)
                scoreText
                rewardChip
                    .padding(.top, 8)
            } else if missionFailed {
                Text("MISSION FAILED")
                    .font(AppFont.mono(11, weight: .bold))
                    .tracking(2.4)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Theme.red)
                            .shadow(color: Theme.red.opacity(0.55), radius: 22)
                    )
                Text("ABORT")
                    .font(AppFont.mono(48, weight: .bold))
                    .kerning(-1.6)
                    .foregroundStyle(LinearGradient(colors: [Theme.red, Theme.pink], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Theme.red.opacity(0.4), radius: 24)
                Text(failureReason.uppercased())
                    .font(AppFont.mono(11, weight: .regular))
                    .tracking(2.4)
                    .foregroundColor(Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Text("FINAL SCORE")
                    .font(AppFont.mono(10, weight: .regular))
                    .tracking(2.4)
                    .foregroundColor(Color.white.opacity(0.55))
                    .padding(.top, 6)
                scoreText
                coinChip
                    .padding(.top, 8)
            } else if isNewHigh {
                Text("NEW PERSONAL BEST")
                    .font(AppFont.mono(11, weight: .bold))
                    .tracking(2.4)
                    .foregroundColor(Theme.void)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [Theme.yellow, Theme.amber], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: Theme.yellow.opacity(0.5), radius: 22)
                    )
                scoreText
                Text("+\(delta) OVER PREVIOUS BEST")
                    .font(AppFont.mono(11, weight: .regular))
                    .tracking(2.4)
                    .foregroundColor(Color.white.opacity(0.55))
            } else {
                EyebrowText(text: "Game Over")
                scoreText
                Text("BEST: \(prevHigh)")
                    .font(AppFont.mono(11, weight: .regular))
                    .tracking(2.4)
                    .foregroundColor(Color.white.opacity(0.55))
            }
        }
    }

    private var coinChip: some View {
        HStack(spacing: 6) {
            Circle().fill(Theme.yellow).frame(width: 10, height: 10)
                .shadow(color: Theme.yellow, radius: 4)
            Text("\(coinBalance) COINS")
                .font(AppFont.mono(11, weight: .bold))
                .tracking(2)
                .foregroundColor(Theme.yellow)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Theme.yellow.opacity(0.12))
                .overlay(Capsule().stroke(Theme.yellow.opacity(0.4), lineWidth: 1))
        )
    }

    /// "+N COINS EARNED · TOTAL M" pill — used on the daily-success hero so
    /// the player sees both the puzzle reward and their new balance.
    private var rewardChip: some View {
        HStack(spacing: 6) {
            Circle().fill(Theme.yellow).frame(width: 10, height: 10)
                .shadow(color: Theme.yellow, radius: 4)
            Text("+\(dailyReward) EARNED · \(coinBalance) TOTAL")
                .font(AppFont.mono(11, weight: .bold))
                .tracking(2)
                .foregroundColor(Theme.yellow)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Theme.yellow.opacity(0.12))
                .overlay(Capsule().stroke(Theme.yellow.opacity(0.4), lineWidth: 1))
        )
    }

    private var scoreText: some View {
        Text("\(score)")
            .font(AppFont.mono(60, weight: .bold))
            .kerning(-2.4)
            .foregroundStyle(
                isNewHigh
                ? LinearGradient(colors: [Theme.yellow, Theme.amber], startPoint: .top, endPoint: .bottom)
                : LinearGradient(colors: [Theme.pinkSoft, Theme.violet], startPoint: .top, endPoint: .bottom)
            )
            .shadow(color: Theme.pink.opacity(0.3), radius: 30)
    }

    private var statsGrid: some View {
        let items: [(label: String, value: String, color: Color)] = [
            ("BEST WORD",    bestWord,                        Theme.green),
            ("LETTERS USED", "\(lettersUsed)",                Theme.pinkSoft),
            ("BEST COMBO",   "×\(bestCombo)",                 Theme.yellow),
            ("RAID REACHED", String(format: "%02d", raid),     Theme.cyan),
        ]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.label)
                        .font(AppFont.mono(9, weight: .regular))
                        .tracking(2)
                        .foregroundColor(Color.white.opacity(0.55))
                    Text(item.value)
                        .font(item.label == "BEST WORD" ? AppFont.display(20, weight: .bold) : AppFont.mono(22, weight: .bold))
                        .foregroundColor(item.color)
                        .shadow(color: item.color.opacity(0.33), radius: 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
                )
            }
        }
        .padding(.horizontal, 20)
    }

    private var rankProgress: some View {
        // Current rank from live XP (PlayerProfile.awardXP has already been
        // called for this run's events by the time the screen renders).
        let currentRank = RankSystem.rank(forXP: playerXP)
        let nextRank = min(RankSystem.maxRank, currentRank + 1)
        let isMaxRank = currentRank >= RankSystem.maxRank
        let currentName = RankSystem.title(forRank: currentRank).uppercased()
        let nextName = RankSystem.title(forRank: nextRank).uppercased()

        // Bar fill = progress within the current rank band.
        let currentThreshold = RankSystem.xpForRank(currentRank)
        let nextThreshold = isMaxRank
            ? currentThreshold
            : (RankSystem.xpForNext(after: currentRank) ?? currentThreshold)
        let bandSize = max(1, nextThreshold - currentThreshold)
        let inBand = max(0, playerXP - currentThreshold)
        let fillFrac = isMaxRank ? 1.0 : min(1.0, Double(inBand) / Double(bandSize))

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(isMaxRank ? "MAX RANK · \(currentName)" : "\(currentName) → \(nextName)")
                    .font(AppFont.mono(10, weight: .regular))
                    .tracking(2)
                    .foregroundColor(Color.white.opacity(0.55))
                Spacer()
                Text("+\(xpGainedThisRun) XP")
                    .font(AppFont.mono(11, weight: .regular))
                    .foregroundColor(.white)
            }
            Capsule()
                .fill(Color.white.opacity(0.08))
                .frame(height: 6)
                .overlay(
                    GeometryReader { g in
                        Capsule()
                            .fill(LinearGradient(colors: [Theme.pink, Theme.violet], startPoint: .leading, endPoint: .trailing))
                            .frame(width: g.size.width * fillFrac)
                            .shadow(color: Theme.pink.opacity(0.5), radius: 6)
                    }
                )
            if !isMaxRank {
                Text("\(inBand) / \(bandSize) XP TO RANK \(nextRank)")
                    .font(AppFont.mono(9.5, weight: .regular))
                    .tracking(1.6)
                    .foregroundColor(Color.white.opacity(0.45))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
        .padding(.horizontal, 20)
    }

    private var ctaBlock: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: "PLAY AGAIN", icon: "play.fill", fontSize: 16) {
                Haptics.impact(.medium)
                onReplay()
            }
            HStack(spacing: 10) {
                GhostButton(title: "Share", icon: "square.and.arrow.up") {
                    Haptics.select()
                    onShare()
                }
                GhostButton(title: "Home", icon: "house.fill") {
                    Haptics.select()
                    onHome()
                }
            }
        }
        .padding(.horizontal, 20)
    }

    /// Fires once when the screen appears with a new personal best.
    /// Notification haptic for the celebration moment.
    private func onAppearCelebrate() {
        if isNewHigh { Haptics.notify(.success) }
        // Small breath, then drop the scattered tiles off the page once.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            tilesFallen = true
        }
        // Build the celebration queue: rank-up first (if any), then one
        // entry per newly-unlocked badge. Kicks off after ~1s so the
        // player reads their final score before being interrupted.
        var queue: [Celebration] = []
        if ranksGainedThisRun > 0 {
            queue.append(.rankUp(
                newRank: RankSystem.rank(forXP: playerXP),
                ranksGained: ranksGainedThisRun
            ))
        }
        for id in newlyUnlockedBadgeIDs {
            if let info = AchievementCatalog.all.first(where: { $0.id.rawValue == id }) {
                queue.append(.badge(info))
            }
        }
        guard !queue.isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            currentCelebration = queue.first
            celebrationQueue = Array(queue.dropFirst())
        }
    }

    /// Renders one tile from a random spec. Tumbles off-screen when
    /// `tilesFallen` flips true. Per-tile timing/distance values live on the
    /// spec for a natural-looking cascade.
    @ViewBuilder
    private func fallingTile(_ spec: FallingTileSpec) -> some View {
        // Fall target = far enough below the visible screen on any device.
        let fallY: CGFloat = 1200
        LetterTile(letter: spec.letter, value: spec.value, tier: spec.tier, size: spec.size, wild: spec.wild)
            .opacity(spec.opacity)
            .rotationEffect(.degrees(tilesFallen ? spec.baseRot + spec.tumbleRot : spec.baseRot))
            .offset(x: spec.x, y: tilesFallen ? fallY : spec.baseY)
            .animation(.easeIn(duration: spec.duration).delay(spec.delay), value: tilesFallen)
    }
}

#Preview {
    GameOverScreen().preferredColorScheme(.dark)
}

/// Celebration sheet shown on top of the game-over screen when the player
/// leveled up during the just-finished run. Triggered with a slight delay
/// so the player reads their score first, then gets the rank-up moment.
private struct RankUpCelebrationView: View {
    let newRank: Int
    let ranksGained: Int          // 1, 2, 3+
    let onDismiss: () -> Void

    /// Coin payout already credited by PlayerProfile.awardXP during the run.
    /// We only need to display it here — re-deriving from rank for the
    /// "Earned" line keeps this view self-contained.
    private var coinRewardSummary: Int {
        // Approximation: 100 × each rank crossed (final rank's bonus only
        // when single-rank; sum across the band when multi-rank).
        guard ranksGained > 0 else { return 0 }
        var total = 0
        for r in (newRank - ranksGained + 1)...newRank {
            total += 100 * r
        }
        return total
    }

    var body: some View {
        ZStack {
            // Match the in-app cosmos so the sheet feels native.
            GameBackground(variant: .cosmos)
                .ignoresSafeArea()
            // Subtle pink/violet wash to push the celebration tone.
            RadialGradient(
                gradient: Gradient(colors: [Theme.pink.opacity(0.35), .clear]),
                center: .center, startRadius: 20, endRadius: 320
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 18) {
                Spacer()

                Text("RANK UP")
                    .font(AppFont.mono(12, weight: .bold))
                    .tracking(3.2)
                    .foregroundColor(Theme.void)
                    .padding(.horizontal, 14).padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [Theme.yellow, Theme.amber],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: Theme.yellow.opacity(0.55), radius: 22)
                    )

                Text("RANK \(newRank)")
                    .font(AppFont.mono(15, weight: .bold))
                    .tracking(2.6)
                    .foregroundColor(Color.white.opacity(0.65))

                Text(RankSystem.title(forRank: newRank).uppercased())
                    .font(AppFont.display(46, weight: .bold))
                    .kerning(-1.4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LinearGradient(
                        colors: [Theme.pinkSoft, Theme.violet, Theme.cyanSoft],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .shadow(color: Theme.pink.opacity(0.5), radius: 24)
                    .padding(.horizontal, 24)

                if ranksGained > 1 {
                    Text("+\(ranksGained) RANKS THIS RUN")
                        .font(AppFont.mono(11, weight: .regular))
                        .tracking(2.2)
                        .foregroundColor(Color.white.opacity(0.55))
                }

                // Coin payout chip.
                HStack(spacing: 8) {
                    Circle().fill(Theme.yellow).frame(width: 12, height: 12)
                        .shadow(color: Theme.yellow, radius: 6)
                    Text("+\(coinRewardSummary) COINS EARNED")
                        .font(AppFont.mono(11, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Theme.yellow)
                }
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Theme.yellow.opacity(0.12))
                        .overlay(Capsule().stroke(Theme.yellow.opacity(0.4), lineWidth: 1))
                )
                .padding(.top, 4)

                Spacer()

                Button {
                    Haptics.impact(.medium)
                    onDismiss()
                } label: {
                    Text("CONTINUE")
                        .font(AppFont.mono(14, weight: .semibold))
                        .tracking(2.8)
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(LinearGradient(colors: [Theme.pink.opacity(0.45), Theme.violet.opacity(0.35)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.pink.opacity(0.55), lineWidth: 1.5))
                        )
                        .shadow(color: Theme.pink.opacity(0.4), radius: 12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Big celebration moment — successful notification haptic on enter.
            Haptics.notify(.success)
        }
    }
}

/// Sister sheet to RankUpCelebrationView — fires once for each badge the
/// player unlocked during the just-finished run. Visually echoes the
/// badges screen (icon coin + name + summary) but presented as a big
/// celebratory takeover with the badge's own accent driving the palette.
private struct BadgeCelebrationView: View {
    let badge: AchievementInfo
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            GameBackground(variant: .cosmos)
                .ignoresSafeArea()
            // Accent-colored radial wash pushes the celebration tone.
            RadialGradient(
                gradient: Gradient(colors: [badge.accent.opacity(0.35), .clear]),
                center: .center, startRadius: 20, endRadius: 320
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 18) {
                Spacer()

                Text("BADGE EARNED")
                    .font(AppFont.mono(12, weight: .bold))
                    .tracking(3.2)
                    .foregroundColor(Theme.void)
                    .padding(.horizontal, 14).padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [badge.accent, badge.accent.opacity(0.7)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(color: badge.accent.opacity(0.55), radius: 22)
                    )

                // Large icon coin — matches the badges-screen treatment
                // but scaled up for the celebration moment.
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [badge.accent.opacity(0.55), badge.accent.opacity(0.20)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 132, height: 132)
                        .overlay(Circle().stroke(badge.accent.opacity(0.7), lineWidth: 1.5))
                        .shadow(color: badge.accent.opacity(0.55), radius: 32)
                    Image(systemName: badge.icon)
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundColor(badge.accent)
                        .shadow(color: badge.accent.opacity(0.7), radius: 14)
                }

                Text(badge.name.uppercased())
                    .font(AppFont.display(34, weight: .bold))
                    .kerning(-1.1)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LinearGradient(
                        colors: [.white, badge.accent],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .shadow(color: badge.accent.opacity(0.45), radius: 18)
                    .padding(.horizontal, 24)

                Text(badge.summary)
                    .font(AppFont.mono(12, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.white.opacity(0.65))
                    .padding(.horizontal, 32)

                Spacer()

                Button {
                    Haptics.impact(.medium)
                    onDismiss()
                } label: {
                    Text("CONTINUE")
                        .font(AppFont.mono(14, weight: .semibold))
                        .tracking(2.8)
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(LinearGradient(colors: [badge.accent.opacity(0.45), badge.accent.opacity(0.20)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(badge.accent.opacity(0.55), lineWidth: 1.5))
                        )
                        .shadow(color: badge.accent.opacity(0.4), radius: 12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Haptics.notify(.success)
        }
    }
}
