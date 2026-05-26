import Foundation
import SwiftUI

// MARK: - Achievement identifiers

enum AchievementID: String, CaseIterable, Identifiable {
    case firstContact    = "first_contact"
    case wordSmith       = "word_smith"
    case lexicographer   = "lexicographer"
    case rareFind        = "rare_find"
    case pangram         = "pangram"
    case comboKiller     = "combo_killer"
    case marathon        = "marathon"
    case stockpiler      = "stockpiler"
    case hangarComplete  = "hangar_complete"
    case streakWeek      = "streak_week"
    case streakMonth     = "streak_month"
    case promotion       = "promotion"
    case seniorOfficer   = "senior_officer"
    case grandAdmiral    = "grand_admiral"
    case dailyDevotee    = "daily_devotee"
    // Additional daily-completion tiers (Daily Devotee covers 30).
    case firstDaily       = "first_daily"
    case dailyFive        = "daily_five"
    case dailyTen         = "daily_ten"
    case dailyTwenty      = "daily_twenty"
    case dailyForty       = "daily_forty"
    case dailyFifty       = "daily_fifty"
    case dailySeventyFive = "daily_seventy_five"
    case dailyHundred     = "daily_hundred"

    // First-time word-length milestones (7 & 9 covered by Word Smith /
    // Lexicographer above so they're not duplicated here).
    case fiveLetterWord  = "five_letter_word"
    case sixLetterWord   = "six_letter_word"
    case eightLetterWord = "eight_letter_word"
    case tenLetterWord   = "ten_letter_word"

    // Progressive tier badges: submit N words of length L for tiers
    // 10 / 25 / 50 / 100 / 200, for each length 5–10.
    case fives10,  fives25,  fives50,  fives100,  fives200
    case sixes10,  sixes25,  sixes50,  sixes100,  sixes200
    case sevens10, sevens25, sevens50, sevens100, sevens200
    case eights10, eights25, eights50, eights100, eights200
    case nines10,  nines25,  nines50,  nines100,  nines200
    case tens10,   tens25,   tens50,   tens100,   tens200

    var id: String { rawValue }
}

// MARK: - Achievement catalog row

/// Static metadata about an achievement plus a `provider` closure that
/// reads the live progress value from whichever store actually owns the
/// underlying stat (AchievementStore, PlayerProfile, Hangar, etc.).
struct AchievementInfo: Identifiable {
    let id: AchievementID
    let name: String
    let summary: String
    /// SF Symbol used as the badge icon.
    let icon: String
    /// Theme accent for the unlocked state. Locked badges desaturate it.
    let accent: Color
    /// Threshold for unlock. Binary achievements use `target = 1`.
    let target: Int
    /// Returns the live progress count. Clamped against `target` by the
    /// computed `progress`/`isUnlocked` helpers below.
    let provider: () -> Int

    /// Current numeric progress, clamped at the target for display.
    var current: Int { min(target, max(0, provider())) }

    /// 0…1 progress fraction.
    var progress: Double { Double(current) / Double(max(1, target)) }

    var isUnlocked: Bool { provider() >= target }

    /// True for multi-step achievements that benefit from a visible bar.
    /// Binary (target == 1) badges just show locked/unlocked state.
    var hasProgressBar: Bool { target > 1 }
}

// MARK: - Catalog

enum AchievementCatalog {
    /// Ordered list shown on the Badges screen. Order = visual grouping
    /// (milestones → word-length binary → word-length tiers → progression).
    static let all: [AchievementInfo] = {
        var entries: [AchievementInfo] = [
            AchievementInfo(
                id: .firstContact, name: "First Contact",
                summary: "Finish your first run.",
                icon: "play.circle.fill", accent: Theme.cyan, target: 1,
                provider: { AchievementStore.get(.runsCompleted) > 0 ? 1 : 0 }
            ),
            AchievementInfo(
                id: .rareFind, name: "Rare Find",
                summary: "Score a word with J, Q, X, or Z.",
                icon: "sparkles", accent: Theme.yellow, target: 1,
                provider: { AchievementStore.get(.hasRareWord) }
            ),
            AchievementInfo(
                id: .pangram, name: "Pangram",
                summary: "Submit a word with all 5 vowels (AEIOU).",
                icon: "rosette", accent: Theme.amber, target: 1,
                provider: { AchievementStore.get(.hasPangram) }
            ),
            AchievementInfo(
                id: .comboKiller, name: "Combo Killer",
                summary: "Hit a 9-combo in a single raid.",
                icon: "flame.fill", accent: Theme.pink, target: 9,
                provider: { AchievementStore.get(.bestCombo) }
            ),
            AchievementInfo(
                id: .marathon, name: "Marathon",
                summary: "Clear 10 raids in a single run.",
                icon: "figure.run", accent: Theme.green, target: 10,
                provider: { AchievementStore.get(.maxRaidsInRun) }
            ),
            AchievementInfo(
                id: .stockpiler, name: "Stockpiler",
                summary: "Bank 5+ of one power-up type.",
                icon: "bolt.fill", accent: Theme.yellow, target: 5,
                provider: { max(Hangar.zapStock, Hangar.wildStock) }
            ),
            AchievementInfo(
                id: .hangarComplete, name: "Hangar Complete",
                summary: "Own every ship in the hangar.",
                icon: "airplane", accent: Theme.pinkSoft, target: ShipSkin.all.count,
                provider: { Hangar.ownedIDs.count }
            ),

            // Word-length binary milestones — one badge per length (5,6,7,8,9,10).
            // 7 and 9 keep their original Word Smith / Lexicographer names.
            AchievementInfo(
                id: .fiveLetterWord, name: "Five-Letter Word",
                summary: "Submit a 5-letter word.",
                icon: "5.circle.fill", accent: Theme.cyanSoft, target: 1,
                provider: { AchievementStore.wordsExact(5) > 0 ? 1 : 0 }
            ),
            AchievementInfo(
                id: .sixLetterWord, name: "Six-Letter Word",
                summary: "Submit a 6-letter word.",
                icon: "6.circle.fill", accent: Theme.cyan, target: 1,
                provider: { AchievementStore.wordsExact(6) > 0 ? 1 : 0 }
            ),
            AchievementInfo(
                id: .wordSmith, name: "Word Smith",
                summary: "Submit a 7-letter word.",
                icon: "7.circle.fill", accent: Theme.violet, target: 1,
                provider: { AchievementStore.wordsExact(7) > 0 ? 1 : 0 }
            ),
            AchievementInfo(
                id: .eightLetterWord, name: "Eight-Letter Word",
                summary: "Submit an 8-letter word.",
                icon: "8.circle.fill", accent: Theme.pinkSoft, target: 1,
                provider: { AchievementStore.wordsExact(8) > 0 ? 1 : 0 }
            ),
            AchievementInfo(
                id: .lexicographer, name: "Lexicographer",
                summary: "Submit a 9-letter word.",
                icon: "9.circle.fill", accent: Theme.pink, target: 1,
                provider: { AchievementStore.wordsExact(9) > 0 ? 1 : 0 }
            ),
            AchievementInfo(
                id: .tenLetterWord, name: "Ten-Letter Word",
                summary: "Submit a 10-letter word.",
                icon: "10.circle.fill", accent: Theme.yellow, target: 1,
                provider: { AchievementStore.wordsExact(10) > 0 ? 1 : 0 }
            ),
        ]

        // Progressive tier badges — 5 tiers × 6 lengths = 30 entries.
        // A word of length L counts toward every tier at length <= L, so
        // chasing long words naturally fills out the shorter-tier rows.
        // Tier icons escalate: rosette → medal → trophy → trophy.fill → crown.
        struct LengthSpec {
            let length: Int
            let label: String      // "Fives" / "Sixes" / …
            let accent: Color
        }
        struct TierSpec {
            let suffix: String     // "I" / "II" / …
            let count: Int
            let icon: String
            let ids: [Int: AchievementID]  // length → id
        }
        let lengths: [LengthSpec] = [
            .init(length: 5,  label: "Fives",  accent: Theme.cyanSoft),
            .init(length: 6,  label: "Sixes",  accent: Theme.cyan),
            .init(length: 7,  label: "Sevens", accent: Theme.violet),
            .init(length: 8,  label: "Eights", accent: Theme.pinkSoft),
            .init(length: 9,  label: "Nines",  accent: Theme.pink),
            .init(length: 10, label: "Tens",   accent: Theme.yellow),
        ]
        let tiers: [TierSpec] = [
            .init(suffix: "I",   count: 10,  icon: "rosette",
                  ids: [5: .fives10, 6: .sixes10, 7: .sevens10, 8: .eights10, 9: .nines10, 10: .tens10]),
            .init(suffix: "II",  count: 25,  icon: "medal.fill",
                  ids: [5: .fives25, 6: .sixes25, 7: .sevens25, 8: .eights25, 9: .nines25, 10: .tens25]),
            .init(suffix: "III", count: 50,  icon: "trophy",
                  ids: [5: .fives50, 6: .sixes50, 7: .sevens50, 8: .eights50, 9: .nines50, 10: .tens50]),
            .init(suffix: "IV",  count: 100, icon: "trophy.fill",
                  ids: [5: .fives100, 6: .sixes100, 7: .sevens100, 8: .eights100, 9: .nines100, 10: .tens100]),
            .init(suffix: "V",   count: 200, icon: "crown.fill",
                  ids: [5: .fives200, 6: .sixes200, 7: .sevens200, 8: .eights200, 9: .nines200, 10: .tens200]),
        ]
        for spec in lengths {
            let length = spec.length     // captured by the provider closure below
            for tier in tiers {
                guard let id = tier.ids[length] else { continue }
                entries.append(AchievementInfo(
                    id: id,
                    name: "\(spec.label) \(tier.suffix)",
                    summary: "Submit \(tier.count) words of exactly \(length) letters.",
                    icon: tier.icon,
                    accent: spec.accent,
                    target: tier.count,
                    provider: { AchievementStore.wordsExact(length) }
                ))
            }
        }

        // Progression badges (ranks / streaks / daily devotion).
        entries.append(contentsOf: [
            AchievementInfo(
                id: .streakWeek, name: "Streak Week",
                summary: "Reach a 7-day daily streak.",
                icon: "calendar", accent: Theme.amber, target: 7,
                provider: { AchievementStore.get(.bestStreak) }
            ),
            AchievementInfo(
                id: .streakMonth, name: "Streak Month",
                summary: "Reach a 30-day daily streak.",
                icon: "calendar.badge.plus", accent: Theme.red, target: 30,
                provider: { AchievementStore.get(.bestStreak) }
            ),
            AchievementInfo(
                id: .promotion, name: "Promotion",
                summary: "Reach Lieutenant (Rank 5).",
                icon: "star.fill", accent: Theme.cyanSoft, target: 5,
                provider: { PlayerProfile.rank }
            ),
            AchievementInfo(
                id: .seniorOfficer, name: "Senior Officer",
                summary: "Reach Commander (Rank 7).",
                icon: "star.circle.fill", accent: Theme.violet, target: 7,
                provider: { PlayerProfile.rank }
            ),
            AchievementInfo(
                id: .grandAdmiral, name: "Grand Admiral",
                summary: "Reach the max rank (20).",
                icon: "crown.fill", accent: Theme.yellow, target: 20,
                provider: { PlayerProfile.rank }
            ),
            // Daily-puzzle completion tiers — counts up from a first-ever
            // milestone all the way to a 100-completion grind.
            AchievementInfo(
                id: .firstDaily, name: "First Daily",
                summary: "Complete your first daily puzzle.",
                icon: "calendar.circle.fill", accent: Theme.cyanSoft, target: 1,
                provider: { AchievementStore.get(.dailyCompletedTotal) }
            ),
            AchievementInfo(
                id: .dailyFive, name: "Daily Five",
                summary: "Complete 5 daily puzzles.",
                icon: "5.square.fill", accent: Theme.cyan, target: 5,
                provider: { AchievementStore.get(.dailyCompletedTotal) }
            ),
            AchievementInfo(
                id: .dailyTen, name: "Daily Ten",
                summary: "Complete 10 daily puzzles.",
                icon: "10.square.fill", accent: Theme.green, target: 10,
                provider: { AchievementStore.get(.dailyCompletedTotal) }
            ),
            AchievementInfo(
                id: .dailyTwenty, name: "Daily Twenty",
                summary: "Complete 20 daily puzzles.",
                icon: "20.square.fill", accent: Theme.amber, target: 20,
                provider: { AchievementStore.get(.dailyCompletedTotal) }
            ),
            AchievementInfo(
                id: .dailyDevotee, name: "Daily Devotee",
                summary: "Complete 30 daily puzzles.",
                icon: "star.square.fill", accent: Theme.amber, target: 30,
                provider: { AchievementStore.get(.dailyCompletedTotal) }
            ),
            AchievementInfo(
                id: .dailyForty, name: "Daily Forty",
                summary: "Complete 40 daily puzzles.",
                icon: "40.square.fill", accent: Theme.pinkSoft, target: 40,
                provider: { AchievementStore.get(.dailyCompletedTotal) }
            ),
            AchievementInfo(
                id: .dailyFifty, name: "Daily Fifty",
                summary: "Complete 50 daily puzzles.",
                icon: "50.square.fill", accent: Theme.pink, target: 50,
                provider: { AchievementStore.get(.dailyCompletedTotal) }
            ),
            AchievementInfo(
                id: .dailySeventyFive, name: "Daily 75",
                summary: "Complete 75 daily puzzles.",
                icon: "rosette", accent: Theme.violet, target: 75,
                provider: { AchievementStore.get(.dailyCompletedTotal) }
            ),
            AchievementInfo(
                id: .dailyHundred, name: "Daily Centurion",
                summary: "Complete 100 daily puzzles.",
                icon: "crown.fill", accent: Theme.yellow, target: 100,
                provider: { AchievementStore.get(.dailyCompletedTotal) }
            ),
        ])

        return entries
    }()

    /// Count of unlocked achievements (computed on demand — cheap because
    /// the catalog is small).
    static var unlockedCount: Int {
        all.filter { $0.isUnlocked }.count
    }
}

// MARK: - Persistent stat store

/// Local-only stat counters that back achievement progress. Game Center
/// will hang off these later — for now everything is UserDefaults.
enum AchievementStore {
    /// Tracked stats. Each is stored under "achStat.<rawValue>" so the
    /// keys are self-namespacing.
    enum Stat: String {
        case runsCompleted        // total endRun calls
        case longestWord          // best valid-word length ever
        case hasRareWord          // 0/1 — ever scored a J/Q/X/Z word
        case hasPangram           // 0/1 — ever scored a 5-vowel word
        case bestCombo            // best combo achieved across any raid
        case maxRaidsInRun        // most raids cleared in a single run
        case bestStreak           // highest daily streak ever
        case dailyCompletedTotal  // total daily puzzles completed (qualifying)
        // Word-length progression counters — one per exact length. A
        // 7-letter word ONLY bumps `wordsExact7`; it does not touch
        // `wordsExact5` or `wordsExact6`. Badges are tied to the explicit
        // shape the player submitted, so e.g. the "Six-Letter Word" badge
        // requires submitting a word of exactly six letters. Words of 11+
        // letters are bucketed into the 10-counter (the catalog tops out
        // at 10).
        case wordsExact5
        case wordsExact6
        case wordsExact7
        case wordsExact8
        case wordsExact9
        case wordsExact10
    }

    /// Helper for catalog providers: maps length → counter stat.
    static func wordsExact(_ length: Int) -> Int {
        switch length {
        case 5:  return get(.wordsExact5)
        case 6:  return get(.wordsExact6)
        case 7:  return get(.wordsExact7)
        case 8:  return get(.wordsExact8)
        case 9:  return get(.wordsExact9)
        case 10: return get(.wordsExact10)
        default: return 0
        }
    }

    private static let prefix = "achStat."

    static func get(_ stat: Stat) -> Int {
        UserDefaults.standard.integer(forKey: prefix + stat.rawValue)
    }

    /// Idempotent — only writes when the new value is larger. Use for any
    /// "best ever" stat to avoid resetting on a worse run.
    private static func setMax(_ stat: Stat, to value: Int) {
        let current = get(stat)
        if value > current {
            UserDefaults.standard.set(value, forKey: prefix + stat.rawValue)
        }
    }

    private static func increment(_ stat: Stat, by amount: Int = 1) {
        UserDefaults.standard.set(get(stat) + amount, forKey: prefix + stat.rawValue)
    }

    private static func setFlag(_ stat: Stat) {
        UserDefaults.standard.set(1, forKey: prefix + stat.rawValue)
    }

    // MARK: - Recording hooks

    /// Fired from `RootView.endRun` after daily bookkeeping but before
    /// routing to game over. Captures whole-run "best ever" stats and the
    /// per-run completion counters.
    static func recordRunEnd(bestCombo: Int,
                             raidsCleared: Int,
                             dailySuccess: Bool,
                             currentStreak: Int) {
        increment(.runsCompleted)
        setMax(.bestCombo, to: bestCombo)
        setMax(.maxRaidsInRun, to: raidsCleared)
        setMax(.bestStreak, to: currentStreak)
        if dailySuccess { increment(.dailyCompletedTotal) }
    }

    /// Fired from `RootView.handleWordResult` once a word has been
    /// validated. Drives word-quality achievements.
    static func recordValidWord(length: Int,
                                hasRareLetter: Bool,
                                distinctVowels: Int) {
        setMax(.longestWord, to: length)
        if hasRareLetter { setFlag(.hasRareWord) }
        if distinctVowels >= 5 { setFlag(.hasPangram) }

        // Bump only the exact-length counter so badges line up with what
        // the player actually submitted. Words 11+ letters fold into the
        // 10-counter (highest tracked bucket).
        switch min(10, length) {
        case 5:  increment(.wordsExact5)
        case 6:  increment(.wordsExact6)
        case 7:  increment(.wordsExact7)
        case 8:  increment(.wordsExact8)
        case 9:  increment(.wordsExact9)
        case 10: increment(.wordsExact10)
        default: break  // <5 letters earns no length-tier credit
        }
    }
}
