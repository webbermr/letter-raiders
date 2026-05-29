import SwiftUI

/// Reference manual screen — explains rules, scoring, power-ups, daily
/// puzzles, and hangar progression. Reached from the (?) icon on the
/// title screen. Third-party credits + copyright live in Settings →
/// About → Credits.
struct HelpScreen: View {
    var onBack: () -> Void = {}

    var body: some View {
        PhoneShell {
            VStack(spacing: 0) {
                PageHeader(title: "Help", onBack: onBack)
                    .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        intro
                        section("Phase 1 · The Raid") {
                            bullet("Drag anywhere", "Your ship glides toward your finger.")
                            bullet("Tap to fire", "Each tap launches a bullet straight up.")
                            bullet("Capture letters", "Hit a falling tile to add it to your letters.")
                            bullet("Avoid bombs", "Red bombs drop from invaders — one hit costs a life.")
                            bullet("Use bunkers", "The green walls absorb hits but erode over time.")
                            bullet("End conditions", "Raid ends when the timer runs out, all lives are lost, or your letters fill up.")
                        }
                        section("Phase 2 · Build a Word") {
                            bullet("Spend your letters", "Tap letters to add them to the word slot. Tap a placed tile to remove it.")
                            bullet("Submit a valid word", "Words must be in the dictionary and at least 2 letters long.")
                            bullet("Wildcards (★)", "Pick any letter when you place a wildcard. Costs no base points but enables shapes you couldn't otherwise spell.")
                            bullet("+30s extend", "Buys 30 more seconds but costs 50 points the first use, 150 the second. Only two extends per word phase.")
                            bullet("Carryover", "Unused letters carry into your next raid — pure gain.")
                        }
                        section("Scoring") {
                            bullet("Base value", "Sum of Scrabble letter values (Q/Z = 10, J/X = 8, common = 1).")
                            bullet("Length multiplier", "5 letters ×1.25 · 6 ×1.5 · 7 ×1.75 · 8+ ×2.0.")
                            bullet("Rare letter bonus", "+50 flat if the word contains a J, Q, X, or Z.")
                            bullet("Efficiency bonus", "+25% if you use 80%+ of your letters, +10% at 50%+.")
                            bullet("Speed multiplier", "Up to ×1.5 — submit faster for more points.")
                            bullet("Raid capture", "Your shoot-up score banks only when you submit a valid word.")
                            bullet("Combo (in-raid)", "Consecutive captures stack a combo that multiplies capture score; misses break it.")
                        }
                        section("Power-Ups") {
                            bullet("ZAP", "Instantly captures every letter on screen.")
                            bullet("WILD", "Arms your ship — the next captured letter becomes a wildcard ★.")
                            bullet("UFO ★", "A scrolling wildcard saucer — shoot it for a big score and a free wildcard tile (worth coins too).")
                            bullet("Yours to keep", "Charges persist across runs forever. Earned or purchased power-ups never expire, with ZAP and WILD capped at 20 each.")
                            bullet("Per-raid grant", "+1 ZAP and +1 WILD on every cleared raid.")
                            bullet("Bonus ZAP", "+1 ZAP every 3rd cleared raid (raids 3, 6, 9, …).")
                            bullet("Bonus WILD", "Clear a raid with a 7+ letter word → +1 WILD.")
                            bullet("Buy in Hangar", "100 coins per charge, any time.")
                        }
                        section("Daily Challenges") {
                            bullet("New puzzle every day", "Same puzzle for every player on a given day. Modifiers vary — see the daily screen for today's rules.")
                            bullet("One attempt per day", "Win or lose, the puzzle locks until tomorrow.")
                            bullet("Streak", "Submit a valid word to advance your streak. Missing a day resets it.")
                            bullet("Reward", "Each puzzle pays out a fixed coin bonus on success (in addition to the normal end-of-run share).")
                        }
                        section("Hangar · Ships") {
                            bullet("Equip a ship", "Each ship adds a small gameplay bonus — faster glide, wider bullet, longer combo grace, bonus UFO coins, bullet piercing.")
                            bullet("Unlock with coins", "Earn coins from captures, raid clears, UFO kills, and end-of-run score share. Rare ships cost more.")
                            bullet("Effect always on", "Your equipped ship's bonus applies to every run, daily included.")
                        }
                        section("Coins") {
                            bullet("+1", "per regular letter captured")
                            bullet("+25", "per UFO captured (×1.2 with Aurora ship)")
                            bullet("+50", "per raid cleared")
                            bullet("+5%", "of your final banked score at end of an endless run")
                            bullet("Daily reward", "Fixed bonus from each daily puzzle (400-800). Scales +5% per 5 ranks earned.")
                        }
                        section("Ranks & XP") {
                            bullet("20 ranks", "From Recruit to Grand Admiral. Each rank carries a callsign that shows on the title screen and game over.")
                            bullet("XP curve", "Steady ~1.5× growth per level. Early ranks pop fast; the late ranks are long-term goals.")
                            bullet("Earn XP", "+1 per letter captured · +10 per UFO · +25 per raid cleared · word length × 5 per valid word · +100 per daily completed · +200 per new personal best.")
                            bullet("Rank-up bonus", "Earn 100 × your new rank in coins each time you level up.")
                            bullet("Daily multiplier", "Higher ranks earn more coins from daily puzzles (+5% per 5 ranks).")
                            bullet("Nova Prime", "Legendary ship gated behind Rank 20 — buy the others with coins, earn Nova through play.")
                        }
                        // Credits + copyright moved to Settings → About →
                        // Credits so the Help view can stay focused on
                        // gameplay rules.
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Sections

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LETTER RAIDERS")
                .font(AppFont.display(28, weight: .bold))
                .kerning(-0.6)
                .foregroundStyle(LinearGradient(
                    colors: [Theme.cyanSoft, Theme.pinkSoft],
                    startPoint: .leading, endPoint: .trailing
                ))
            Text("Capture falling letters in a Space-Invaders-style raid, then spend them on the biggest word you can spell. Every run has two phases — a shooter, then a word puzzle — and your score depends on both.")
                .font(AppFont.mono(12, weight: .regular))
                .lineSpacing(3)
                .foregroundColor(Color.white.opacity(0.75))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(
                    colors: [Theme.violet.opacity(0.18), Theme.cyan.opacity(0.10)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1))
        )
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowText(text: title)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
        }
    }

    /// Bullet line: bold label + body. Renders to one row when short, wraps
    /// cleanly when the body is long.
    private func bullet(_ label: String, _ body: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle().fill(Theme.cyanSoft).frame(width: 5, height: 5)
                .shadow(color: Theme.cyanSoft, radius: 3)
                .offset(y: -2)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppFont.mono(12, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.white)
                Text(body)
                    .font(AppFont.mono(11.5, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // Credits + copyright moved to Settings → About → Credits.
}
