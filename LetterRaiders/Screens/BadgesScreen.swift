import SwiftUI

/// "Badges" tab — surfaces every achievement in the catalog, with unlock
/// state, a progress bar for multi-step achievements, and a header summary
/// (e.g. "5 / 15 UNLOCKED"). Replaces the old hardcoded Leaderboard view.
///
/// Local-only for now — once Game Center is wired up the unlock writes
/// will also call `GKAchievement` and the dashboard here stays the same.
struct BadgesScreen: View {
    var onBack: () -> Void = {}

    /// Live bindings to the underlying stat keys so the screen redraws as
    /// the player earns progress in real time (e.g. opening the screen
    /// right after a run sees the new values).
    @AppStorage(PlayerProfile.xpKey) private var playerXP: Int = 0
    @AppStorage(Hangar.bonusZapKey) private var zapStock: Int = Hangar.startingCharges
    @AppStorage(Hangar.bonusWildKey) private var wildStock: Int = Hangar.startingCharges
    @AppStorage(Hangar.ownedKey) private var ownedCSV: String = Hangar.defaultOwned

    private var unlockedCount: Int { AchievementCatalog.unlockedCount }
    private var total: Int { AchievementCatalog.all.count }

    var body: some View {
        PhoneShell {
            VStack(spacing: 0) {
                PageHeader(title: "Badges", onBack: onBack) {
                    progressChip
                }
                .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(AchievementCatalog.all) { a in
                            badgeRow(a)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    /// "5 / 15" pill in the page header.
    private var progressChip: some View {
        Text("\(unlockedCount) / \(total)")
            .font(AppFont.mono(11, weight: .bold))
            .tracking(1.6)
            .foregroundColor(Theme.yellow)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Theme.yellow.opacity(0.12))
                    .overlay(Capsule().stroke(Theme.yellow.opacity(0.35), lineWidth: 1))
            )
    }

    /// One row per achievement. Locked badges are desaturated; unlocked
    /// ones use their accent color + a checkmark. Multi-step badges
    /// surface a thin progress bar with `current / target` underneath.
    private func badgeRow(_ a: AchievementInfo) -> some View {
        let unlocked = a.isUnlocked
        let tint = unlocked ? a.accent : Color.white.opacity(0.35)
        return HStack(alignment: .top, spacing: 14) {
            // Icon "coin"
            ZStack {
                Circle()
                    .fill(unlocked
                          ? AnyShapeStyle(LinearGradient(colors: [a.accent.opacity(0.45), a.accent.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing))
                          : AnyShapeStyle(Color.white.opacity(0.06)))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle().stroke(unlocked ? a.accent.opacity(0.55) : Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: unlocked ? a.accent.opacity(0.45) : .clear, radius: 12)
                Image(systemName: a.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(unlocked ? a.accent : Color.white.opacity(0.35))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(a.name)
                        .font(AppFont.display(15, weight: .bold))
                        .foregroundColor(unlocked ? .white : Color.white.opacity(0.7))
                    Spacer()
                    if unlocked {
                        // Unlocked check pill — visual confirmation that
                        // outranks the progress bar (which is hidden once
                        // a target is reached).
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                            Text("UNLOCKED")
                                .font(AppFont.mono(9, weight: .bold))
                                .tracking(1.6)
                        }
                        .foregroundColor(Theme.void)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(LinearGradient(colors: [a.accent, a.accent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .shadow(color: a.accent.opacity(0.5), radius: 8)
                        )
                    }
                }
                Text(a.summary)
                    .font(AppFont.mono(11, weight: .regular))
                    .foregroundColor(Color.white.opacity(unlocked ? 0.65 : 0.5))
                    .fixedSize(horizontal: false, vertical: true)

                // Progress meter — only for multi-step badges, and only
                // while still locked (a full bar after unlock is redundant
                // with the UNLOCKED pill).
                if a.hasProgressBar && !unlocked {
                    progressMeter(a, tint: tint)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(unlocked ? 0.06 : 0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(unlocked ? a.accent.opacity(0.30) : Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        // Re-evaluate the row when any backing store changes so progress
        // reflects live state without an explicit refresh.
        .id(rowIdentity(a))
    }

    private func progressMeter(_ a: AchievementInfo, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Capsule()
                .fill(Color.white.opacity(0.08))
                .frame(height: 6)
                .overlay(
                    GeometryReader { g in
                        Capsule()
                            .fill(LinearGradient(colors: [tint, tint.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: g.size.width * a.progress)
                            .shadow(color: tint.opacity(0.5), radius: 4)
                    }
                )
            Text("\(a.current) / \(a.target)")
                .font(AppFont.mono(9.5, weight: .regular))
                .tracking(1.4)
                .foregroundColor(Color.white.opacity(0.5))
        }
        .padding(.top, 4)
    }

    /// SwiftUI sometimes caches rows aggressively when only the underlying
    /// closure return value changes. Mixing the dynamic state into the row
    /// identity guarantees a redraw when stats tick over.
    private func rowIdentity(_ a: AchievementInfo) -> String {
        "\(a.id.rawValue)#\(playerXP)#\(zapStock)#\(wildStock)#\(ownedCSV)#\(a.current)"
    }
}

#Preview {
    BadgesScreen().preferredColorScheme(.dark)
}
