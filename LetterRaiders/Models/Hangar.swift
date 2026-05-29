import SwiftUI

/// Per-ship gameplay parameters consumed by the shooter engine.
/// Every ship gets one of these. Viper is the neutral baseline (1.0× / 20px /
/// 0 pierce). Each non-baseline ship tweaks exactly the field its description
/// promises so the on-card text matches what the player feels in-game.
struct ShipLoadout {
    let id: String
    let body: Color
    let accent: Color
    // Original five perks (Magenta / Argon / Twilight / Aurora / Nova).
    var glideMul: Double = 1.0
    var comboDecayMul: Double = 1.0
    var bulletHitRadius: CGFloat = 20
    var flybyCoinMul: Double = 1.0
    var bulletPierces: Int = 0
    // Cascade — multiplier on the fire-cooldown duration (<1 = faster fire).
    var fireCooldownMul: Double = 1.0
    // Phantom — letters reaching the bottom are captured instead of escaping.
    var letterMagnet: Bool = false
    // Sentinel — the first hit each raid is absorbed (no life lost).
    var firstHitShield: Bool = false
    // Bastion — bunker row count multiplier (1.5 = 6 rows vs default 4).
    var bunkerSizeMul: Double = 1.0
    // Eclipse — bonus seconds added to the raid timer / word phase timer.
    var bonusRaidSeconds: Double = 0
    var bonusWordSeconds: Double = 0
    // Skyhawk — extra hold-limit slots per raid (added to PlayScreen's 10).
    var bonusHoldLimit: Int = 0
    // Nebula — multiplier on enemy bomb fall speed (<1 = slower bombs).
    var bombSpeedMul: Double = 1.0
    // Pulsar — multiplier on the wildcard spawn rate.
    var wildSpawnMul: Double = 1.0
    // Specter — multiplier on the +50 rare-letter bonus in the word score.
    var rareBonusMul: Double = 1.0
    // Singularity — flat multiplier applied to the final word score.
    var wordScoreMul: Double = 1.0

    static func forID(_ id: String) -> ShipLoadout {
        let body: Color
        let accent: Color
        switch id {
        case "magenta":     body = Theme.pinkSoft; accent = Theme.yellow
        case "argon":       body = Theme.green;    accent = Theme.cyan
        case "twilight":    body = Theme.violet;   accent = Theme.pink
        case "aurora":      body = Theme.yellow;   accent = Theme.amber
        case "nova":        body = Theme.red;      accent = Theme.yellow
        case "cascade":     body = Theme.cyan;     accent = Theme.amber
        case "phantom":     body = Theme.violet;   accent = Theme.cyanSoft
        case "sentinel":    body = Theme.green;    accent = Theme.pinkSoft
        case "bastion":     body = Theme.amber;    accent = Theme.green
        case "eclipse":     body = Theme.violet;   accent = Theme.cyan
        case "skyhawk":     body = Theme.cyanSoft; accent = Theme.violet
        case "nebula":      body = Theme.pinkSoft; accent = Theme.amber
        case "pulsar":      body = Theme.yellow;   accent = Theme.pink
        case "specter":     body = Theme.red;      accent = Theme.cyan
        case "singularity": body = Theme.violet;   accent = Theme.yellow
        default:            body = Theme.cyan;     accent = Theme.pink   // viper baseline
        }
        // Each ship overrides exactly the field its description promises;
        // everything else stays at the neutral default for clarity.
        switch id {
        case "magenta":      return .init(id: id, body: body, accent: accent, glideMul: 1.5)
        case "argon":        return .init(id: id, body: body, accent: accent, comboDecayMul: 1.1)
        case "twilight":     return .init(id: id, body: body, accent: accent, bulletHitRadius: 28)
        case "aurora":       return .init(id: id, body: body, accent: accent, flybyCoinMul: 1.2)
        case "nova":         return .init(id: id, body: body, accent: accent, bulletPierces: 1)
        case "cascade":      return .init(id: id, body: body, accent: accent, fireCooldownMul: 0.6)
        case "phantom":      return .init(id: id, body: body, accent: accent, letterMagnet: true)
        case "sentinel":     return .init(id: id, body: body, accent: accent, firstHitShield: true)
        case "bastion":      return .init(id: id, body: body, accent: accent, bunkerSizeMul: 1.5)
        case "eclipse":      return .init(id: id, body: body, accent: accent, bonusRaidSeconds: 10, bonusWordSeconds: 10)
        case "skyhawk":      return .init(id: id, body: body, accent: accent, bonusHoldLimit: 2)
        case "nebula":       return .init(id: id, body: body, accent: accent, bombSpeedMul: 0.7)
        case "pulsar":       return .init(id: id, body: body, accent: accent, wildSpawnMul: 2.0)
        case "specter":      return .init(id: id, body: body, accent: accent, rareBonusMul: 2.0)
        case "singularity":  return .init(id: id, body: body, accent: accent, wordScoreMul: 1.2)
        default:             return .init(id: id, body: body, accent: accent)
        }
    }
}

/// Persistent hangar state. Reads/writes the same UserDefaults keys the
/// SkinsScreen binds to via @AppStorage, so view bindings stay in sync with
/// non-view callers (the engine awarding coins, RootView looking up the
/// equipped loadout, etc.).
enum Hangar {
    static let coinKey = "coinBalance"
    static let ownedKey = "ownedShipIDsCSV"
    static let equippedKey = "equippedShipID"
    // UserDefaults keys for the persistent power-up stock. Names kept as
    // "bonusZapCharges"/"bonusWildCharges" for backward compatibility with
    // saves from the earlier bank model; existing values carry over and are
    // clamped to `maxChargeStock` on read/write.
    static let bonusZapKey = "bonusZapCharges"
    static let bonusWildKey = "bonusWildCharges"
    static let lifeKey = "lifeStock"
    /// Ships granted to a fresh save: the three "rarity ≤ rare" hangar starters.
    static let defaultOwned = "viper,magenta,argon"
    static let startingCoins = 2000
    /// Cost in coins to buy a single ZAP or WILD charge from the Hangar.
    static let chargePrice = 100
    /// Fresh-install default for each power-up type — first-time players
    /// have one of each available on their very first raid.
    static let startingCharges = 1
    /// Hard cap on stored ZAP/WILD charges.
    static let maxChargeStock = 20
    /// Hard cap on simultaneous lives. The player can never exceed this —
    /// earn and purchase paths both clamp here, so a 3-life player gets
    /// no benefit from extra grants.
    static let maxLives = 3
    /// Cost in coins to buy a single life from the Hangar.
    static let lifePrice = 500

    static var coins: Int {
        get { UserDefaults.standard.object(forKey: coinKey) as? Int ?? startingCoins }
        set { UserDefaults.standard.set(newValue, forKey: coinKey) }
    }

    static var equippedID: String {
        get { UserDefaults.standard.string(forKey: equippedKey) ?? "viper" }
        set { UserDefaults.standard.set(newValue, forKey: equippedKey) }
    }

    static var ownedIDs: Set<String> {
        get {
            let csv = UserDefaults.standard.string(forKey: ownedKey) ?? defaultOwned
            return Set(csv.split(separator: ",").map(String.init))
        }
        set {
            let csv = newValue.sorted().joined(separator: ",")
            UserDefaults.standard.set(csv, forKey: ownedKey)
        }
    }

    static func awardCoins(_ amount: Int) {
        guard amount > 0 else { return }
        coins = coins + amount
    }

    static func currentLoadout() -> ShipLoadout {
        ShipLoadout.forID(equippedID)
    }

    // MARK: - Power-up stock (persistent, capped)
    //
    // Single persistent pool per power-up type. Everything earned (per-raid
    // base grant, raid-cleared bonus, long-word bonus) and purchased ends
    // up here. Engine reads it at raid start AND writes through on each
    // use, so a pause-quit or app force-close never costs the player a
    // charge they've earned.
    //
    // Charges cap at `maxChargeStock`. Fresh installs default to
    // `startingCharges` so first-time play has a usable kit.

    static var zapStock: Int {
        get {
            if UserDefaults.standard.object(forKey: bonusZapKey) == nil {
                return startingCharges
            }
            let stored = UserDefaults.standard.integer(forKey: bonusZapKey)
            let clamped = min(max(0, stored), maxChargeStock)
            if stored != clamped {
                UserDefaults.standard.set(clamped, forKey: bonusZapKey)
            }
            return clamped
        }
        set { UserDefaults.standard.set(min(max(0, newValue), maxChargeStock), forKey: bonusZapKey) }
    }

    static var wildStock: Int {
        get {
            if UserDefaults.standard.object(forKey: bonusWildKey) == nil {
                return startingCharges
            }
            let stored = UserDefaults.standard.integer(forKey: bonusWildKey)
            let clamped = min(max(0, stored), maxChargeStock)
            if stored != clamped {
                UserDefaults.standard.set(clamped, forKey: bonusWildKey)
            }
            return clamped
        }
        set { UserDefaults.standard.set(min(max(0, newValue), maxChargeStock), forKey: bonusWildKey) }
    }

    /// Spend `chargePrice` coins for +1 ZAP in the persistent stock.
    /// Returns false (changes nothing) when the player can't afford it or
    /// the stock is already capped.
    @discardableResult
    static func buyZap() -> Bool {
        guard coins >= chargePrice, zapStock < maxChargeStock else { return false }
        coins -= chargePrice
        zapStock += 1
        return true
    }

    @discardableResult
    static func buyWild() -> Bool {
        guard coins >= chargePrice, wildStock < maxChargeStock else { return false }
        coins -= chargePrice
        wildStock += 1
        return true
    }

    /// Grant power-up rewards (raid-clear base, raid-3 ZAP bonus, 7+ word
    /// WILD bonus). Just bumps the persistent capped stock.
    static func grantZap(_ amount: Int = 1) {
        guard amount > 0 else { return }
        zapStock += amount
    }

    static func grantWild(_ amount: Int = 1) {
        guard amount > 0 else { return }
        wildStock += amount
    }

    // MARK: - Lives (persistent, hard-capped at maxLives)
    //
    // Single persistent counter, 0...maxLives. Engine reads this at raid
    // start and RootView writes the engine's final livesRemaining back at
    // raid end (endless runs only — daily puzzles override via their
    // own modifier and never touch the stock). Earn paths and the 500-coin
    // purchase both clamp to `maxLives`, so the player never holds more
    // than 3 lives at once.

    static var lifeStock: Int {
        get {
            if UserDefaults.standard.object(forKey: lifeKey) == nil {
                return maxLives
            }
            return UserDefaults.standard.integer(forKey: lifeKey)
        }
        set {
            let clamped = max(0, min(maxLives, newValue))
            UserDefaults.standard.set(clamped, forKey: lifeKey)
        }
    }

    /// Bump life stock by `amount`, clamped to `maxLives`. Returns true if
    /// at least one life was actually added (so callers can fire a
    /// celebratory haptic only when the player wasn't already capped).
    @discardableResult
    static func grantLife(_ amount: Int = 1) -> Bool {
        guard amount > 0 else { return false }
        let before = lifeStock
        lifeStock = before + amount
        return lifeStock > before
    }

    /// Spend `lifePrice` coins for +1 life. Returns false (changes nothing)
    /// when the player can't afford it OR is already at the cap.
    @discardableResult
    static func buyLife() -> Bool {
        guard coins >= lifePrice, lifeStock < maxLives else { return false }
        coins -= lifePrice
        lifeStock += 1
        return true
    }
}
