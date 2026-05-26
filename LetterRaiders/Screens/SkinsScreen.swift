import SwiftUI

struct ShipSkin: Identifiable, Equatable {
    let id: String
    let name: String
    let rarity: Rarity
    let body: Color
    let accent: Color
    let cost: Int
    let desc: String
    /// Player rank required before the ship can be unlocked. 0 = no gate.
    /// Rank-gated ships with `cost == 0` auto-unlock at the threshold; ships
    /// with both a rank requirement AND a cost (Nova) need both met.
    var requiredRank: Int = 0

    enum Rarity: String {
        case common, rare, epic, legendary
        var color: Color {
            switch self {
            case .common: return Theme.cyanSoft
            case .rare: return Theme.violet
            case .epic: return Theme.pinkSoft
            case .legendary: return Theme.yellow
            }
        }
        var label: String { rawValue.uppercased() }
    }

    /// Catalog of ships. Ownership and equipped state live in `Hangar` (and
    /// are surfaced via @AppStorage in SkinsScreen), not on this struct.
    static let all: [ShipSkin] = [
        // ── Starter loadout (free) ────────────────────────────────────────
        .init(id: "viper",    name: "Viper Mk II",   rarity: .common, body: Theme.cyan,     accent: Theme.pink,   cost: 0,    desc: "Standard issue. Quick and forgiving."),
        .init(id: "magenta",  name: "Magenta Drift", rarity: .common, body: Theme.pinkSoft, accent: Theme.yellow, cost: 0,    desc: "Pink chassis · faster glide."),
        .init(id: "argon",    name: "Argon",         rarity: .rare,   body: Theme.green,    accent: Theme.cyan,   cost: 0,    desc: "+10% combo decay grace."),

        // ── Coin-priced ships, ascending cost ────────────────────────────
        .init(id: "twilight", name: "Twilight",   rarity: .rare,      body: Theme.violet,   accent: Theme.pink,     cost: 1200,  desc: "Wider bullet pickup arc."),
        .init(id: "aurora",   name: "Aurora",     rarity: .epic,      body: Theme.yellow,   accent: Theme.amber,    cost: 2500,  desc: "Coins +20% on UFO kills."),
        .init(id: "cascade",  name: "Cascade",    rarity: .epic,      body: Theme.cyan,     accent: Theme.amber,    cost: 3500,  desc: "Rapid fire — 40% shorter cooldown between shots."),
        .init(id: "phantom",  name: "Phantom",    rarity: .epic,      body: Theme.violet,   accent: Theme.cyanSoft, cost: 5000,  desc: "Letter magnet — letters passing your ship are auto-captured."),
        .init(id: "sentinel", name: "Sentinel",   rarity: .epic,      body: Theme.green,    accent: Theme.pinkSoft, cost: 10000, desc: "Shield — absorbs the first hit each raid."),
        .init(id: "bastion",  name: "Bastion",    rarity: .legendary, body: Theme.amber,    accent: Theme.green,    cost: 25000, desc: "Reinforced bunkers — 50% more cells per bunker."),
        .init(id: "eclipse",  name: "Eclipse",    rarity: .legendary, body: Theme.violet,   accent: Theme.cyan,     cost: 50000, desc: "Time bender — +10s raid time and +10s word phase."),

        // ── Rank-gated ships (free once unlocked by rank) ────────────────
        .init(id: "skyhawk",     name: "Skyhawk",     rarity: .rare,      body: Theme.cyanSoft, accent: Theme.violet,  cost: 0, desc: "Expanded rack — hold 2 extra letters per raid.",       requiredRank: 3),
        .init(id: "nebula",      name: "Nebula",      rarity: .epic,      body: Theme.pinkSoft, accent: Theme.amber,   cost: 0, desc: "Slow bombs — incoming enemy bombs fall 30% slower.",   requiredRank: 7),
        .init(id: "pulsar",      name: "Pulsar",      rarity: .epic,      body: Theme.yellow,   accent: Theme.pink,    cost: 0, desc: "Wild storm — wildcard ★ tiles spawn 2× more often.",  requiredRank: 11),
        .init(id: "specter",     name: "Specter",     rarity: .legendary, body: Theme.red,      accent: Theme.cyan,    cost: 0, desc: "Double rare — the rare-letter bonus is doubled (+100).", requiredRank: 15),
        .init(id: "singularity", name: "Singularity", rarity: .legendary, body: Theme.violet,   accent: Theme.yellow,  cost: 0, desc: "All word scores ×1.2.",                                requiredRank: 18),

        // ── Cost + rank: the apex ship ───────────────────────────────────
        .init(id: "nova",     name: "Nova Prime",   rarity: .legendary, body: Theme.red,      accent: Theme.yellow, cost: 4800, desc: "Bullets pierce one extra invader.", requiredRank: 20),
    ]
}

struct SkinsScreen: View {
    var onBack: () -> Void = {}

    @AppStorage(Hangar.equippedKey) private var equippedID: String = "viper"
    @AppStorage(Hangar.ownedKey) private var ownedCSV: String = Hangar.defaultOwned
    @AppStorage(Hangar.coinKey) private var coins: Int = Hangar.startingCoins
    @AppStorage(Hangar.bonusZapKey) private var zapStock: Int = Hangar.startingCharges
    @AppStorage(Hangar.bonusWildKey) private var wildStock: Int = Hangar.startingCharges
    @AppStorage(PlayerProfile.xpKey) private var playerXP: Int = 0

    private var playerRank: Int { RankSystem.rank(forXP: playerXP) }

    /// Local in-screen selection (which card is featured in the hero). Starts
    /// on the currently equipped ship so the screen opens to the player's
    /// active loadout.
    @State private var selected: String

    init(onBack: @escaping () -> Void = {}) {
        self.onBack = onBack
        _selected = State(initialValue: UserDefaults.standard.string(forKey: Hangar.equippedKey) ?? "viper")
    }

    private var ownedSet: Set<String> {
        Set(ownedCSV.split(separator: ",").map(String.init))
    }

    /// True when the player's rank doesn't yet meet the ship's requirement.
    /// Drives the "REACH RANK N" disabled CTA + the lock icon on grid cells.
    private func isRankLocked(_ s: ShipSkin) -> Bool {
        s.requiredRank > 0 && playerRank < s.requiredRank
    }

    /// Ownership read-through. A rank-gated ship with zero cost is
    /// automatically considered owned once the player meets the rank — no
    /// extra unlock click required. Ships with a cost (Twilight, Aurora,
    /// Cascade-Eclipse, Nova) still need an explicit purchase.
    private func isOwned(_ id: String) -> Bool {
        if ownedSet.contains(id) { return true }
        guard let s = ShipSkin.all.first(where: { $0.id == id }) else { return false }
        if s.cost == 0 && s.requiredRank > 0 && playerRank >= s.requiredRank {
            return true
        }
        return false
    }

    private func isEquipped(_ id: String) -> Bool { equippedID == id }

    private var ship: ShipSkin {
        ShipSkin.all.first { $0.id == selected } ?? ShipSkin.all[0]
    }

    var body: some View {
        PhoneShell {
            VStack(spacing: 0) {
                PageHeader(title: "Hangar", onBack: onBack) {
                    HStack(spacing: 6) {
                        Circle().fill(Theme.yellow).frame(width: 12, height: 12)
                        Text("\(coins)")
                            .font(AppFont.mono(12, weight: .bold))
                            .foregroundColor(Theme.yellow)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Theme.yellow.opacity(0.12))
                            .overlay(Capsule().stroke(Theme.yellow.opacity(0.3), lineWidth: 1))
                    )
                }
                .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        featured.padding(.horizontal, 20)

                        ctaButton.padding(.horizontal, 20).padding(.top, 14)

                        gridSection.padding(.horizontal, 20).padding(.top, 18)

                        powerupsSection.padding(.horizontal, 20).padding(.top, 18)

                        Spacer().frame(height: 40)
                    }
                }
            }
        }
    }

    private var featured: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [ship.body.opacity(0.33), .clear]),
                        center: .init(x: 0.5, y: 0.6), startRadius: 0, endRadius: 220
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.04), Color.white.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                )
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(ship.body.opacity(0.2), lineWidth: 1))
                .frame(height: 260)

            VStack {
                HStack {
                    Text(ship.rarity.label)
                        .font(AppFont.mono(9, weight: .bold))
                        .tracking(2)
                        .foregroundColor(ship.rarity.color)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(
                            Capsule().fill(ship.rarity.color.opacity(0.13))
                                .overlay(Capsule().stroke(ship.rarity.color.opacity(0.4), lineWidth: 1))
                        )
                    Spacer()
                    if isEquipped(ship.id) {
                        Text("EQUIPPED")
                            .font(AppFont.mono(9, weight: .bold))
                            .tracking(2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(
                                Capsule().fill(LinearGradient(colors: [Theme.pink, Theme.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .shadow(color: Theme.pink.opacity(0.5), radius: 12)
                            )
                    }
                }
                Spacer()
                Ship(size: 64, color: ship.body, accent: ship.accent)
                    .scaleEffect(2.6)
                    .shadow(color: ship.body.opacity(0.7), radius: 32)
                Spacer()
                VStack(alignment: .leading, spacing: 3) {
                    Text(ship.name).font(AppFont.display(22, weight: .bold))
                    Text(ship.desc).font(AppFont.display(12, weight: .regular)).foregroundColor(Color.white.opacity(0.65))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(height: 260)
        }
    }

    @ViewBuilder
    private var ctaButton: some View {
        if isOwned(ship.id) {
            if isEquipped(ship.id) {
                GhostButton(title: "EQUIPPED") {}
                    .opacity(0.7)
                    .disabled(true)
            } else {
                PrimaryButton(title: "EQUIP \(ship.name.split(separator: " ").first?.uppercased() ?? "")", fontSize: 15) {
                    equipShip(ship.id)
                }
            }
        } else if isRankLocked(ship) {
            GhostButton(title: "REACH RANK \(ship.requiredRank)", icon: "lock.fill") {}
                .opacity(0.5)
                .disabled(true)
        } else {
            // Show as disabled when the player can't afford it — still labelled
            // with the cost so they know what they're saving toward.
            let canAfford = coins >= ship.cost
            PrimaryButton(title: "UNLOCK · \(ship.cost)", fontSize: 15) {
                if canAfford { unlockShip(ship.id, cost: ship.cost) }
            }
            .opacity(canAfford ? 1 : 0.45)
            .disabled(!canAfford)
        }
    }

    private var gridSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowText(text: "Collection · \(ShipSkin.all.filter { isOwned($0.id) }.count) / \(ShipSkin.all.count)")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(ShipSkin.all) { s in
                    Button {
                        selected = s.id
                    } label: {
                        gridCell(s)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func gridCell(_ s: ShipSkin) -> some View {
        let on = s.id == selected
        let owned = isOwned(s.id)
        let equipped = isEquipped(s.id)
        return ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(on
                      ? AnyShapeStyle(LinearGradient(colors: [s.body.opacity(0.2), s.body.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing))
                      : AnyShapeStyle(Color.white.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(on ? s.body.opacity(0.55) : Color.white.opacity(0.08), lineWidth: 1))
                .shadow(color: on ? s.body.opacity(0.4) : .clear, radius: 14)

            VStack {
                HStack {
                    Circle().fill(s.rarity.color).frame(width: 6, height: 6)
                        .shadow(color: s.rarity.color, radius: 4)
                    Spacer()
                    if equipped {
                        Circle()
                            .fill(LinearGradient(colors: [Theme.pink, Theme.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 14, height: 14)
                            .overlay(Image(systemName: "checkmark").font(.system(size: 7, weight: .bold)).foregroundColor(.white))
                    }
                }
                Spacer()
                if isRankLocked(s) && !owned {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.white.opacity(0.5))
                } else {
                    Ship(size: 42, color: s.body, accent: s.accent)
                        .opacity(owned ? 1 : 0.55)
                        .saturation(owned ? 1 : 0.4)
                }
                Spacer()
            }
            .padding(6)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Mutations

    /// "POWER-UPS" buy section — purchase ZAP or WILD charges with coins.
    /// Charges live in a single persistent pool (`Hangar.zapStock` /
    /// `Hangar.wildStock`) — no cap, no draining on use. Anything earned
    /// or bought belongs to the player permanently.
    private var powerupsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowText(text: "Power-Ups · \(Hangar.chargePrice) coins each")
            HStack(spacing: 10) {
                buyTile(
                    label: "ZAP",
                    icon: "bolt.fill",
                    color: Theme.yellow,
                    owned: zapStock
                ) {
                    if Hangar.buyZap() { Haptics.notify(.success) }
                    else { Haptics.notify(.warning) }
                }
                buyTile(
                    label: "WILD",
                    icon: "star.fill",
                    color: Theme.pinkSoft,
                    owned: wildStock
                ) {
                    if Hangar.buyWild() { Haptics.notify(.success) }
                    else { Haptics.notify(.warning) }
                }
            }
            Text("Charges persist across runs. Earn more by clearing raids (+1 of each per clear), every 3rd raid (+1 ZAP), and 7+ letter words (+1 WILD).")
                .font(AppFont.mono(10, weight: .regular))
                .foregroundColor(Color.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// One tile in the Power-Ups buy grid. Greys out only when the player
    /// can't afford it — no stock cap to gate against any more.
    private func buyTile(label: String,
                         icon: String,
                         color: Color,
                         owned: Int,
                         action: @escaping () -> Void) -> some View {
        let canAfford = coins >= Hangar.chargePrice
        let disabled = !canAfford
        return Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.18))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(color)
                        .shadow(color: color.opacity(0.5), radius: 6)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(AppFont.display(14, weight: .semibold))
                        .foregroundColor(.white)
                    Text("OWNED \(owned)")
                        .font(AppFont.mono(10, weight: .regular))
                        .tracking(1.6)
                        .foregroundColor(Color.white.opacity(0.55))
                }
                Spacer(minLength: 4)
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(disabled ? Color.white.opacity(0.3) : color)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(disabled ? Color.white.opacity(0.08) : color.opacity(0.4), lineWidth: 1))
            )
            .opacity(disabled ? 0.55 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func equipShip(_ id: String) {
        guard isOwned(id) else { return }
        GameAudio.shared.play("ui_back")
        Haptics.impact(.medium)
        equippedID = id
    }

    private func unlockShip(_ id: String, cost: Int) {
        guard coins >= cost, !isOwned(id) else { return }
        GameAudio.shared.play("ui_back")
        // Bigger purchase = celebratory success notification.
        Haptics.notify(.success)
        coins -= cost
        var owned = ownedSet
        owned.insert(id)
        ownedCSV = owned.sorted().joined(separator: ",")
        // Auto-equip newly unlocked ships — players almost always want to try
        // the thing they just bought.
        equippedID = id
        selected = id
    }
}
