import SwiftUI

struct TitleScreen: View {
    var onPlay: () -> Void = {}
    var onContinue: () -> Void = {}
    var onDaily: () -> Void = {}
    var onShips: () -> Void = {}
    var onRanks: () -> Void = {}
    var onSettings: () -> Void = {}
    var onHelp: () -> Void = {}
    // Active-run state used to render the Continue card. When `hasActiveRun`
    // is false the card is hidden entirely.
    var hasActiveRun: Bool = false
    var currentRaid: Int = 1
    var currentScore: Int = 0
    var currentLives: Int = 3
    var livesMax: Int = 3

    @AppStorage("highScore") private var highScore: Int = 0
    @AppStorage(Hangar.coinKey) private var coins: Int = Hangar.startingCoins
    @AppStorage(Hangar.lifeKey) private var lifeStock: Int = Hangar.maxLives
    /// Drives the daily-teaser "Available in" state when today is already played.
    @AppStorage(DailyState.lastAttemptDayKey) private var dailyLastAttemptDay: String = ""
    /// Live player XP so the avatar pill auto-updates after a run.
    @AppStorage(PlayerProfile.xpKey) private var playerXP: Int = 0
    /// Live player nickname (editable from Settings → Account).
    @AppStorage(PlayerProfile.nicknameKey) private var playerNickname: String = PlayerProfile.defaultNickname
    @State private var float: Bool = false
    @State private var showingCoinStore = false
    /// The five hero tiles. Letters / values / tiers are reshuffled every
    /// time the title appears so the home screen looks fresh on each visit.
    /// Sizes and bob offsets stay fixed so the visual choreography is stable.
    @State private var heroTiles: [HeroTileSpec] = TitleScreen.makeHeroTiles()

    var body: some View {
        PhoneShell {
            VStack(spacing: 0) {
                topRow
                hero
                // Flexible space pushes the action cluster (Continue, Launch,
                // Daily) toward the bottom, sitting just above the TabBar.
                Spacer(minLength: 24)
                if hasActiveRun {
                    continueCard
                    Spacer().frame(height: 14)
                }
                PrimaryButton(title: "LAUNCH MISSION", icon: "play.fill", fontSize: 18, verticalPadding: 20) {
                    Haptics.impact(.medium)
                    onPlay()
                }
                    .padding(.horizontal, 20)
                dailyTeaser
                // Tiny breath before the TabBar safeAreaInset takes over.
                Spacer().frame(height: 12)
            }
            .padding(.top, 8)
            // Anchor the TabBar as a bottom safe-area inset rather than a
            // free-floating overlay, so SwiftUI subtracts its height from the
            // content's vertical space. On SE this prevents the daily teaser
            // from sliding behind the tabs; on Pro Max the extra space is
            // absorbed naturally by the flexible Spacer above.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                TabBar(active: .play) { id in
                    switch id {
                    case .daily: onDaily()
                    case .ships: onShips()
                    case .ranks: onRanks()
                    case .play:  break
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { float = true }
            heroTiles = Self.makeHeroTiles()
        }
        .sheet(isPresented: $showingCoinStore) {
            CoinStoreSheet { showingCoinStore = false }
        }
    }

    private static func makeHeroTiles() -> [HeroTileSpec] { TitleScreenHelpers.makeHeroTiles() }

    private var topRow: some View {
        HStack {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Theme.pink, Theme.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 28, height: 28)
                        .shadow(color: Theme.pink.opacity(0.55), radius: 8)
                    // Re-derive initials from the live nickname so the
                    // monogram tracks the user's edits without going stale.
                    Text(PlayerProfile.nicknameInitials).font(AppFont.mono(12, weight: .bold))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(playerNickname).font(AppFont.display(12, weight: .semibold))
                    Text("RANK \(RankSystem.rank(forXP: playerXP)) · \(RankSystem.title(forRank: RankSystem.rank(forXP: playerXP)).uppercased())")
                        .font(AppFont.mono(9, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.5))
                        .tracking(0.9)
                }
            }
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.06))
                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
            )

            Spacer()

            HStack(spacing: 8) {
                Button {
                    Haptics.select()
                    onHelp()
                } label: {
                    Image(systemName: "questionmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.06))
                                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)

                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.06))
                                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    private var hero: some View {
        VStack(spacing: 36) {
            // Floating tiles row — staggered y-offsets give a casual "drifting"
            // arrangement instead of a rigid line-up. `float` toggles each tile
            // up/down a few pt for a continuous bob.
            HStack(spacing: 18) {
                ForEach(Array(heroTiles.enumerated()), id: \.element.id) { _, t in
                    FlippingHeroTile(initial: t)
                        .offset(y: float ? t.bobUp : t.bobDown)
                }
            }
            .frame(height: 60)
            .padding(.top, 12)

            VStack(spacing: 10) {
                Wordmark(size: 56)
                highScoreChip
                coinsChip
                livesChip
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    private var coinsChip: some View {
        HStack(spacing: 8) {
            Circle().fill(Theme.yellow).frame(width: 10, height: 10)
                .shadow(color: Theme.yellow, radius: 4)
            Text("COINS")
                .font(AppFont.mono(10, weight: .regular))
                .tracking(2.4)
                .foregroundColor(Color.white.opacity(0.55))
            Text("\(coins)")
                .font(AppFont.mono(11, weight: .bold))
                .tracking(1.6)
                .foregroundColor(Theme.yellow)
            Image(systemName: "plus")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Theme.yellow)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Theme.yellow.opacity(0.08))
                .overlay(Capsule().stroke(Theme.yellow.opacity(0.3), lineWidth: 1))
        )
        .contentShape(Capsule())
        .onTapGesture {
            Haptics.select()
            showingCoinStore = true
        }
    }

    private var livesChip: some View {
        let lowLives = lifeStock <= 0
        return HStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.red)
                .shadow(color: Theme.red.opacity(0.6), radius: 4)
            Text("LIVES")
                .font(AppFont.mono(10, weight: .regular))
                .tracking(2.4)
                .foregroundColor(Color.white.opacity(0.55))
            Text("\(lifeStock) / \(Hangar.maxLives)")
                .font(AppFont.mono(11, weight: .bold))
                .tracking(1.6)
                .foregroundColor(lowLives ? Theme.red : Theme.pinkSoft)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill((lowLives ? Theme.red : Theme.pinkSoft).opacity(0.08))
                .overlay(Capsule().stroke((lowLives ? Theme.red : Theme.pinkSoft).opacity(0.3), lineWidth: 1))
        )
        .contentShape(Capsule())
    }

    private var highScoreChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.yellow)
            Text("HIGH SCORE")
                .font(AppFont.mono(10, weight: .regular))
                .tracking(2.4)
                .foregroundColor(Color.white.opacity(0.55))
            Text("\(highScore)")
                .font(AppFont.mono(11, weight: .bold))
                .tracking(1.6)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.05))
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        )
    }

    private var continueCard: some View {
        let livesFrac = livesMax > 0 ? max(0, min(1, Double(currentLives) / Double(livesMax))) : 0
        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .frame(width: 52, height: 52)
                Ship(size: 36)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("CONTINUE · RAID \(currentRaid) · LIVES \(currentLives)/\(livesMax)")
                    .font(AppFont.mono(9.5, weight: .regular))
                    .tracking(2)
                    .foregroundColor(Color.white.opacity(0.55))
                Text("\(currentScore) PTS")
                    .font(AppFont.display(16, weight: .bold))
                    .foregroundColor(.white)
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)
                    .overlay(
                        GeometryReader { g in
                            Capsule()
                                .fill(LinearGradient(colors: [Theme.pink, Theme.violet], startPoint: .leading, endPoint: .trailing))
                                .frame(width: g.size.width * livesFrac)
                        }
                    )
                    .padding(.top, 4)
            }
            Spacer()
            Button {
                Haptics.impact(.light)
                onContinue()
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(LinearGradient(colors: [Theme.pink, Theme.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .shadow(color: Theme.pink.opacity(0.5), radius: 8, y: 6)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(
                    colors: [Theme.pink.opacity(0.12), Theme.cyan.opacity(0.08)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.pink.opacity(0.25), lineWidth: 1))
                .shadow(color: Theme.pink.opacity(0.18), radius: 16, y: 12)
        )
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var dailyTeaser: some View {
        // TimelineView gives us a live "resets in HH:MM:SS" countdown
        // without exposing a Timer to the outer view body. Today's puzzle
        // is read inside so the teaser auto-updates if the calendar day
        // rolls over while the screen is open.
        //
        // When today's puzzle has already been attempted we hide the title
        // (it would just nag the player) and show a calm "Available in …"
        // state with the same countdown.
        Button(action: onDaily) {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let puzzle = DailyPuzzleCatalog.puzzle()
                let secs = Int(DailyPuzzleCatalog.secondsUntilNextDay(from: ctx.date))
                let h = secs / 3600
                let m = (secs % 3600) / 60
                let s = secs % 60
                let countdown = String(format: "%02d:%02d:%02d", h, m, s)
                let played = dailyLastAttemptDay == DailyState.dayString()
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient(
                                colors: played
                                    ? [Color.white.opacity(0.15), Color.white.opacity(0.05)]
                                    : [Theme.yellow, Theme.amber],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 48, height: 48)
                            .shadow(color: played ? .clear : Theme.yellow.opacity(0.4), radius: 12)
                        Image(systemName: played ? "checkmark" : "star.fill")
                            .font(.system(size: 22, weight: played ? .bold : .regular))
                            .foregroundColor(played ? Color.white.opacity(0.75) : Theme.void)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        if played {
                            Text("DAILY CHALLENGE · COMPLETED")
                                .font(AppFont.mono(9.5, weight: .regular))
                                .tracking(2)
                                .foregroundColor(Color.white.opacity(0.55))
                            Text("Available in \(countdown)")
                                .font(AppFont.display(15, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        } else {
                            Text("DAILY CHALLENGE · \(countdown)")
                                .font(AppFont.mono(9.5, weight: .regular))
                                .tracking(2)
                                .foregroundColor(Color.white.opacity(0.55))
                            Text("\(puzzle.name) · \(puzzle.tagline)")
                                .font(AppFont.display(15, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color.white.opacity(0.45))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                )
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TitleScreen()
        .preferredColorScheme(.dark)
}

// MARK: - Hero tile spec + builder (file-scope so FlippingHeroTile can see them)

/// Per-tile spec: the visual choreography (size + bob offsets) is stable,
/// but the letter / value / tier reroll on every screen appearance AND on
/// every periodic flip.
fileprivate struct HeroTileSpec: Identifiable {
    let id = UUID()
    let letter: Character
    let value: Int?
    let tier: Int
    let size: CGFloat
    let wild: Bool
    let bobUp: CGFloat
    let bobDown: CGFloat
}

fileprivate enum TitleScreenHelpers {
    /// Build a fresh hero-tile lineup. Keeps the five-tile composition with
    /// the same sizes/offsets as the legacy hardcoded set; just swaps the
    /// letters in each slot. ~15% chance per slot of a ★ wildcard for variety.
    static func makeHeroTiles() -> [HeroTileSpec] {
        let sizes: [CGFloat] = [44, 36, 42, 38, 44]
        let bobs: [(up: CGFloat, down: CGFloat)] = [(-6, 0), (-2, 8), (-10, -2), (-4, 6), (-6, 2)]
        return (0..<5).map { i in
            rerollSpec(size: sizes[i], bobUp: bobs[i].up, bobDown: bobs[i].down)
        }
    }

    /// Roll a fresh tile spec at a fixed slot (size + bob). Used both for
    /// initial layout and for mid-flip re-rolls.
    static func rerollSpec(size: CGFloat, bobUp: CGFloat, bobDown: CGFloat) -> HeroTileSpec {
        let isWild = Double.random(in: 0..<1) < 0.15
        if isWild {
            return HeroTileSpec(letter: "★", value: nil, tier: 5, size: size, wild: true,
                                bobUp: bobUp, bobDown: bobDown)
        }
        let pool: [Character] = Array(LetterData.table.keys)
        let l = pool.randomElement() ?? "E"
        let info = LetterData.table[l]
        return HeroTileSpec(letter: l, value: info?.value, tier: info?.tier ?? 1,
                            size: size, wild: false,
                            bobUp: bobUp, bobDown: bobDown)
    }
}

// MARK: - Flipping hero tile
//
// Each tile owns its own flip cadence — wakes up at random intervals,
// 3D-rotates around its Y axis, swaps the visible letter at the edge-on
// midpoint (when the tile is invisible to the camera), and rotates back to
// face-on. Per-tile schedule keeps the cluster lively without ever
// flipping more than one tile at the same instant.

fileprivate struct FlippingHeroTile: View {
    let initial: HeroTileSpec
    @State private var current: HeroTileSpec
    @State private var rotation: Double = 0

    init(initial: HeroTileSpec) {
        self.initial = initial
        _current = State(initialValue: initial)
    }

    var body: some View {
        LetterTile(letter: current.letter, value: current.value, tier: current.tier,
                   size: current.size, wild: current.wild)
            // Perspective keeps the flip readable as a 3D card flip rather
            // than a flat squash.
            .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .task { await flipLoop() }
    }

    /// Wait a random delay, flip once, repeat forever (task is cancelled
    /// automatically when the view leaves the hierarchy).
    private func flipLoop() async {
        // Stagger the first flip per-tile so they don't all open the loop
        // at the same instant.
        try? await Task.sleep(nanoseconds: UInt64.random(in: 2_500_000_000...6_500_000_000))
        while !Task.isCancelled {
            await flipOnce()
            try? await Task.sleep(nanoseconds: UInt64.random(in: 4_000_000_000...9_000_000_000))
        }
    }

    @MainActor
    private func flipOnce() async {
        // Phase 1 — rotate to 90° (edge-on, tile is invisible at this angle).
        withAnimation(.easeIn(duration: 0.28)) { rotation = 90 }
        try? await Task.sleep(nanoseconds: 280_000_000)
        // At the midpoint: swap the letter and snap to the other edge so the
        // second-half rotation reveals the new face.
        current = TitleScreenHelpers.rerollSpec(size: initial.size,
                                                bobUp: initial.bobUp,
                                                bobDown: initial.bobDown)
        rotation = -90
        // Phase 2 — rotate back to face-on.
        withAnimation(.easeOut(duration: 0.28)) { rotation = 0 }
    }
}
