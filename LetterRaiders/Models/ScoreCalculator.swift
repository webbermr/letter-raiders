import Foundation

struct ScoreBreakdown {
    var word: String
    var valid: Bool
    var base: Int
    var lengthMul: Double
    var effPct: Double
    var rareBonus: Int
    var speedMul: Double
    var beforeSpeed: Int
    var withEff: Int
    var final: Int
    var used: Int
    var total: Int
    var hasRare: Bool
    /// Flat penalty subtracted from `final` because the player extended the
    /// timer one or more times. Shown as a separate row in the breakdown.
    var timePenalty: Int = 0

    static let sampleQuits = ScoreBreakdown(
        word: "QUITS",
        valid: true,
        base: 14,
        lengthMul: 1.25,
        effPct: 0,
        rareBonus: 50,
        speedMul: 1.3,
        beforeSpeed: 67,
        withEff: 67,
        final: 88,
        used: 5, total: 8, hasRare: true
    )
}

enum ScoreCalculator {
    static func score(word: [CapturedLetter],
                      racked: [CapturedLetter],
                      timeLeft: Double,
                      maxTime: Double,
                      modifiers: PuzzleModifiers = .none,
                      loadout: ShipLoadout = ShipLoadout.forID("viper")) -> ScoreBreakdown {
        let used = word.count
        let total = racked.count
        let base = word.reduce(0) { $0 + ($1.wild ? 0 : $1.value) }
        let lengthMul: Double = used >= 8 ? 2 : used >= 7 ? 1.75 : used >= 6 ? 1.5 : used >= 5 ? 1.25 : 1
        let effRatio = total == 0 ? 0 : Double(used) / Double(total)
        let effPct: Double = effRatio >= 0.8 ? 0.25 : effRatio >= 0.5 ? 0.10 : 0
        let hasRare = word.contains { !$0.wild && $0.value >= 8 }
        // Specter: rareBonusMul scales the flat +50 rare-letter bonus
        // (e.g. 2× → +100).
        let rareBonus = hasRare ? Int((Double(50) * loadout.rareBonusMul).rounded()) : 0
        let speedMul = 1 + max(0, min(1, timeLeft / max(1, maxTime))) * 0.5

        let wordString = word.map { tile -> String in
            if tile.wild {
                if let picked = tile.pickedLetter { return String(picked) }
                return "?"
            }
            return String(tile.letter)
        }.joined()

        // Dictionary validity is necessary but not sufficient under daily
        // modifiers — the word must also clear the puzzle's length / vowel
        // rules to count as "valid" (i.e. score above zero and qualify for
        // the streak).
        let inDictionary = WordDictionary.shared.isValid(wordString)
        let meetsLength = used >= modifiers.minWordLength
        let meetsVowels: Bool = {
            guard modifiers.requireDistinctVowels > 0 else { return true }
            let vowels: Set<Character> = ["A","E","I","O","U"]
            let used = Set(wordString.uppercased()).intersection(vowels)
            return used.count >= modifiers.requireDistinctVowels
        }()
        let valid = inDictionary && meetsLength && meetsVowels

        // Pure Word turns off the length / efficiency / speed multipliers so
        // the breakdown is just base + rare. Other multipliers stay at 1.0
        // and effPct stays at 0 so the breakdown card hides those rows.
        let effLength = modifiers.scoreUseBonuses ? lengthMul : 1.0
        let effEff: Double = modifiers.scoreUseBonuses ? effPct : 0.0
        let effSpeed = modifiers.scoreUseBonuses ? speedMul : 1.0

        let beforeSpeed = Double(base) * effLength + Double(rareBonus)
        let withEff = beforeSpeed * (1 + effEff)
        let rawFinal = withEff * effSpeed
        // Compound modifier × loadout multipliers — Singularity contributes
        // ×1.2 (or whatever the ship configures) on top of any puzzle multi.
        let scaled = rawFinal * max(0, modifiers.scoreMultiplier) * max(0, loadout.wordScoreMul)
        let final = valid ? Int(scaled.rounded()) : 0

        return ScoreBreakdown(
            word: wordString,
            valid: valid,
            base: base,
            lengthMul: effLength,
            effPct: effEff,
            rareBonus: rareBonus,
            speedMul: effSpeed,
            beforeSpeed: Int(beforeSpeed.rounded()),
            withEff: Int(withEff.rounded()),
            final: final,
            used: used,
            total: total,
            hasRare: hasRare
        )
    }
}
