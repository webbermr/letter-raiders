import SwiftUI

struct DailyScreen: View {
    var onBack: () -> Void = {}
    var onPlay: () -> Void = {}

    @AppStorage(DailyState.lastAttemptDayKey) private var lastAttemptDay: String = ""
    @AppStorage(DailyState.lastQualifiedKey) private var lastQualified: Bool = false
    @AppStorage(DailyState.lastScoreKey)     private var lastScore: Int = 0
    @AppStorage(DailyState.streakKey)        private var streak: Int = 0
    /// Drives the info sheet — tap the (i) icon in the header to read the
    /// full rules / strategy for today's puzzle.
    @State private var showingInfo: Bool = false

    /// Today's puzzle. Computed once per view-render from the calendar date.
    /// Same for every device on the same day.
    private var puzzle: DailyPuzzle { DailyPuzzleCatalog.puzzle() }
    private var todayString: String { DailyState.dayString() }
    private var hasAttemptedToday: Bool { lastAttemptDay == todayString }

    /// Live countdown to next puzzle. Re-renders every second via TimelineView.
    var body: some View {
        PhoneShell {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                content(now: context.date)
            }
        }
        .sheet(isPresented: $showingInfo) {
            PuzzleInfoSheet(puzzle: puzzle) { showingInfo = false }
        }
    }

    private func content(now: Date) -> some View {
        VStack(spacing: 0) {
            PageHeader(title: "Daily Challenge", onBack: onBack) {
                Button {
                    Haptics.select()
                    showingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.white.opacity(0.06)).overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)

            heroCard(now: now).padding(.horizontal, 20)

            ctaButton.padding(.horizontal, 20).padding(.top, 14)

            if hasAttemptedToday {
                lastResultCard.padding(.horizontal, 20).padding(.top, 14)
            }

            streakCard.padding(.horizontal, 20).padding(.top, 16)

            Spacer()
        }
    }

    private func heroCard(now: Date) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(todayString)")
                    .font(AppFont.mono(10, weight: .bold))
                    .tracking(2.4)
                    .foregroundColor(Theme.yellow)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Theme.void.opacity(0.6)))

                Text("\(puzzle.name).\n\(puzzle.tagline).")
                    .font(AppFont.display(28, weight: .bold))
                    .kerning(-0.84)
                    .foregroundColor(.white)

                Text(puzzle.description)
                    .font(AppFont.mono(11, weight: .regular))
                    .tracking(0.5)
                    .foregroundColor(Color.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)

                modifierChips

                rewardRow(now: now)
            }
            .padding(20)

            LetterTile(letter: heroTileLetter, value: 10, tier: 5, size: 120)
                .opacity(0.4)
                .rotationEffect(.degrees(-12))
                .offset(x: 16, y: -12)
        }
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(LinearGradient(
                    colors: [Theme.yellow.opacity(0.18), Theme.amber.opacity(0.10), Theme.violet.opacity(0.18)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(Theme.yellow.opacity(0.35), lineWidth: 1))
                .shadow(color: Theme.yellow.opacity(0.18), radius: 22, y: 12)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    /// Pick a thematic decorative tile letter that nods to the puzzle.
    private var heroTileLetter: Character {
        switch puzzle.id {
        case "vowel_famine", "vowel_feast", "pangram": return "A"
        case "rare_hunt", "q_storm": return "Q"
        case "wildcard_storm":                          return "★"
        case "speed_run", "bullet_hell":                return "Z"
        case "glass_cannon":                            return "X"
        case "tiny_rack", "big_rack":                   return "K"
        case "pacifist":                                return "P"
        case "long_word":                               return "W"
        case "pure_word":                               return "J"
        case "slow_motion":                             return "S"
        default:                                        return "Q"
        }
    }

    /// Render chips for each non-default modifier so the player sees the
    /// active rules at a glance. Hidden cleanly when a puzzle has none.
    private var modifierChips: some View {
        let chips = describeModifiers(puzzle.modifiers)
        return FlowLayout(spacing: 6, alignment: .leading) {
            ForEach(chips, id: \.0) { chip in
                Text(chip.0)
                    .font(AppFont.mono(9.5, weight: .bold))
                    .tracking(1.8)
                    .foregroundColor(chip.1)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(chip.1.opacity(0.13))
                            .overlay(Capsule().stroke(chip.1.opacity(0.4), lineWidth: 1))
                    )
            }
        }
    }

    /// Surface each modifier as a labelled chip. Order = letter-bag, run
    /// shape, pace, scoring — same as the catalog grouping.
    private func describeModifiers(_ m: PuzzleModifiers) -> [(String, Color)] {
        var out: [(String, Color)] = []
        if !m.bannedLetters.isEmpty {
            let list = m.bannedLetters.sorted().map { String($0) }.joined(separator: " ")
            out.append(("NO \(list)", Theme.red))
        }
        if let only = m.allowedLettersOnly {
            let list = only.sorted().map { String($0) }.joined(separator: " ")
            out.append(("ONLY \(list)", Theme.amber))
        }
        if !m.bagMultipliers.isEmpty {
            let list = m.bagMultipliers.keys.sorted().map { String($0) }.joined(separator: "/")
            let mul = m.bagMultipliers.values.first ?? 1
            out.append(("\(list) ×\(mul)", Theme.violet))
        }
        if m.wildSpawnChance > 0.05 {
            out.append(("★ \(Int(m.wildSpawnChance * 100))%", Theme.yellow))
        }
        if m.lives != 3 {
            out.append(("LIVES \(m.lives)", Theme.red))
        }
        if m.raidSeconds != 30 {
            out.append(("\(Int(m.raidSeconds))S RAID", Theme.cyan))
        }
        if m.holdLimit != 10 {
            out.append(("\(m.holdLimit) LETTERS", Theme.amber))
        }
        if !m.allowZap || !m.allowWild {
            out.append(("NO POWERUPS", Theme.pinkSoft))
        }
        if m.letterSpeedMul != 1.0 {
            out.append((String(format: "%.1f× FALL", m.letterSpeedMul), Theme.cyan))
        }
        if m.bombRateMul != 1.0 {
            out.append((String(format: "%.1f× BOMBS", m.bombRateMul), Theme.red))
        }
        if m.minWordLength > 2 {
            out.append(("\(m.minWordLength)+ LETTERS", Theme.green))
        }
        if m.requireDistinctVowels > 0 {
            out.append(("\(m.requireDistinctVowels)+ VOWELS", Theme.amber))
        }
        if !m.scoreUseBonuses {
            out.append(("BASE + RARE", Theme.violet))
        }
        if m.scoreMultiplier != 1.0 {
            out.append((String(format: "%.0f× SCORE", m.scoreMultiplier), Theme.yellow))
        }
        return out
    }

    private func rewardRow(now: Date) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("RESETS IN")
                    .font(AppFont.mono(9.5, weight: .regular))
                    .tracking(2)
                    .foregroundColor(Color.white.opacity(0.55))
                Text(formatResetsIn(now: now))
                    .font(AppFont.mono(18, weight: .bold))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("REWARD")
                    .font(AppFont.mono(9.5, weight: .regular))
                    .tracking(2)
                    .foregroundColor(Color.white.opacity(0.55))
                HStack(spacing: 4) {
                    Circle().fill(Theme.yellow).frame(width: 14, height: 14)
                    Text("+\(puzzle.coinReward)").font(AppFont.mono(16, weight: .bold))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.void.opacity(0.6))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
        )
    }

    private func formatResetsIn(now: Date) -> String {
        let secs = Int(DailyPuzzleCatalog.secondsUntilNextDay(from: now))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    /// CTA at the top of the action stack. Disabled (greyed) when today's
    /// attempt has already been used.
    @ViewBuilder
    private var ctaButton: some View {
        if hasAttemptedToday {
            GhostButton(title: "ATTEMPTED · COMES BACK TOMORROW", icon: "checkmark.circle.fill") {}
                .opacity(0.6)
                .disabled(true)
        } else {
            PrimaryButton(title: "START RUN · 1 ATTEMPT", fontSize: 15) {
                Haptics.impact(.medium)
                onPlay()
            }
        }
    }

    /// Shown only when the player has played today — surfaces their result.
    private var lastResultCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(lastQualified ? Theme.green.opacity(0.25) : Theme.red.opacity(0.25))
                    .frame(width: 38, height: 38)
                Image(systemName: lastQualified ? "checkmark.seal.fill" : "xmark.octagon.fill")
                    .foregroundColor(lastQualified ? Theme.green : Theme.red)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(lastQualified ? "TODAY'S RESULT" : "TODAY'S RESULT · INCOMPLETE")
                    .font(AppFont.mono(10, weight: .regular))
                    .tracking(2.2)
                    .foregroundColor(Color.white.opacity(0.55))
                Text(lastQualified ? "\(lastScore) PTS · +\(puzzle.coinReward) COINS" : "No valid word — try again tomorrow")
                    .font(AppFont.display(13, weight: .bold))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    /// Streak chip — pip count matches the actual streak from DailyState.
    /// First 8 pips are visible; longer streaks just show "8+" full pips
    /// (streak number is in the label text).
    private var streakCard: some View {
        let visible = max(0, min(8, streak))
        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [Theme.pink, Theme.amber], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                    .shadow(color: Theme.pink.opacity(0.5), radius: 16)
                Image(systemName: "flame.fill")
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("STREAK").font(AppFont.mono(10, weight: .regular)).tracking(2.2).foregroundColor(Color.white.opacity(0.55))
                Text(streak == 0 ? "Start today" : "\(streak) day\(streak == 1 ? "" : "s") · keep it alive")
                    .font(AppFont.display(15, weight: .bold))
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(0..<8, id: \.self) { i in
                    Capsule()
                        .fill(i < visible
                              ? AnyShapeStyle(LinearGradient(colors: [Theme.pink, Theme.violet], startPoint: .top, endPoint: .bottom))
                              : AnyShapeStyle(Color.white.opacity(0.1)))
                        .frame(width: 8, height: 16)
                        .shadow(color: i < visible ? Theme.pink.opacity(0.5) : .clear, radius: 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Theme.pink.opacity(0.12), Theme.violet.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.pink.opacity(0.25), lineWidth: 1))
        )
    }
}

/// Full-screen sheet that surfaces a puzzle's rules + strategy. Opened by
/// the (i) icon in the daily-screen header.
private struct PuzzleInfoSheet: View {
    let puzzle: DailyPuzzle
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Match the in-app cosmos background so the sheet feels native.
            GameBackground(variant: .cosmos)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // Eyebrow + headline
                    Text("DAILY PUZZLE · HOW IT WORKS")
                        .font(AppFont.mono(10, weight: .bold))
                        .tracking(2.4)
                        .foregroundColor(Theme.yellow)

                    Text(puzzle.name)
                        .font(AppFont.display(32, weight: .bold))
                        .kerning(-0.8)
                        .foregroundColor(.white)

                    Text(puzzle.tagline)
                        .font(AppFont.mono(13, weight: .bold))
                        .tracking(1.6)
                        .foregroundColor(Theme.cyanSoft)

                    // Reward chip
                    HStack(spacing: 6) {
                        Circle().fill(Theme.yellow).frame(width: 10, height: 10)
                            .shadow(color: Theme.yellow, radius: 4)
                        Text("+\(puzzle.coinReward) COINS ON SUCCESS")
                            .font(AppFont.mono(10, weight: .bold))
                            .tracking(1.8)
                            .foregroundColor(Theme.yellow)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Theme.yellow.opacity(0.12))
                            .overlay(Capsule().stroke(Theme.yellow.opacity(0.35), lineWidth: 1))
                    )

                    // Tips body — multi-paragraph, mono for that arcade feel.
                    Text(puzzle.tips)
                        .font(AppFont.mono(13, weight: .regular))
                        .foregroundColor(.white)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Close (X) — top-right, always visible above the scroll.
            Button {
                Haptics.select()
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .preferredColorScheme(.dark)
    }
}
