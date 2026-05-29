import Foundation
import SwiftUI

/// State that persists across raids within a single endless run.
/// Reset whenever the player starts a brand-new run from the Title screen.
@MainActor
final class RunState: ObservableObject {
    @Published var raid: Int = 1
    @Published var lives: Int = 3
    @Published var cumulativeScore: Int = 0
    /// Unused letters carried over from the previous raid's Word phase.
    /// All unused tiles transfer — no cap. The next raid's hold limit still
    /// bounds the total rack size, so a fully-stocked carryover just means
    /// fewer captures are possible in Phase 1.
    @Published var carriedLetters: [CapturedLetter] = []
    @Published var bestWord: String = ""
    @Published var bestWordScore: Int = 0
    /// Total letters captured this run (across all raids).
    @Published var lettersCapturedTotal: Int = 0
    /// Highest combo achieved this run.
    @Published var bestCombo: Int = 0
    /// Shoot-up score from the current raid's Phase 1, held until the Word
    /// phase resolves. Folded into `cumulativeScore` only when the player
    /// submits a valid word; forfeited on invalid/skip/run-end.
    @Published var pendingRaidScore: Int = 0
    /// Coins earned during the current raid's Phase 1. Already banked in
    /// `Hangar.coins`; this copy exists so the Word-phase breakdown card
    /// can show how much the player just earned.
    @Published var pendingRaidCoinsEarned: Int = 0
    /// True while a run is in progress (between resetForNewRun and the run
    /// ending via game over). Drives whether the title screen offers Continue.
    @Published var isActive: Bool = false
    /// Snapshot of `PlayerProfile.xp` taken at run start so the game-over
    /// screen can show "+N XP earned" — computed as `current.xp - this`.
    @Published var xpAtRunStart: Int = 0
    /// Achievement IDs already unlocked at run start. Anything that becomes
    /// unlocked during the run is the diff — drives the badge-earned
    /// celebration sheet(s) on game over.
    @Published var unlockedAtRunStart: Set<String> = []

    static let startingLives = 3

    func resetForNewRun() {
        raid = 1
        // Lives are persistent (Hangar.lifeStock, capped at maxLives).
        // RootView gates Launch Mission on lifeStock >= 1, so we trust the
        // current value here — no auto-refill. Daily puzzles still override
        // via PuzzleModifiers.lives in the .play case.
        lives = Hangar.lifeStock
        cumulativeScore = 0
        carriedLetters = []
        bestWord = ""
        bestWordScore = 0
        lettersCapturedTotal = 0
        bestCombo = 0
        pendingRaidScore = 0
        pendingRaidCoinsEarned = 0
        isActive = true
        xpAtRunStart = PlayerProfile.xp
        // Snapshot already-unlocked badges so the game-over flow can
        // celebrate only the ones earned during THIS run.
        unlockedAtRunStart = Set(
            AchievementCatalog.all.filter { $0.isUnlocked }.map { $0.id.rawValue }
        )
        // Power-up charges aren't reset here — they live in Hangar.zapStock
        // / Hangar.wildStock and persist across runs by design. Players keep
        // every charge they've earned or purchased.
    }

    /// Apply the result of a finished raid (the shooter phase).
    func recordRaidEnd(livesRemaining: Int, lettersCaptured: Int, bestComboThisRaid: Int) {
        lives = livesRemaining
        lettersCapturedTotal += lettersCaptured
        bestCombo = max(bestCombo, bestComboThisRaid)
    }

    /// Bump current run lives by `amount` (clamped to maxLives) and mirror
    /// the change to the persistent Hangar.lifeStock so the next raid's
    /// engine init sees it.
    @discardableResult
    func grantLife(_ amount: Int = 1) -> Bool {
        guard amount > 0 else { return false }
        let before = lives
        lives = min(Hangar.maxLives, lives + amount)
        if lives > before {
            Hangar.lifeStock = lives
            return true
        }
        return false
    }

    /// Apply the result of a finished word phase and advance to the next raid.
    /// Caller guarantees `score.valid == true`; on invalid/skip the run ends
    /// instead and `pendingRaidScore` is forfeited (never folded in).
    func advanceAfterWord(score: ScoreBreakdown, unusedLetters: [CapturedLetter]) {
        cumulativeScore += max(0, score.final) + max(0, pendingRaidScore)
        pendingRaidScore = 0
        pendingRaidCoinsEarned = 0
        if score.valid, score.final > bestWordScore {
            bestWordScore = score.final
            bestWord = score.word
        }
        carriedLetters = unusedLetters
        raid += 1
        // Raid-clear coin bonus — flat per cleared raid, on top of any
        // in-raid drip awarded by the engine.
        Hangar.awardCoins(50)
        // XP: +25 for clearing the raid plus length × 5 for word quality.
        // A 5-letter word = +50, a 7-letter = +60, an 8-letter = +65 (all
        // on top of the per-capture XP earned in Phase 1).
        let wordLength = max(0, score.used)
        // Rank-up from word XP grants +1 life (capped at maxLives). Fires
        // between raids, after the engine is gone, so there's no race
        // with the engine's local lives counter.
        if PlayerProfile.awardXP(25 + wordLength * 5) != nil {
            grantLife()
        }
    }
}
