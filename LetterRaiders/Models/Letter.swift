import SwiftUI

struct LetterInfo {
    let value: Int
    let tier: Int
    let weight: Int
}

enum LetterData {
    static let table: [Character: LetterInfo] = [
        "A": .init(value: 1, tier: 1, weight: 9),
        "B": .init(value: 3, tier: 3, weight: 2),
        "C": .init(value: 3, tier: 3, weight: 2),
        "D": .init(value: 2, tier: 2, weight: 4),
        "E": .init(value: 1, tier: 1, weight: 12),
        "F": .init(value: 4, tier: 3, weight: 2),
        "G": .init(value: 2, tier: 2, weight: 3),
        "H": .init(value: 4, tier: 3, weight: 2),
        "I": .init(value: 1, tier: 1, weight: 9),
        "J": .init(value: 8, tier: 4, weight: 1),
        "K": .init(value: 5, tier: 3, weight: 1),
        "L": .init(value: 1, tier: 1, weight: 4),
        "M": .init(value: 3, tier: 3, weight: 2),
        "N": .init(value: 1, tier: 1, weight: 6),
        "O": .init(value: 1, tier: 1, weight: 8),
        "P": .init(value: 3, tier: 3, weight: 2),
        "Q": .init(value: 10, tier: 5, weight: 1),
        "R": .init(value: 1, tier: 1, weight: 6),
        "S": .init(value: 1, tier: 1, weight: 4),
        "T": .init(value: 1, tier: 1, weight: 6),
        "U": .init(value: 1, tier: 1, weight: 4),
        "V": .init(value: 4, tier: 3, weight: 2),
        "W": .init(value: 4, tier: 3, weight: 2),
        "X": .init(value: 8, tier: 4, weight: 1),
        "Y": .init(value: 4, tier: 3, weight: 2),
        "Z": .init(value: 10, tier: 5, weight: 1),
    ]

    /// Vanilla weighted bag used by the standard endless run.
    static let defaultBag: [Character] = {
        var result: [Character] = []
        for (letter, info) in table {
            for _ in 0..<info.weight { result.append(letter) }
        }
        return result
    }()

    /// Build a sample bag honouring a daily puzzle's letter restrictions.
    /// Banned / not-allowed letters are excluded; `bagMultipliers` scales
    /// the base Scrabble weight for specific letters. Returns the vanilla
    /// bag if no modifiers are in play, to avoid wasted work for normal runs.
    static func bag(for modifiers: PuzzleModifiers) -> [Character] {
        if modifiers.allowedLettersOnly == nil
            && modifiers.bannedLetters.isEmpty
            && modifiers.bagMultipliers.isEmpty {
            return defaultBag
        }
        let allowed = modifiers.effectiveAllowedLetters
        var result: [Character] = []
        for (letter, info) in table where allowed.contains(letter) {
            let mul = max(1, modifiers.bagMultipliers[letter] ?? 1)
            let count = info.weight * mul
            for _ in 0..<count { result.append(letter) }
        }
        return result
    }

    static func pickLetter() -> Character {
        defaultBag.randomElement() ?? "E"
    }

    static func value(for letter: Character) -> Int {
        table[letter]?.value ?? 0
    }

    static func tier(for letter: Character) -> Int {
        table[letter]?.tier ?? 1
    }
}

struct TierProfile {
    let color: Color
    let glow: Color
    let speed: Double   // points per ms downward
    let spawnY: CGFloat
    let label: String
}

enum TierTable {
    static let wildColor = Color(hex: 0xFDE047)
    static let wildGlow = Color(hex: 0xFBBF24)

    static let profiles: [Int: TierProfile] = [
        1: .init(color: Color(hex: 0x67E8F9), glow: Color(hex: 0x22D3EE), speed: 0.06,  spawnY: 165, label: "COMMON"),
        2: .init(color: Color(hex: 0x5EEAD4), glow: Color(hex: 0x14B8A6), speed: 0.075, spawnY: 145, label: "USEFUL"),
        3: .init(color: Color(hex: 0xFBBF24), glow: Color(hex: 0xF59E0B), speed: 0.105, spawnY: 115, label: "TRICKY"),
        4: .init(color: Color(hex: 0xFF6DB1), glow: Color(hex: 0xEC4899), speed: 0.155, spawnY:  80, label: "RARE"),
        5: .init(color: Color(hex: 0xD946EF), glow: Color(hex: 0xA855F7), speed: 0.21,  spawnY:  40, label: "PRIZE"),
    ]

    static func profile(_ tier: Int) -> TierProfile {
        profiles[tier] ?? profiles[1]!
    }
}

struct CapturedLetter: Identifiable, Equatable {
    let id = UUID()
    let letter: Character        // "★" for wildcard pre-pick
    let value: Int
    let tier: Int
    let wild: Bool
    var pickedLetter: Character? // chosen letter for wildcard during word building

    init(letter: Character, value: Int, tier: Int, wild: Bool = false, pickedLetter: Character? = nil) {
        self.letter = letter
        self.value = value
        self.tier = tier
        self.wild = wild
        self.pickedLetter = pickedLetter
    }

    static let sampleQuites: [CapturedLetter] = [
        .init(letter: "R", value: 1, tier: 1),
        .init(letter: "A", value: 1, tier: 1),
        .init(letter: "Q", value: 10, tier: 5),
        .init(letter: "U", value: 1, tier: 1),
        .init(letter: "I", value: 1, tier: 1),
        .init(letter: "T", value: 1, tier: 1),
        .init(letter: "E", value: 1, tier: 1),
        .init(letter: "S", value: 1, tier: 1),
    ]
}

struct FallingLetter: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vy: CGFloat
    let letter: Character
    let value: Int
    let tier: Int
    let wild: Bool
    let color: Color
    let glow: Color
}

enum LetterRoll {
    /// Pick a falling letter from a precomputed weighted bag, with the
    /// caller's wild-spawn chance applied first. `bag` may be empty only if
    /// the puzzle modifiers filtered everything out — defensive fallback
    /// returns an "E" so spawning never crashes.
    static func roll(wildChance: Double = 0.04,
                     bag: [Character] = LetterData.defaultBag) -> FallingLetter {
        if Double.random(in: 0..<1) < wildChance {
            return FallingLetter(
                x: 0, y: TierTable.profile(5).spawnY,
                vy: 0.22,
                letter: "★", value: 0, tier: 5, wild: true,
                color: TierTable.wildColor, glow: TierTable.wildGlow
            )
        }
        let L = bag.randomElement() ?? "E"
        guard let info = LetterData.table[L] else {
            return FallingLetter(x: 0, y: 165, vy: 0.06, letter: "E", value: 1, tier: 1, wild: false,
                                 color: TierTable.profile(1).color, glow: TierTable.profile(1).glow)
        }
        let prof = TierTable.profile(info.tier)
        return FallingLetter(
            x: 0, y: prof.spawnY,
            vy: prof.speed * Double.random(in: 0.9...1.1),
            letter: L, value: info.value, tier: info.tier, wild: false,
            color: prof.color, glow: prof.glow
        )
    }
}
