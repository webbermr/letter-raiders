import SwiftUI

enum AppRoute: Equatable {
    case title
    case onboarding(step: Int)
    case play
    case word(rack: [CapturedLetter])
    case gameover(score: Int, bestWord: String, missionFailed: Bool, failureReason: String, raidsCleared: Int, lettersUsed: Int, bestCombo: Int, prevHigh: Int, isNewHigh: Bool, dailySuccess: Bool, dailyPuzzleName: String?, dailyReward: Int, xpGainedThisRun: Int, ranksGainedThisRun: Int, newlyUnlockedBadgeIDs: [String])
    case daily
    case badges
    case skins
    case settings
    case help
}

struct RootView: View {
    @State private var route: AppRoute
    @State private var background: BackgroundVariant = .cosmos
    @StateObject private var run = RunState()
    @AppStorage("highScore") private var highScore: Int = 0
    /// Global CRT scanline overlay toggle. Settings binds to the same key, so
    /// toggling there immediately appears/disappears the overlay app-wide.
    @AppStorage("scanlines") private var scanlines: Bool = true
    /// First-launch gate. Set true by either path out of the onboarding
    /// (NEXT through step 3 OR the SKIP link).
    @AppStorage("onboardingDone") private var onboardingDone: Bool = false
    /// When non-nil the player is mid-daily-puzzle. The modifiers flow
    /// through to PlayScreen + WordScreen, and the run is single-raid: a
    /// valid word ends the daily as success, anything else as failure.
    @State private var activeDailyPuzzle: DailyPuzzle? = nil
    /// True when the player tapped Launch Mission with `Hangar.lifeStock`
    /// at 0. Drives the LifePurchasePrompt overlay; resolved when the
    /// player buys lives or declines.
    @State private var showLifePrompt: Bool = false
    @State private var showingCoinStore: Bool = false

    init() {
        // Start on onboarding for fresh installs; jump straight to title for
        // returning players. UserDefaults read at init so we don't render
        // the title for one frame before swapping.
        let done = UserDefaults.standard.bool(forKey: "onboardingDone")
        _route = State(initialValue: done ? .title : .onboarding(step: 1))
    }

    var body: some View {
        ZStack {
            switch route {
            case .title:
                TitleScreen(
                    onPlay: { tryLaunchMission() },
                    onContinue: { route = .play },
                    onDaily:    { route = .daily },
                    onShips:    { route = .skins },
                    onRanks:    { route = .badges },
                    onSettings: { route = .settings },
                    onHelp:     { route = .help },
                    hasActiveRun: run.isActive,
                    currentRaid: run.raid,
                    currentScore: run.cumulativeScore,
                    currentLives: run.lives,
                    livesMax: RunState.startingLives
                )
                .transition(.opacity)

            case .onboarding(let step):
                OnboardingScreen(
                    step: step,
                    onNext: {
                        if step >= OnboardingScreen.totalSteps {
                            // Final NEXT — mark onboarding done and drop the
                            // player on the home screen so they can look
                            // around (hangar, daily, settings) before
                            // jumping into a run.
                            onboardingDone = true
                            route = .title
                        } else {
                            route = .onboarding(step: step + 1)
                        }
                    },
                    onSkip: {
                        // SKIP also satisfies the onboarding gate; we don't
                        // want to nag them again on relaunch.
                        onboardingDone = true
                        route = .title
                    }
                )
                .transition(.opacity)

            case .play:
                // Daily puzzles override raid time/hold/lives via modifiers.
                // Endless runs use the normal difficulty ramp (raidSeconds
                // shrinks each raid, bottoming out at 18s).
                let modifiers = activeDailyPuzzle?.modifiers ?? .none
                let loadout = Hangar.currentLoadout()
                // Eclipse: bonusRaidSeconds adds to whichever base time
                // applies (daily or difficulty-ramped endless). Skyhawk:
                // bonusHoldLimit stacks on top of the base hold limit.
                let baseRaidSeconds = activeDailyPuzzle != nil
                    ? modifiers.raidSeconds
                    : max(18.0, 30.0 - Double(run.raid - 1) * 2.0)
                let raidSeconds = baseRaidSeconds + loadout.bonusRaidSeconds
                let baseHoldLimit = activeDailyPuzzle != nil ? modifiers.holdLimit : 10
                let holdLimit = baseHoldLimit + loadout.bonusHoldLimit
                let lives = activeDailyPuzzle != nil ? modifiers.lives : run.lives
                let rack = activeDailyPuzzle != nil ? [] : run.carriedLetters
                PlayScreen(
                    background: background,
                    holdLimit: holdLimit,
                    raidSeconds: raidSeconds,
                    raidNumber: run.raid,
                    initialLives: lives,
                    initialRack: rack,
                    cumulativeScoreBase: run.cumulativeScore,
                    loadout: loadout,
                    modifiers: modifiers,
                    // Charges come straight from the persistent Hangar pool.
                    // Engine decrements Hangar on every use so a pause-quit
                    // can never lose what the player has earned.
                    initialZap: Hangar.zapStock,
                    initialWild: Hangar.wildStock,
                    // Continue-on-death only for endless runs; daily puzzles
                    // are one-attempt-per-day fixed challenges.
                    allowContinue: activeDailyPuzzle == nil,
                    onPause: { endRun(reason: "Mission aborted") },
                    onComplete: handlePlayResult
                )
                .id(run.raid)        // fresh engine per raid
                .transition(.opacity)

            case .word(let rack):
                let wordLoadout = Hangar.currentLoadout()
                WordScreen(
                    rack: rack,
                    // Eclipse: bonusWordSeconds extends the word-phase timer.
                    startTime: 60 + wordLoadout.bonusWordSeconds,
                    raidScoreBonus: run.pendingRaidScore,
                    raidCoinsEarned: run.pendingRaidCoinsEarned,
                    modifiers: activeDailyPuzzle?.modifiers ?? .none,
                    loadout: wordLoadout,
                    onSubmit: handleWordResult,
                    onSkip: {
                        // Skip = aborting Phase 2. End the run as Mission Failed.
                        endRun(reason: "Mission aborted")
                    }
                )
                .id(run.raid)
                .transition(.opacity)

            case .gameover(let score, let bestWord, let missionFailed, let failureReason, let raidsCleared, let lettersUsed, let bestCombo, let prevHigh, let isNewHigh, let dailySuccess, let dailyPuzzleName, let dailyReward, let xpGainedThisRun, let ranksGainedThisRun, let newlyUnlockedBadgeIDs):
                GameOverScreen(
                    score: score,
                    raid: raidsCleared,
                    bestWord: bestWord.isEmpty ? "—" : bestWord,
                    lettersUsed: lettersUsed,
                    bestCombo: bestCombo,
                    isNewHigh: isNewHigh,
                    missionFailed: missionFailed,
                    failureReason: failureReason,
                    prevHigh: prevHigh,
                    dailySuccess: dailySuccess,
                    dailyPuzzleName: dailyPuzzleName,
                    dailyReward: dailyReward,
                    xpGainedThisRun: xpGainedThisRun,
                    ranksGainedThisRun: ranksGainedThisRun,
                    newlyUnlockedBadgeIDs: newlyUnlockedBadgeIDs,
                    onReplay: { tryLaunchMission() },
                    onHome: { route = .title }
                )
                .transition(.opacity)

            case .daily:
                DailyScreen(
                    onBack: { route = .title },
                    onPlay: startDailyPuzzle
                )
                .transition(.opacity)

            case .badges:
                BadgesScreen(onBack: { route = .title })
                    .transition(.opacity)

            case .skins:
                SkinsScreen(onBack: { route = .title })
                    .transition(.opacity)

            case .settings:
                SettingsScreen(onBack: { route = .title })
                    .transition(.opacity)

            case .help:
                HelpScreen(onBack: { route = .title })
                    .transition(.opacity)
            }

            // At-launch life gate. Sits above the route but below the
            // scanline overlay so it reads in the same neon look as the
            // game. Only reachable from the title screen — `tryLaunchMission`
            // is what raises it.
            if showLifePrompt {
                LifePurchasePrompt(
                    mode: .preLaunch,
                    onBuy: { count in handleLifePurchase(count: count) },
                    onDecline: { showLifePrompt = false },
                    onGetCoins: { showingCoinStore = true }
                )
                .transition(.opacity)
                .zIndex(50)
            }

            // Global CRT scanline overlay — rendered last so it sits above
            // every route AND any in-screen overlays (pause menu, score card).
            // `.allowsHitTesting(false)` (inside ScanlineOverlay) keeps taps
            // flowing through to the UI beneath.
            if scanlines {
                ScanlineOverlay()
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: route)
        .animation(.easeInOut(duration: 0.2), value: showLifePrompt)
        .sheet(isPresented: $showingCoinStore) {
            CoinStoreSheet { showingCoinStore = false }
        }
    }

    /// Title-screen LAUNCH MISSION handler. Persistent lives means a player
    /// who ended their last run at 0 has to refuel before launching — show
    /// the purchase prompt instead of running with zero lives. Players who
    /// can't afford any lives can still decline; their out is today's daily
    /// puzzle (which uses puzzle-modifier lives, not Hangar.lifeStock).
    private func tryLaunchMission() {
        if Hangar.lifeStock <= 0 {
            showLifePrompt = true
            return
        }
        run.resetForNewRun()
        route = .play
    }

    /// At-launch purchase confirmed. Deducts coins, sets the lifeStock to
    /// the bought count (player was at 0), dismisses the prompt, and
    /// launches the run.
    private func handleLifePurchase(count: Int) {
        let cost = Hangar.lifePrice * count
        guard Hangar.coins >= cost, count > 0 else { return }
        Hangar.coins -= cost
        Hangar.lifeStock = min(Hangar.maxLives, count)
        showLifePrompt = false
        run.resetForNewRun()
        route = .play
    }

    // MARK: - Run flow

    private func handlePlayResult(_ result: PlayResult) {
        run.recordRaidEnd(
            livesRemaining: result.livesRemaining,
            lettersCaptured: result.lettersCapturedThisRaid,
            bestComboThisRaid: result.bestComboThisRaid
        )
        // No charge-state writeback here — the engine wrote through to
        // Hangar.zapStock / Hangar.wildStock on every power-up use, so
        // the persistent pool already reflects the truth.
        //
        // Lives DO need writeback at raid end: the engine ran a local
        // counter for the raid. Persist for endless runs (daily puzzles
        // override lives via modifiers and must NOT contaminate the
        // persistent stock — losing all lives on Glass Cannon shouldn't
        // empty the player's hangar life pool).
        if activeDailyPuzzle == nil {
            Hangar.lifeStock = max(0, result.livesRemaining)
        }

        // Phase-1 failure paths bypass the Word screen.
        if result.reason == "no_lives" {
            endRun(reason: "Ship destroyed")
            return
        }
        if result.rack.count <= 1 {
            endRun(reason: "Not enough letters captured")
            return
        }

        // Hold the shoot-up score across the Word phase. It folds into
        // cumulativeScore only if the player submits a valid word.
        run.pendingRaidScore = result.score
        // Coins earned this raid are already banked in Hangar — we just mirror
        // the count so the breakdown card can show the per-raid delta.
        run.pendingRaidCoinsEarned = result.coinsEarnedThisRaid
        route = .word(rack: result.rack)
    }

    private func handleWordResult(_ result: WordResult) {
        // Invalid words fail the mission — no carryover, no next raid.
        guard result.score.valid else {
            endRun(reason: "Word not in dictionary")
            return
        }

        // Achievement hooks for word-quality milestones (longest word, rare
        // letter, pangram). Counted regardless of daily vs endless mode.
        let upperWord = result.score.word.uppercased()
        let vowelSet: Set<Character> = ["A","E","I","O","U"]
        let distinctVowels = Set(upperWord).intersection(vowelSet).count
        AchievementStore.recordValidWord(
            length: result.score.used,
            hasRareLetter: result.score.hasRare,
            distinctVowels: distinctVowels
        )

        // Snapshot the raid we just cleared BEFORE advanceAfterWord bumps
        // `raid` — used to apply the "+1 ZAP every 3 cleared raids" bonus.
        let justClearedRaid = run.raid
        let wordLength = result.score.used

        // Bank the word's score + pending raid score either way.
        run.advanceAfterWord(score: result.score, unusedLetters: result.unusedLetters)

        // Daily puzzles are single-raid: a valid word ends the daily as a
        // success (records attempt, awards coin reward, bumps streak). Skip
        // the inter-raid power-up grants — they wouldn't fire anyway.
        if activeDailyPuzzle != nil {
            endRun(reason: "Mission complete", dailySuccess: true)
            return
        }

        // Per-raid power-up progression:
        //   • Base grant: +1 ZAP + 1 WILD on every cleared raid.
        //   • Bonus ZAP: every 3rd cleared raid (raids 3, 6, 9, …).
        //   • Bonus WILD: word of 7+ letters that cleared the raid.
        // All written straight to the persistent Hangar pool, capped by
        // Hangar.maxChargeStock.
        let zapBonus = (justClearedRaid % 3 == 0) ? 1 : 0
        let wildBonus = (wordLength >= 7) ? 1 : 0
        Hangar.grantZap(1 + zapBonus)
        Hangar.grantWild(1 + wildBonus)

        // Life rewards — hard-capped at 3 by RunState.grantLife.
        //   • Every 5 cleared raids in a run (raids 5, 10, 15, …)
        //   • Word of 9+ letters (rarer than the WILD bonus, bigger reward)
        // Each call is a no-op when already at the cap.
        if justClearedRaid % 5 == 0 { run.grantLife() }
        if wordLength >= 9 { run.grantLife() }

        // If lives are gone (shouldn't happen here — handlePlayResult already
        // catches no_lives — but defensive), end the run.
        if run.lives <= 0 {
            endRun(reason: "Ship destroyed")
            return
        }
        route = .play
    }

    /// Begin today's daily puzzle. Single-attempt-per-day gate is enforced by
    /// the DailyScreen's CTA (button disabled when already attempted), so this
    /// just sets up the run.
    private func startDailyPuzzle() {
        let puzzle = DailyPuzzleCatalog.puzzle()
        activeDailyPuzzle = puzzle
        run.resetForNewRun()
        // Override the default 3 lives so PlayScreen sees the puzzle's value.
        run.lives = puzzle.modifiers.lives
        route = .play
    }

    private func endRun(reason: String, dailySuccess: Bool = false) {
        run.isActive = false
        // Snapshot the previous high BEFORE updating, so the game-over screen
        // can show the delta and the "NEW PERSONAL BEST" treatment.
        let prevHigh = highScore
        let isNewHigh = run.cumulativeScore > prevHigh
        if isNewHigh { highScore = run.cumulativeScore }
        // Celebration XP: +200 for a brand-new personal best. Fires before
        // the daily/non-daily branching so it stacks with either reward.
        if isNewHigh { PlayerProfile.awardXP(200) }

        // Capture the daily puzzle info BEFORE we clear `activeDailyPuzzle`
        // so the game-over screen can show "MISSION COMPLETE · <puzzle name>"
        // on success with the reward we just awarded.
        var dailyPuzzleName: String? = nil
        var dailyReward: Int = 0

        // Daily-puzzle bookkeeping. Recording an attempt is one-shot per day
        // (DailyState handles dedup), so it's safe to call from any path
        // that ends a daily run (success, fail, pause, skip).
        if let puzzle = activeDailyPuzzle {
            dailyPuzzleName = puzzle.name
            if dailySuccess {
                // Daily coin reward scales with rank (+5% per 5 ranks).
                let mul = RankSystem.dailyRewardMultiplier(forRank: PlayerProfile.rank)
                let scaled = Int((Double(puzzle.coinReward) * mul).rounded())
                Hangar.awardCoins(scaled)
                dailyReward = scaled
                // Daily completion XP bonus — independent of rank multiplier.
                PlayerProfile.awardXP(100)
                // Daily clear refills 1 life directly into the persistent
                // pool (DailyState's once-per-day gate guarantees this fires
                // at most once per calendar day). No-op when already at cap.
                Hangar.grantLife()
            }
            DailyState.recordAttempt(
                score: dailySuccess ? run.cumulativeScore : 0,
                submittedValidWord: dailySuccess
            )
            activeDailyPuzzle = nil
        } else {
            // End-of-run coin payout: 5% of the run's final banked score.
            // Daily puzzles don't get the score share — they get the puzzle's
            // fixed coinReward instead, awarded above.
            Hangar.awardCoins(Int((Double(run.cumulativeScore) * 0.05).rounded()))
        }
        let xpGainedThisRun = max(0, PlayerProfile.xp - run.xpAtRunStart)
        // Rank delta: highest rank reached this run minus rank at run start.
        // Drives the rank-up celebration sheet on the game-over screen.
        let startRank = RankSystem.rank(forXP: run.xpAtRunStart)
        let endRank = PlayerProfile.rank
        let ranksGainedThisRun = max(0, endRank - startRank)

        // Achievement bookkeeping. Read DailyState.streak AFTER recordAttempt
        // above has bumped it (when applicable) so the best-streak stat sees
        // today's increment.
        let raidsCleared = max(0, run.raid - 1)
        AchievementStore.recordRunEnd(
            bestCombo: run.bestCombo,
            raidsCleared: raidsCleared,
            dailySuccess: dailySuccess,
            currentStreak: DailyState.streak
        )

        // Diff the badge state from run start. Anything now-unlocked that
        // wasn't unlocked when the run began gets a celebration sheet on
        // game over.
        let newlyUnlockedBadgeIDs: [String] = AchievementCatalog.all
            .filter { $0.isUnlocked && !run.unlockedAtRunStart.contains($0.id.rawValue) }
            .map { $0.id.rawValue }

        route = .gameover(
            score: run.cumulativeScore,
            bestWord: run.bestWord,
            // Mission "failed" hero treatment only when the run actually
            // failed. Daily success surfaces as MISSION COMPLETE instead.
            missionFailed: !dailySuccess,
            failureReason: reason,
            raidsCleared: max(0, run.raid - 1),
            lettersUsed: run.lettersCapturedTotal,
            bestCombo: run.bestCombo,
            prevHigh: prevHigh,
            isNewHigh: isNewHigh,
            dailySuccess: dailySuccess,
            dailyPuzzleName: dailyPuzzleName,
            dailyReward: dailyReward,
            xpGainedThisRun: xpGainedThisRun,
            ranksGainedThisRun: ranksGainedThisRun,
            newlyUnlockedBadgeIDs: newlyUnlockedBadgeIDs
        )
    }
}

#Preview {
    RootView().preferredColorScheme(.dark)
}
