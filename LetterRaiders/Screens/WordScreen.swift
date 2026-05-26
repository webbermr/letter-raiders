import SwiftUI

/// Outcome of a Word phase, surfaced to RootView so it can advance the run.
struct WordResult {
    let score: ScoreBreakdown
    let unusedLetters: [CapturedLetter]
}

struct WordScreen: View {
    let rack: [CapturedLetter]
    var layout: WordLayout = .row
    var timed: Bool = true
    var startTime: Double = 60
    var showResult: ScoreBreakdown? = nil
    /// Shoot-up score carried over from Phase 1. Awarded on top of the word
    /// score iff the submitted word is valid; otherwise forfeited.
    var raidScoreBonus: Int = 0
    /// Coins earned during Phase 1, surfaced on the breakdown card so the
    /// player sees the income from the raid that just ended.
    var raidCoinsEarned: Int = 0
    /// Daily-puzzle modifiers. Influences min-word-length / vowel rules /
    /// score multiplier when computing the breakdown.
    var modifiers: PuzzleModifiers = .none
    /// Equipped ship loadout — flows into the score calculation for the
    /// Specter (rare bonus ×) and Singularity (final score ×) perks.
    var loadout: ShipLoadout = ShipLoadout.forID("viper")
    var onSubmit: (WordResult) -> Void = { _ in }
    var onSkip: () -> Void = {}

    @State private var word: [WordSlot] = []
    @State private var timeLeft: Double
    @State private var pickingWildIdx: Int? = nil
    @State private var result: ScoreBreakdown?
    @State private var submitted: Bool = false
    @State private var startedAt: Date = Date()
    @State private var rackOrder: [Int]
    /// Pulses the word-build area red while the timer is in the danger zone.
    /// Driven by a repeating ease-in-out animation when `danger` is true.
    @State private var dangerPulse: Bool = false
    @State private var bonusTime: Double = 0
    @State private var extraTimeUses: Int = 0
    /// First-time word-phase tutorial. Shown ONCE per install when the
    /// player enters Phase 2, freezing the countdown while it's visible.
    @State private var showingPhase2Tutorial: Bool = false
    @AppStorage("seenPhase2Tutorial") private var seenPhase2Tutorial: Bool = false

    // Time-extend mechanic — each tap of "+30s" adds time to the timer and
    // costs a stiff, escalating penalty off the final score. Capped so the
    // player still has to commit to a word. Penalty is cumulative: the values
    // below are the *total* deduction at each use count (index 0 = no uses).
    private let maxExtraTimeUses = 2
    private let extraTimeBonus: Double = 30
    private let extraTimePenaltyTotals: [Int] = [0, 50, 150]

    /// Marginal cost of the *next* extend tap (50 for first use, 100 for second).
    private var nextExtraTimeCost: Int {
        let cur = extraTimeUses
        let nxt = min(cur + 1, extraTimePenaltyTotals.count - 1)
        return extraTimePenaltyTotals[nxt] - extraTimePenaltyTotals[cur]
    }

    private var effectiveMaxTime: Double { startTime + bonusTime }

    /// True when the timer is in the same low-time zone the TimerBadge uses
    /// to flip its number red — drives the word-area red pulse.
    private var danger: Bool {
        guard timed, !submitted else { return false }
        return timeLeft / max(1, effectiveMaxTime) < 0.25
    }

    init(rack: [CapturedLetter],
         layout: WordLayout = .row,
         timed: Bool = true,
         startTime: Double = 60,
         showResult: ScoreBreakdown? = nil,
         raidScoreBonus: Int = 0,
         raidCoinsEarned: Int = 0,
         modifiers: PuzzleModifiers = .none,
         loadout: ShipLoadout = ShipLoadout.forID("viper"),
         onSubmit: @escaping (WordResult) -> Void = { _ in },
         onSkip: @escaping () -> Void = {}) {
        self.rack = rack
        self.layout = layout
        self.timed = timed
        self.startTime = startTime
        self.showResult = showResult
        self.raidScoreBonus = raidScoreBonus
        self.raidCoinsEarned = raidCoinsEarned
        self.modifiers = modifiers
        self.loadout = loadout
        self.onSubmit = onSubmit
        self.onSkip = onSkip
        _timeLeft = State(initialValue: startTime)
        _result = State(initialValue: showResult)
        _submitted = State(initialValue: showResult != nil)
        _rackOrder = State(initialValue: Array(0..<rack.count))
    }

    enum WordLayout { case row, grid }

    struct WordSlot: Identifiable, Equatable {
        let id = UUID()
        let rackIndex: Int
        let tile: CapturedLetter
        var pickedLetter: Character?

        static func == (lhs: WordSlot, rhs: WordSlot) -> Bool { lhs.id == rhs.id }
    }

    private var usedRackIndices: Set<Int> { Set(word.map { $0.rackIndex }) }

    private var currentWord: String {
        word.map { slot -> String in
            if slot.tile.wild {
                if let p = slot.pickedLetter { return String(p) }
                return "?"
            }
            return String(slot.tile.letter)
        }.joined()
    }

    var body: some View {
        PhoneShell(hasBg: true) {
            ZStack {
                GameBackground(variant: .cosmos)

                VStack(spacing: 0) {
                    headerRow
                        .padding(.top, 8)

                    if let result {
                        ScoreBreakdownCard(sc: result, raidScoreBonus: raidScoreBonus, raidCoinsEarned: raidCoinsEarned) {
                            onSubmit(WordResult(score: result, unusedLetters: unusedRackLetters()))
                        }
                            .padding(.top, 18)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    } else {
                        wordSlotView.padding(.top, 18).padding(.horizontal, 16)
                        rackTitle.padding(.top, 22)
                        rackView.padding(.top, 8).padding(.horizontal, 16)
                        Spacer()
                        actionRow.padding(.horizontal, 16).padding(.bottom, 24)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if pickingWildIdx != nil {
                    WildPickerOverlay(onPick: pickWildLetter, onCancel: { pickingWildIdx = nil })
                }

                if showingPhase2Tutorial {
                    Phase2TutorialOverlay {
                        Haptics.impact(.light)
                        seenPhase2Tutorial = true
                        // Restart the countdown from "now" so the player
                        // gets a full clock when they actually start
                        // building — no time lost to reading.
                        startedAt = Date()
                        showingPhase2Tutorial = false
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showingPhase2Tutorial)
            .onAppear {
                if !seenPhase2Tutorial {
                    showingPhase2Tutorial = true
                }
            }
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            // Freeze the countdown while the first-time tutorial is up.
            guard timed, !submitted, !showingPhase2Tutorial else { return }
            let elapsed = Date().timeIntervalSince(startedAt)
            let left = max(0, effectiveMaxTime - elapsed)
            // Whole-second tick in the final 3 seconds.
            let prevWhole = Int(ceil(timeLeft))
            let nextWhole = Int(ceil(left))
            if prevWhole != nextWhole, nextWhole >= 1, nextWhole <= 3 {
                GameAudio.shared.play("timer_tick")
            }
            timeLeft = left
            if left <= 0 {
                handleSubmit(forcedTime: 0)
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            Button {
                GameAudio.shared.play("ui_back")
                Haptics.notify(.warning)
                onSkip()
            } label: {
                Text("ABORT")
                    .font(AppFont.mono(11, weight: .semibold))
                    .tracking(1.8)
                    .foregroundColor(Color.white.opacity(0.7))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.08)).overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("BUILD A WORD")
                .font(AppFont.mono(10, weight: .regular))
                .tracking(2.4)
                .foregroundColor(Color.white.opacity(0.55))
                .padding(.top, 6)

            Spacer()

            VStack(spacing: 6) {
                // Keep `timed` true after submit so the badge freezes on the
                // actual elapsed value instead of falling back to "—".
                // `timeLeft` stops updating in onReceive once submitted, so
                // what's shown is the time at the moment of submission.
                TimerBadge(timeLeft: timeLeft, startTime: effectiveMaxTime, timed: timed)
                extendTimeButton
            }
        }
        .padding(.horizontal, 20)
    }

    private var extendTimeButton: some View {
        let remaining = maxExtraTimeUses - extraTimeUses
        let disabled = remaining <= 0 || submitted
        return Button(action: extendTime) {
            VStack(spacing: 0) {
                Text("+\(Int(extraTimeBonus))s")
                    .font(AppFont.mono(11, weight: .bold))
                    .foregroundColor(disabled ? Color.white.opacity(0.3) : Theme.yellow)
                    .lineLimit(1)
                Text("−\(nextExtraTimeCost) ×\(remaining)")
                    .font(AppFont.mono(8, weight: .regular))
                    .tracking(0.6)
                    .foregroundColor(Color.white.opacity(disabled ? 0.25 : 0.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(width: 96)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.4))
                    .overlay(Capsule().stroke(disabled ? Color.white.opacity(0.1) : Theme.yellow.opacity(0.5), lineWidth: 1))
            )
            .shadow(color: disabled ? .clear : Theme.yellow.opacity(0.35), radius: 6)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func extendTime() {
        guard !submitted, extraTimeUses < maxExtraTimeUses else { return }
        extraTimeUses += 1
        bonusTime += extraTimeBonus
        Haptics.impact(.medium)
        // No timer surgery needed — the .onReceive handler now subtracts
        // elapsed from `effectiveMaxTime` (= startTime + bonusTime).
    }

    private var wordSlotView: some View {
        RoundedRectangle(cornerRadius: 18)
            .strokeBorder(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.04), Color.white.opacity(0.01)],
                        startPoint: .top, endPoint: .bottom
                    ))
            )
            .overlay(wordSlotContent)
            // Red pulse — animates a solid red border + glow when the timer
            // enters the danger zone. `dangerPulse` is toggled in a repeating
            // ease-in-out animation; opacity drives both the stroke and the
            // outer shadow so the whole area "throbs". Invisible when not in
            // danger so non-time-critical states stay clean.
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Theme.red, lineWidth: 2)
                    .opacity(danger ? (dangerPulse ? 0.85 : 0.25) : 0)
                    .shadow(color: Theme.red.opacity(danger ? (dangerPulse ? 0.7 : 0.2) : 0), radius: 14)
                    .allowsHitTesting(false)
            )
            .onChange(of: danger) { _, isDanger in
                if isDanger {
                    withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                        dangerPulse = true
                    }
                } else {
                    withAnimation(.linear(duration: 0.2)) {
                        dangerPulse = false
                    }
                }
            }
            .frame(minHeight: 96)
    }

    @ViewBuilder
    private var wordSlotContent: some View {
        if word.isEmpty {
            Text("TAP LETTERS BELOW · BUILD A WORD")
                .font(AppFont.mono(12, weight: .regular))
                .tracking(2.4)
                .foregroundColor(Color.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(12)
        } else {
            // One row of tiles, scaled to fit. Word can be up to 10 letters
            // (rack hold limit); we shrink the tiles from 44 → 22pt to keep
            // everything on a single line regardless of length.
            GeometryReader { geo in
                let spacing: CGFloat = 6
                let pad: CGFloat = 12      // matches outer .padding(12)
                let n = max(1, word.count)
                let available = max(0, geo.size.width - pad * 2)
                let raw = (available - CGFloat(n - 1) * spacing) / CGFloat(n)
                let tileSize = max(22, min(44, raw))
                HStack(spacing: spacing) {
                    ForEach(Array(word.enumerated()), id: \.element.id) { idx, slot in
                        Button {
                            guard !submitted else { return }
                            GameAudio.shared.play("tile_remove")
                            Haptics.select()
                            word.remove(at: idx)
                        } label: {
                            LetterTile(
                                letter: slot.tile.wild ? (slot.pickedLetter ?? "★") : slot.tile.letter,
                                value: slot.tile.wild ? (slot.pickedLetter.flatMap { LetterData.value(for: $0) }) : slot.tile.value,
                                tier: slot.tile.tier,
                                size: tileSize,
                                wild: slot.tile.wild && slot.pickedLetter == nil,
                                state: .word
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            }
            .padding(12)
        }
    }

    private var rackTitle: some View {
        Text("YOUR LETTERS · \(rack.count - usedRackIndices.count) / \(rack.count)")
            .font(AppFont.mono(10, weight: .regular))
            .tracking(2.6)
            .foregroundColor(Color.white.opacity(0.55))
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var rackView: some View {
        // `rackOrder` is a permutation of the rack's real indices. Iterating
        // over it lets SHUFFLE reorder the on-screen tiles without losing the
        // mapping back to the original rack (used by addTile / usedRackIndices).
        if layout == .grid {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(rackOrder, id: \.self) { idx in
                    rackTileButton(idx: idx, tile: rack[idx])
                }
            }
        } else {
            FlowLayout(spacing: 10, alignment: .center) {
                ForEach(rackOrder, id: \.self) { idx in
                    rackTileButton(idx: idx, tile: rack[idx])
                }
            }
        }
    }

    private func rackTileButton(idx: Int, tile: CapturedLetter) -> some View {
        let used = usedRackIndices.contains(idx)
        return Button {
            addTile(idx: idx)
        } label: {
            LetterTile(
                letter: tile.wild ? "★" : tile.letter,
                value: tile.value, tier: tile.tier,
                size: 56,
                wild: tile.wild,
                state: .rack,
                used: used
            )
        }
        .buttonStyle(.plain)
        .disabled(used || submitted)
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            ActionButton(label: "CLEAR") {
                // Re-use tile_remove pitched down 3 semis for a longer-tail "clear".
                GameAudio.shared.play("tile_remove", opts: .init(gain: 0.5, pitch: -3))
                Haptics.impact(.light)
                word.removeAll()
            }
            ActionButton(label: "SHUFFLE") {
                GameAudio.shared.play("shuffle")
                Haptics.select()
                // Reshuffle the rack display order (Scrabble-style) so the
                // player can spot new word possibilities. The selected word
                // stays as-is.
                rackOrder.shuffle()
            }
            // Label is the same whether the word is valid or not — the
            // player only finds out after submitting, so they can't probe
            // the dictionary in real time. 2-letter words are allowed
            // (AT, BE, IT, …); 1 or fewer letters disables the button.
            ActionButton(
                label: "SUBMIT",
                variant: .primary,
                disabled: word.count < 2
            ) {
                handleSubmit()
            }
        }
    }

    private func addTile(idx: Int) {
        guard !submitted, !usedRackIndices.contains(idx) else { return }
        let tile = rack[idx]
        if tile.wild {
            GameAudio.shared.play("wild_pick")
            Haptics.impact(.medium)
            pickingWildIdx = idx
        } else {
            // Pitch tile_tap by position so the rack reads as an ascending melody.
            let semis = Float((word.count % 7) * 2)
            GameAudio.shared.play("tile_tap", opts: .init(pitch: semis))
            Haptics.select()
            word.append(WordSlot(rackIndex: idx, tile: tile))
        }
    }

    private func pickWildLetter(_ letter: Character) {
        guard let idx = pickingWildIdx else { return }
        let tile = rack[idx]
        // "Found it" — same sample as tile_tap, but +8 semitones.
        GameAudio.shared.play("tile_tap", opts: .init(gain: 0.55, pitch: 8))
        Haptics.select()
        word.append(WordSlot(rackIndex: idx, tile: tile, pickedLetter: letter))
        pickingWildIdx = nil
    }

    private func handleSubmit(forcedTime: Double? = nil) {
        guard !submitted else { return }
        let finalTime = forcedTime ?? timeLeft
        let wordTiles = word.map { slot -> CapturedLetter in
            var t = slot.tile
            t.pickedLetter = slot.pickedLetter
            return t
        }
        var sc = ScoreCalculator.score(word: wordTiles, racked: rack, timeLeft: finalTime, maxTime: effectiveMaxTime, modifiers: modifiers, loadout: loadout)
        let penalty = extraTimePenaltyTotals[min(extraTimeUses, extraTimePenaltyTotals.count - 1)]
        sc.timePenalty = penalty
        if !sc.valid {
            sc.final = 0
        } else {
            sc.final = max(0, sc.final - penalty)
        }
        result = sc
        submitted = true

        // SFX: submit cue immediately, then verdict + ticks.
        GameAudio.shared.play("submit_word")
        Haptics.impact(.medium)
        if sc.valid {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                GameAudio.shared.play("valid_word")
                Haptics.notify(.success)
            }
            // Ascending tick reveal at 400/600/800/1000ms — matches the spec.
            for (i, t) in [0.40, 0.60, 0.80, 1.00].enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                    GameAudio.shared.play("score_tick", opts: .init(pitch: Float(i) * 2))
                    Haptics.impact(.light, intensity: 0.6)
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                GameAudio.shared.play("invalid_word")
                Haptics.notify(.error)
            }
        }

        // Both valid and invalid words now require the player to tap the
        // breakdown card's button to advance. The button label switches to
        // "CONTINUE →" on invalid words (leads to game over) and
        // "NEXT RAID →" on valid ones.
    }

    private func unusedRackLetters() -> [CapturedLetter] {
        rack.enumerated()
            .filter { !usedRackIndices.contains($0.offset) }
            .map(\.element)
    }
}

private struct ActionButton: View {
    let label: String
    enum Variant { case primary, ghost }
    var variant: Variant = .ghost
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(AppFont.mono(12, weight: .semibold))
                .tracking(2.2)
                .foregroundColor(.white)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(variant == .primary
                              ? AnyShapeStyle(LinearGradient(colors: [Theme.cyan.opacity(0.35), Theme.violet.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                              : AnyShapeStyle(Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(variant == .primary ? Theme.cyan.opacity(0.5) : Color.white.opacity(0.12), lineWidth: variant == .primary ? 1.5 : 1)
                        )
                )
                .shadow(color: variant == .primary ? Theme.cyan.opacity(0.4) : .clear, radius: 12)
                .opacity(disabled ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

private struct TimerBadge: View {
    let timeLeft: Double
    let startTime: Double
    let timed: Bool

    var body: some View {
        let pct = max(0, min(1, timeLeft / max(1, startTime)))
        let danger = pct < 0.25
        return VStack(spacing: 4) {
            Text(timed ? String(format: "%.1f", timeLeft) : "—")
                .font(AppFont.mono(14, weight: .bold))
                .foregroundColor(danger ? Theme.red : .white)
            Capsule()
                .fill(Color.white.opacity(0.1))
                .frame(height: 3)
                .overlay(
                    GeometryReader { g in
                        Capsule()
                            .fill(danger ? Theme.red : Theme.cyan)
                            .frame(width: g.size.width * pct)
                            .shadow(color: danger ? Theme.red : Theme.cyan, radius: 3)
                    }
                )
                .padding(.horizontal, 8)
        }
        .padding(.vertical, 6)
        .frame(width: 72)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.4))
                .overlay(Capsule().stroke(danger ? Theme.red.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1))
        )
    }
}

struct WildPickerOverlay: View {
    let onPick: (Character) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color(hex: 0x06031A).opacity(0.78).ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 12) {
                Text("★ WILDCARD · CHOOSE A LETTER")
                    .font(AppFont.mono(11, weight: .regular))
                    .tracking(2.4)
                    .foregroundColor(Theme.yellow)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                    ForEach(Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ"), id: \.self) { L in
                        Button {
                            onPick(L)
                        } label: {
                            let info = LetterData.table[L]
                            LetterTile(letter: L, value: info?.value, tier: info?.tier ?? 1, size: 42)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient(colors: [Color(hex: 0x1A0B2E), Color(hex: 0x0C0729)], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.yellow.opacity(0.4), lineWidth: 1.5))
                    .shadow(color: Theme.yellow.opacity(0.4), radius: 40)
            )
            .padding(.horizontal, 22)
        }
    }
}

struct ScoreBreakdownCard: View {
    let sc: ScoreBreakdown
    var raidScoreBonus: Int = 0
    var raidCoinsEarned: Int = 0
    let onContinue: () -> Void

    @AppStorage(Hangar.coinKey) private var coinBalance: Int = Hangar.startingCoins

    /// Raid bonus only counts when the word is valid — invalid/skip forfeits it.
    private var effectiveRaidBonus: Int { sc.valid ? max(0, raidScoreBonus) : 0 }
    private var displayedFinal: Int { sc.final + effectiveRaidBonus }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(sc.valid ? "✓ WORD ACCEPTED" : "✗ NOT IN DICTIONARY")
                .font(AppFont.mono(10, weight: .regular))
                .tracking(2.8)
                .foregroundColor(sc.valid ? Theme.green : Theme.red)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)

            Text(sc.word.uppercased())
                .font(AppFont.display(40, weight: .bold))
                .kerning(-1.6)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .shadow(color: sc.valid ? Theme.green.opacity(0.6) : .clear, radius: 18)
                .padding(.bottom, 14)

            ScrollView(showsIndicators: false) {
                ScoreRow(label: "BASE POINTS", value: "\(sc.base)", accent: .white)
                ScoreRow(label: "LENGTH × (\(sc.used))", value: String(format: "%.2f×", sc.lengthMul), accent: Theme.cyanSoft)
                if sc.rareBonus > 0 {
                    ScoreRow(label: "RARE LETTER", value: "+\(sc.rareBonus)", accent: Theme.pinkSoft)
                }
                if sc.effPct > 0 {
                    ScoreRow(label: "EFFICIENCY (\(sc.used)/\(sc.total))", value: "+\(Int((sc.effPct*100).rounded()))%", accent: Theme.green)
                }
                ScoreRow(label: "SPEED", value: String(format: "%.2f×", sc.speedMul), accent: Color(hex: 0xFBBF24))
                if sc.timePenalty > 0 {
                    ScoreRow(label: "TIME PENALTY", value: "−\(sc.timePenalty)", accent: Theme.red)
                }
                if effectiveRaidBonus > 0 {
                    ScoreRow(label: "RAID CAPTURE", value: "+\(effectiveRaidBonus)", accent: Theme.cyan)
                }
                Color.clear.frame(height: 8)
                ScoreRow(label: "FINAL", value: "\(displayedFinal)", accent: .white, strong: true)
                if raidCoinsEarned > 0 {
                    ScoreRow(
                        label: "COINS · BAL \(coinBalance)",
                        value: "+\(raidCoinsEarned)",
                        accent: Theme.yellow
                    )
                }
            }

            Button {
                Haptics.impact(.light)
                onContinue()
            } label: {
                Text(sc.valid ? "NEXT RAID →" : "CONTINUE →")
                    .font(AppFont.mono(13, weight: .semibold))
                    .tracking(2.6)
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient(colors: [Theme.cyan.opacity(0.35), Theme.violet.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cyan.opacity(0.5), lineWidth: 1.5))
                    )
                    .shadow(color: Theme.cyan.opacity(0.4), radius: 12)
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [Color(hex: 0x1A0B2E).opacity(0.85), Color(hex: 0x0C0729).opacity(0.85)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.violet.opacity(0.35), lineWidth: 1.5))
                .shadow(color: Theme.violet.opacity(0.4), radius: 50)
        )
    }
}

private struct ScoreRow: View {
    let label: String
    let value: String
    var accent: Color = .white
    var strong: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(AppFont.mono(strong ? 12 : 11, weight: .regular))
                .tracking(1.7)
                .foregroundColor(Color.white.opacity(0.55))
            Spacer()
            Text(value)
                .font(strong ? AppFont.display(24, weight: .bold) : AppFont.mono(13, weight: .semibold))
                .foregroundColor(accent)
        }
        .padding(.vertical, 8)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .frame(maxWidth: .infinity, alignment: .bottom)
                .opacity(0.5),
            alignment: .bottom
        )
    }
}

// MARK: - Minimal FlowLayout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var alignment: HorizontalAlignment = .center

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        return arrange(subviews: subviews, in: maxWidth).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrange(subviews: subviews, in: bounds.width)
        for (offset, sub) in subviews.enumerated() {
            let p = layout.positions[offset]
            sub.place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }

    private func arrange(subviews: Subviews, in maxWidth: CGFloat) -> (positions: [CGPoint], size: CGSize) {
        // First pass: group subviews into rows and remember per-subview size.
        struct Item { let index: Int; let size: CGSize }
        var rows: [[Item]] = [[]]
        var x: CGFloat = 0
        var widestRow: CGFloat = 0

        for (i, sub) in subviews.enumerated() {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(Item(index: i, size: s))
            x += s.width + spacing
            widestRow = max(widestRow, x - spacing)
        }

        // Second pass: assign positions, honoring horizontal alignment per row.
        var positions = Array(repeating: CGPoint.zero, count: subviews.count)
        var y: CGFloat = 0
        for row in rows {
            let rowWidth = row.reduce(0) { $0 + $1.size.width } +
                CGFloat(max(0, row.count - 1)) * spacing
            let rowHeight = row.map { $0.size.height }.max() ?? 0

            var startX: CGFloat
            switch alignment {
            case .center:   startX = max(0, (maxWidth - rowWidth) / 2)
            case .trailing: startX = max(0, maxWidth - rowWidth)
            default:        startX = 0
            }

            var cursor = startX
            for item in row {
                positions[item.index] = CGPoint(x: cursor, y: y)
                cursor += item.size.width + spacing
            }
            y += rowHeight + spacing
        }

        let totalHeight = max(0, y - spacing)
        return (positions, CGSize(width: widestRow, height: totalHeight))
    }
}

// MARK: - Phase 2 first-time tutorial

/// Word-phase tutorial overlay shown ONCE per install when the player
/// first reaches Phase 2. Explains the tap-to-add / tap-to-remove letter
/// flow, the dictionary requirement, and the +30s extension's cost.
/// The parent freezes the countdown timer while this is visible, then
/// resets `startedAt` on dismiss so the player gets a full clock.
private struct Phase2TutorialOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.78)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { /* swallow */ }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HOW TO PLAY · PHASE 2")
                        .font(AppFont.mono(10, weight: .bold))
                        .tracking(2.6)
                        .foregroundColor(Theme.cyanSoft)
                    Text("Build a word")
                        .font(AppFont.display(26, weight: .bold))
                        .kerning(-0.6)
                        .foregroundColor(.white)
                }

                row(icon: "hand.tap.fill",
                    tint: Theme.cyan,
                    title: "TAP A LETTER",
                    body: "Tap a letter in your rack to add it to the word slot at the top.")
                row(icon: "delete.left.fill",
                    tint: Theme.pinkSoft,
                    title: "TAP TO REMOVE",
                    body: "Tap any letter inside the word to take it back out and place it differently.")
                row(icon: "text.book.closed.fill",
                    tint: Theme.violet,
                    title: "VALID WORDS",
                    body: "Words must be in the dictionary and at least 2 letters. SHUFFLE rearranges your rack.")
                row(icon: "clock.arrow.circlepath",
                    tint: Theme.yellow,
                    title: "+30s · USE CAREFULLY",
                    body: "Extending the timer costs points (50 first use, 150 second). Only spend when you're close to a great word.")

                Button(action: onDismiss) {
                    Text("LET'S GO")
                        .font(AppFont.mono(13, weight: .semibold))
                        .tracking(2.6)
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(LinearGradient(colors: [Theme.cyan.opacity(0.4), Theme.violet.opacity(0.3)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cyan.opacity(0.5), lineWidth: 1.5))
                        )
                        .shadow(color: Theme.cyan.opacity(0.4), radius: 12)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(22)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient(colors: [Color(hex: 0x1A0B2E).opacity(0.95), Color(hex: 0x0C0729).opacity(0.95)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.violet.opacity(0.4), lineWidth: 1.5))
                    .shadow(color: Theme.violet.opacity(0.5), radius: 40)
            )
            .padding(.horizontal, 24)
        }
    }

    private func row(icon: String, tint: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tint.opacity(0.18))
                    .frame(width: 36, height: 36)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(tint.opacity(0.45), lineWidth: 1))
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(tint)
                    .shadow(color: tint.opacity(0.55), radius: 6)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.mono(11, weight: .bold))
                    .tracking(1.8)
                    .foregroundColor(.white)
                Text(body)
                    .font(AppFont.mono(11.5, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
