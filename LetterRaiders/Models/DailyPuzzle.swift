import Foundation

/// One day's catalog entry. The same puzzle fires for every device on a
/// given date (see `DailyPuzzleCatalog.puzzle(forDate:)`).
struct DailyPuzzle: Identifiable, Equatable {
    let id: String         // stable key, e.g. "vowel_famine"
    let name: String       // big headline ("Vowel Famine")
    let tagline: String    // tight one-line rule ("No A, E, I, O, U")
    let description: String // longer hint shown on the hero card
    /// Multi-paragraph rules + strategy explanation. Surfaced by the
    /// daily-screen info icon so players know how to actually beat the puzzle.
    let tips: String
    let coinReward: Int    // payout on a streak-qualifying completion
    let modifiers: PuzzleModifiers
}

/// All gameplay tweaks that a daily puzzle can apply to a normal raid.
/// `.none` is identity (matches the standard endless-run rules).
struct PuzzleModifiers: Equatable {
    // MARK: Letter bag
    /// Letters removed from the spawn pool. Example: vowel famine bans AEIOU.
    var bannedLetters: Set<Character> = []
    /// If non-nil, ONLY these letters can spawn (overrides bannedLetters).
    var allowedLettersOnly: Set<Character>? = nil
    /// Per-letter weight multipliers applied to the base Scrabble bag.
    /// Example: rare hunt sets {Q,Z,X,J,K} to 5.
    var bagMultipliers: [Character: Int] = [:]
    /// Probability a single roll produces a ★ wild instead of a regular letter.
    /// Engine default is 0.04.
    var wildSpawnChance: Double = 0.04

    // MARK: Run shape
    var lives: Int = 3
    var raidSeconds: Double = 30
    var holdLimit: Int = 10
    var allowZap: Bool = true
    var allowWild: Bool = true

    // MARK: Pace
    /// Multiplier on falling-letter vertical velocity (and the bomb spawn cadence).
    var letterSpeedMul: Double = 1.0
    /// Multiplier on enemy-bomb spawn rate (higher = more bombs).
    var bombRateMul: Double = 1.0

    // MARK: Scoring / validation
    /// Words shorter than this score zero. Default 2 = current behaviour.
    var minWordLength: Int = 2
    /// Flat multiplier applied to the breakdown's final score.
    var scoreMultiplier: Double = 1.0
    /// When false, length / efficiency / speed multipliers are turned off —
    /// final = base + rareBonus only. Used by Pure Word.
    var scoreUseBonuses: Bool = true
    /// Word must contain at least this many DISTINCT vowels to score.
    /// 0 = no requirement.
    var requireDistinctVowels: Int = 0

    static let none = PuzzleModifiers()

    /// The set of letters that the bag is allowed to roll, after applying
    /// `allowedLettersOnly` / `bannedLetters`. Wildcards are independent.
    var effectiveAllowedLetters: Set<Character> {
        let everything = Set(LetterData.table.keys)
        if let only = allowedLettersOnly {
            return only.intersection(everything)
        }
        return everything.subtracting(bannedLetters)
    }
}

enum DailyPuzzleCatalog {
    /// Active puzzle rotation. Order is arbitrary — selection uses a date
    /// hash modulo this count so the player sees the same puzzle on the
    /// same calendar day across devices.
    static let all: [DailyPuzzle] = [
        // ── Letter-bag puzzles ──────────────────────────────────────────
        .init(id: "vowel_famine", name: "Vowel Famine",
              tagline: "No A, E, I, O, U",
              description: "Build words from consonants only.",
              tips: """
              No vowels (A, E, I, O, U) will fall. Capture consonants and \
              build a valid word from them.

              Y is your friend — it acts as a vowel in many words: SHY, GYM, \
              CRY, HYMN, RHYTHM, MYTH.

              Strategy: short, consonant-heavy words are easier than long \
              ones. The dictionary still applies.
              """,
              coinReward: 500,
              modifiers: PuzzleModifiers(bannedLetters: ["A","E","I","O","U"])),
        .init(id: "vowel_feast", name: "Vowel Feast",
              tagline: "Vowels only",
              description: "Hunt for vowel-rich words like QUEUE, AUDIO, OUIJA.",
              tips: """
              Only vowels (and Y) fall. You're hunting for vowel-heavy \
              dictionary words.

              Targets: AI, OE, OI (2-letter Scrabble plays); AUDIO, OUIJA, \
              EERIE, AIOLI (longer plays); QUEUE if a wildcard turns into Q.

              Wildcards become powerful here — use them to fill in the \
              missing consonant.
              """,
              coinReward: 400,
              modifiers: PuzzleModifiers(allowedLettersOnly: ["A","E","I","O","U","Y"])),
        .init(id: "rare_hunt", name: "Rare Hunt",
              tagline: "Q/Z/X/J/K ×5",
              description: "High-value letters drop five times more often.",
              tips: """
              Q, Z, X, J, and K fall five times more often than usual. These \
              high-value tiles (5–10 points each) drive huge scores.

              Target words: QUIZ, JINX, KAYAK, ZAP, JOKE, WAX, FIZZ.

              The Rare Letter bonus (+50) triggers on any word containing an \
              8+ point letter (J, Q, X, Z). Stack it with a length bonus for \
              maximum payout.
              """,
              coinReward: 600,
              modifiers: PuzzleModifiers(bagMultipliers: ["Q": 5, "Z": 5, "X": 5, "J": 5, "K": 5])),
        .init(id: "q_storm", name: "Q Storm",
              tagline: "Q ×5",
              description: "Q falls 5× more often. QI, QAT are valid dictionary words.",
              tips: """
              Q falls 5× more often. Q is worth 10 points base, and Q-words \
              trigger the +50 rare-letter bonus.

              Q without U is fine: QI (a life force), QAT (a chewable leaf), \
              QADI, QOPH are all valid Scrabble plays.

              With normal letters around: QUEST, QUARTZ, EQUINE, QUEUE, \
              QUICK. Pair Q with a U from your letters for the easiest scores.
              """,
              coinReward: 700,
              modifiers: PuzzleModifiers(bagMultipliers: ["Q": 5])),
        .init(id: "wildcard_storm", name: "Wildcard Storm",
              tagline: "25% wild rate",
              description: "Wild ★ tiles fall a quarter of the time.",
              tips: """
              ★ Wildcard tiles fall 25% of the time (vs. 4% normally). Each \
              wildcard becomes any letter you choose during word building.

              Stockpile wildcards and aim for long words: 6+ letters unlocks \
              the length multiplier (×1.5 → ×2.0 for 8 letters).

              Wildcards earn 0 base points themselves, but they fill any \
              shape — so plan around the real letters you collect.
              """,
              coinReward: 400,
              modifiers: PuzzleModifiers(wildSpawnChance: 0.25)),

        // ── Run-shape puzzles ───────────────────────────────────────────
        .init(id: "speed_run", name: "Speed Run",
              tagline: "15s · 1.5× fall",
              description: "Half the time, faster letters.",
              tips: """
              15 seconds instead of 30. Letters fall 1.5× faster.

              Don't try to be perfect — capture aggressively, then submit \
              fast. The Speed Multiplier (up to ×1.5) rewards quick word \
              submissions.

              The +30s extend button costs heavy points (50 first use, 150 \
              second) — use it only if you're close to a great word.
              """,
              coinReward: 500,
              modifiers: PuzzleModifiers(raidSeconds: 15, letterSpeedMul: 1.5)),
        .init(id: "glass_cannon", name: "Glass Cannon",
              tagline: "1 life · 2× score",
              description: "One mistake and it's over. Every point counts double.",
              tips: """
              Single life. One hit from a bomb or letter ends the run \
              instantly.

              In return: every point scores 2×.

              Strategy: dodge first, capture second. Only fire when you have \
              a clean shot at a high-value letter. Bunkers are your \
              best friend — stay between them.
              """,
              coinReward: 800,
              modifiers: PuzzleModifiers(lives: 1, scoreMultiplier: 2.0)),
        .init(id: "tiny_rack", name: "Few Letters",
              tagline: "5 letters max",
              description: "Half the usual capacity. Use them wisely.",
              tips: """
              Letter capacity is 5 (vs. 10). When full, the raid ends \
              instantly.

              Be selective — chase rare letters (J, Q, X, Z) and skip \
              commons like A, E, T unless you need them to spell.

              The Efficiency bonus (+25%) triggers when you use 80%+ of \
              your letters — easy here since 4 of 5 hits that mark.
              """,
              coinReward: 600,
              modifiers: PuzzleModifiers(holdLimit: 5)),
        .init(id: "big_rack", name: "Many Letters",
              tagline: "15 letters max",
              description: "Stockpile letters and build long words.",
              tips: """
              Letter capacity is 15 (vs. 10). More room to collect a \
              diverse alphabet.

              Aim long: 6 letters = ×1.5, 7 = ×1.75, 8 = ×2.0 length multiplier. \
              Combined with the +50 rare-letter bonus and speed bonus, an \
              8-letter rare-letter word can score 400+.

              Watch your time — building a long word takes setup.
              """,
              coinReward: 500,
              modifiers: PuzzleModifiers(holdLimit: 15)),
        .init(id: "pacifist", name: "Pacifist",
              tagline: "No ZAP, no WILD",
              description: "Pure skill — no power-ups available.",
              tips: """
              Both power-up buttons are disabled. No ZAP (mass-capture), no \
              WILD (next capture becomes a wildcard).

              Pure shooting accuracy + word-building skill.

              Strategy: aim carefully, conserve fire when bombs are close, \
              and pick a tight word target early so you know which letters \
              to chase.
              """,
              coinReward: 400,
              modifiers: PuzzleModifiers(allowZap: false, allowWild: false)),

        // ── Word-rule puzzles ───────────────────────────────────────────
        .init(id: "long_word", name: "Long Word",
              tagline: "6+ letters only",
              description: "Short words score zero. Build something substantial.",
              tips: """
              Words shorter than 6 letters score 0 and don't qualify for the \
              streak.

              Target hits: FORGET, MARBLE, JOCKEY, SQUEEZE, QUARTZ, QUICKLY. \
              The length multiplier rewards going even longer (×1.75 at 7, \
              ×2.0 at 8).

              Capture broadly — you need 6+ usable letters before you can \
              even score.
              """,
              coinReward: 700,
              modifiers: PuzzleModifiers(minWordLength: 6)),
        .init(id: "pangram", name: "Vowel Hunt",
              tagline: "4+ distinct vowels",
              description: "Word must contain at least four different vowels (A E I O U).",
              tips: """
              Your word must contain at least 4 of the 5 distinct vowels \
              (A E I O U). Y doesn't count.

              Target hits: SEQUOIA, OUTRAGE (5/5!), EDUCATION, VARIATION, \
              AUTHORITIES, MIRACULOUS, AUDITION.

              Capture vowels aggressively — you'll need most of them. \
              Wildcards can fill in any vowel you're missing.
              """,
              coinReward: 800,
              modifiers: PuzzleModifiers(requireDistinctVowels: 4)),
        .init(id: "pure_word", name: "Pure Word",
              tagline: "Base + rare only",
              description: "No length / efficiency / speed bonuses. Letter values are all that matter.",
              tips: """
              Pure Word changes how your word is SCORED, not how it's \
              validated. The only ways to "fail":
              • Your word isn't in the dictionary.
              • You submitted with fewer than 2 letters (or timed out \
              without building one).

              Any valid 2+ letter dictionary word qualifies for the streak \
              and the coin reward — even a tiny one like AT or QI.

              What's actually different: length, efficiency, and speed \
              multipliers are all OFF. Only base letter values + the +50 \
              rare-letter bonus count.

              Maximize letter VALUE, not length: Q (10) + Z (10) = 20, \
              JINX = 19, QUIZ = 22 (with rare bonus). A 7-letter word with \
              no rare letters might still score less than QI.

              No reason to rush submission — speed doesn't matter.
              """,
              coinReward: 500,
              modifiers: PuzzleModifiers(scoreUseBonuses: false)),

        // ── Pace-tweak puzzles ──────────────────────────────────────────
        .init(id: "slow_motion", name: "Slow Motion",
              tagline: "0.5× tempo",
              description: "Letters and bombs both move at half speed.",
              tips: """
              Letters and bombs fall at half speed. Plenty of time to aim \
              and pick which letters you want.

              Use the breathing room to be selective — chase the high-value \
              tiles (J, Q, X, Z) and ignore filler.

              The speed bonus still rewards fast word submission, so don't \
              dawdle in Phase 2.
              """,
              coinReward: 400,
              modifiers: PuzzleModifiers(letterSpeedMul: 0.5, bombRateMul: 0.5)),
        .init(id: "bullet_hell", name: "Bullet Hell",
              tagline: "2× bombs",
              description: "Enemy bombs spawn twice as often.",
              tips: """
              Bombs spawn 2× more often. The screen will be busy with red \
              projectiles.

              Dodging is the priority — your bunkers are crucial. Stay \
              behind cover and pop out to fire.

              Capture quickly when the lanes are clear. The clock still \
              ticks — don't camp.
              """,
              coinReward: 500,
              modifiers: PuzzleModifiers(bombRateMul: 2.0)),
    ]

    /// Returns today's puzzle. Pure function of the calendar date so every
    /// device sees the same puzzle on the same day. Uses the device's
    /// current calendar/timezone — players in different timezones may roll
    /// over to the next puzzle at different wall-clock instants, which is
    /// the expected daily-puzzle behaviour.
    static func puzzle(forDate date: Date = Date(),
                       calendar: Calendar = .current) -> DailyPuzzle {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 2025
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        // Stable, calendar-only index — no clock-time or runtime randomness.
        let index = ((y &* 372) &+ (m &* 31) &+ d) % all.count
        return all[(index + all.count) % all.count]
    }

    /// Seconds remaining until the next calendar-day rollover. Drives the
    /// "RESETS IN HH:MM:SS" countdown on the daily screen.
    static func secondsUntilNextDay(from date: Date = Date(),
                                    calendar: Calendar = .current) -> TimeInterval {
        guard let next = calendar.nextDate(after: date,
                                           matching: DateComponents(hour: 0, minute: 0, second: 0),
                                           matchingPolicy: .nextTime) else {
            return 0
        }
        return max(0, next.timeIntervalSince(date))
    }
}
