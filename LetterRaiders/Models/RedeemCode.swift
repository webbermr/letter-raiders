import Foundation

/// Custom in-app coin codes. Apple's offer codes only redeem against
/// auto-renewable subscriptions, so coin grants for our consumable economy
/// are handled entirely client-side: a fixed code table redeemed straight
/// into the Hangar balance, with each code consumable once per device.
enum RedeemCode {
    /// Codes already redeemed on this device, so a code can't pay out twice.
    static let redeemedKey = "redeemedCoinCodes"

    /// Code → coin grant. Codes are matched trimmed + uppercased, so store
    /// the keys uppercased here.
    static let table: [String: Int] = [
        "LAUNCH": 1_000,
        "RAIDER": 2_500,
        "NEONDROP": 5_000,
    ]

    enum Outcome {
        case success(coins: Int)
        case invalid
        case alreadyRedeemed
    }

    static var redeemedCodes: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: redeemedKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: redeemedKey) }
    }

    static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    @discardableResult
    static func redeem(_ raw: String) -> Outcome {
        let code = normalize(raw)
        guard !code.isEmpty, let coins = table[code] else { return .invalid }
        var redeemed = redeemedCodes
        guard !redeemed.contains(code) else { return .alreadyRedeemed }
        Hangar.awardCoins(coins)
        redeemed.insert(code)
        redeemedCodes = redeemed
        return .success(coins: coins)
    }
}
