import Foundation

/// XP → rank ladder for the player progression system.
///
/// 20 ranks with a "steady" curve: each level-up costs ~1.5× the previous
/// level. Casual players reach the mid teens in a few weeks; rank 20 is a
/// long-tail prestige goal. Ranks carry a callsign for flavor and gate a
/// couple of mechanical rewards (Nova @ 20, daily coin multiplier, coin
/// bonus on rank-up).
enum RankSystem {
    static let names: [String] = [
        "Recruit",        // 1
        "Cadet",          // 2
        "Ensign",         // 3
        "Petty Officer",  // 4
        "Lieutenant",     // 5
        "Lt. Commander",  // 6
        "Commander",      // 7
        "Captain",        // 8
        "Major",          // 9
        "Lt. Colonel",    // 10
        "Colonel",        // 11
        "Brigadier",      // 12
        "General",        // 13
        "Fleet Commander",// 14
        "Commodore",      // 15
        "Rear Admiral",   // 16
        "Vice Admiral",   // 17
        "Admiral",        // 18
        "Fleet Admiral",  // 19
        "Grand Admiral",  // 20
    ]
    static let maxRank = names.count

    /// Cumulative XP needed to first reach each rank. `xpThresholds[0]` is 0
    /// (rank 1 baseline); `xpThresholds[i]` is the XP needed to reach rank i+1.
    ///
    /// Curve: 250 XP for rank 2, growing at ×1.35 per level. Earlier (50 / ×1.5)
    /// let players blow through ranks 1–5 in a single run. The flatter
    /// multiplier slows early ranks substantially while keeping rank 20
    /// (~213k XP) at roughly the same long-tail goal as before.
    static let xpThresholds: [Int] = {
        var thresholds: [Int] = [0]
        var cost: Double = 250
        for _ in 1..<maxRank {
            thresholds.append(thresholds.last! + Int(cost.rounded()))
            cost *= 1.35
        }
        return thresholds
    }()

    /// Highest rank whose threshold is <= `xp`. Always ≥ 1, never above
    /// `maxRank`.
    static func rank(forXP xp: Int) -> Int {
        var lo = 1
        var hi = maxRank
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if xpThresholds[mid - 1] <= xp {
                lo = mid
            } else {
                hi = mid - 1
            }
        }
        return lo
    }

    static func title(forRank rank: Int) -> String {
        let i = max(1, min(maxRank, rank)) - 1
        return names[i]
    }

    /// XP at the start of the given rank (when the player first earned it).
    static func xpForRank(_ rank: Int) -> Int {
        let i = max(1, min(maxRank, rank)) - 1
        return xpThresholds[i]
    }

    /// XP needed to reach the rank above `current`. Nil when already at max.
    static func xpForNext(after current: Int) -> Int? {
        guard current < maxRank else { return nil }
        return xpThresholds[current]   // index `current` (0-indexed) = next rank's threshold
    }

    /// Daily coin reward multiplier from rank: +5% per 5 ranks earned.
    /// Rank 1–5 = 1.00, 6–10 = 1.05, 11–15 = 1.10, 16–20 = 1.15.
    static func dailyRewardMultiplier(forRank rank: Int) -> Double {
        1.0 + Double((max(1, rank) - 1) / 5) * 0.05
    }
}

/// Persistent player progression — XP, rank, level-up side-effects.
/// Backed by UserDefaults so it survives launches and stays in sync with
/// @AppStorage bindings in the UI (title pill, settings, game over).
enum PlayerProfile {
    static let xpKey = "playerXP"
    /// UserDefaults key for the player's display nickname. Default value
    /// "Cmdr Nyx" matches the legacy hardcoded label so existing users see
    /// no change until they explicitly rename themselves in Settings.
    static let nicknameKey = "playerNickname"
    static let defaultNickname = "Cmdr Nyx"
    /// Hard upper bound on nickname length. Just enough to keep the avatar
    /// pill from blowing out on small screens.
    static let nicknameMaxLength = 16

    static var nickname: String {
        get {
            let value = UserDefaults.standard.string(forKey: nicknameKey) ?? defaultNickname
            return value.isEmpty ? defaultNickname : value
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let capped = String(trimmed.prefix(nicknameMaxLength))
            UserDefaults.standard.set(capped.isEmpty ? defaultNickname : capped, forKey: nicknameKey)
        }
    }

    /// Two-character monogram for the avatar pill. Falls back to first two
    /// letters of the default nickname when nothing typeable is found.
    static var nicknameInitials: String {
        let parts = nickname.split(separator: " ")
        if let first = parts.first, let initial = first.first {
            if parts.count > 1, let second = parts.last, let secondInitial = second.first {
                return String(initial).uppercased() + String(secondInitial).uppercased()
            }
            return String(initial).uppercased() + (first.count > 1 ? String(first.dropFirst().first!).uppercased() : "")
        }
        return "NK"
    }

    static var xp: Int {
        get { UserDefaults.standard.integer(forKey: xpKey) }
        set { UserDefaults.standard.set(max(0, newValue), forKey: xpKey) }
    }

    static var rank: Int { RankSystem.rank(forXP: xp) }
    static var rankTitle: String { RankSystem.title(forRank: rank) }

    /// XP earned inside the current rank band (0…(nextThreshold - thisThreshold)).
    static var xpInCurrentRank: Int { xp - RankSystem.xpForRank(rank) }

    /// XP needed to reach the next rank. 0 when at maxRank.
    static var xpToNextRank: Int {
        guard let next = RankSystem.xpForNext(after: rank) else { return 0 }
        return max(0, next - xp)
    }

    /// Award XP and run rank-up side-effects (coin bonus + haptic-ready
    /// signal via the return value). Returns the new rank if the player
    /// leveled up this call, nil otherwise. Multi-level jumps in one award
    /// are possible (e.g., end-of-run new-high) — the caller still gets a
    /// single non-nil result for the new rank.
    @discardableResult
    static func awardXP(_ amount: Int) -> Int? {
        guard amount > 0 else { return nil }
        let oldRank = rank
        xp = xp + amount
        let newRank = rank
        guard newRank > oldRank else { return nil }
        // Rank-up coin bonus: 100 × new rank. Compounds for back-to-back
        // levels in a single award (we only award for the final new rank
        // to keep payouts predictable).
        Hangar.awardCoins(100 * newRank)
        // Note: rank-up life grants are NOT awarded here. Mid-raid rank-ups
        // (from per-letter +1 XP) would race with the engine's lives counter
        // — it overwrites Hangar.lifeStock at raid end and the grant would
        // be lost. Life grants live at safe callsites (between raids in
        // RunState.advanceAfterWord and the daily-clear path in
        // RootView.endRun).
        return newRank
    }
}
