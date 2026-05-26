import SwiftUI

/// First-launch onboarding. 5 steps:
///   1. Welcome + nickname capture (commits to PlayerProfile.nickname)
///   2. Mission — the two-phase loop (shoot then spell)
///   3. Controls — drag to move, tap to fire
///   4. Word phase — scoring rules + power-ups (ZAP / WILD)
///   5. Progression — daily challenges, hangar ships, ranks & badges
///
/// Routed via RootView.onboarding(step:); the threshold for the final
/// DEPLOY action is set there based on the highest step here.
struct OnboardingScreen: View {
    static let totalSteps = 5

    var step: Int = 1
    var onNext: () -> Void = {}
    var onSkip: () -> Void = {}

    /// Local draft of the player's chosen nickname. Saved to
    /// PlayerProfile on advancing past step 1. Default value matches the
    /// app-wide fallback so a player who never types still gets a
    /// reasonable callsign.
    @State private var nicknameDraft: String = ""
    @FocusState private var nicknameFocused: Bool

    var body: some View {
        PhoneShell {
            VStack(spacing: 0) {
                topBar
                stepContent
                Spacer()
                bottomBar
            }
        }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                Haptics.select()
                onSkip()
            } label: {
                Text("SKIP")
                    .font(AppFont.mono(11, weight: .regular))
                    .tracking(2.4)
                    .foregroundColor(Color.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
        }
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 1: stepNickname
        case 2: stepMission
        case 3: stepControls
        case 4: stepWord
        case 5: stepProgression
        default: stepMission
        }
    }

    // MARK: - Step 1 · Welcome + nickname

    private var stepNickname: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                EyebrowText(text: "Step · 01")
                Text("Welcome, raider.")
                    .font(AppFont.display(30, weight: .bold))
                    .kerning(-0.9)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                Text("Pick a callsign. You can change it any time in Settings.")
                    .font(AppFont.mono(13, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.white.opacity(0.65))
                    .padding(.horizontal, 32)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("CALLSIGN")
                    .font(AppFont.mono(10, weight: .bold))
                    .tracking(2.4)
                    .foregroundColor(Theme.cyanSoft)
                TextField("Cmdr Nyx", text: $nicknameDraft)
                    .font(AppFont.display(20, weight: .bold))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                    .submitLabel(.next)
                    .focused($nicknameFocused)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cyan.opacity(0.4), lineWidth: 1))
                    )
                    .onSubmit { advanceFromNickname() }
                Text("Up to \(PlayerProfile.nicknameMaxLength) characters.")
                    .font(AppFont.mono(10, weight: .regular))
                    .tracking(1.4)
                    .foregroundColor(Color.white.opacity(0.45))
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            // Pre-fill with whatever is currently stored so a player who
            // backs out of onboarding mid-flow doesn't lose what they typed.
            if nicknameDraft.isEmpty { nicknameDraft = PlayerProfile.nickname }
            nicknameFocused = true
        }
    }

    // MARK: - Step 2 · Mission

    private var stepMission: some View {
        VStack(spacing: 36) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        gradient: Gradient(colors: [Theme.pink, Theme.violet, .clear]),
                        center: .init(x: 0.3, y: 0.3), startRadius: 5, endRadius: 130
                    ))
                    .frame(width: 200, height: 200)
                    .shadow(color: Theme.pink.opacity(0.45), radius: 38)
                LetterTile(letter: "★", tier: 5, size: 120, wild: true)
            }
            VStack(spacing: 10) {
                EyebrowText(text: "Step · 02 · Mission")
                Text("Shoot letters.\nSpell to score.")
                    .font(AppFont.display(30, weight: .bold))
                    .kerning(-0.9)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                Text("Phase 1: capture falling tiles — rare letters fall faster. Phase 2: spend them on the biggest word you can spell.")
                    .font(AppFont.display(15, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.white.opacity(0.65))
                    .padding(.horizontal, 32)
            }
        }
    }

    // MARK: - Step 3 · Controls

    private var stepControls: some View {
        VStack(spacing: 30) {
            VStack(spacing: 10) {
                EyebrowText(text: "Step · 03 · Controls")
                Text("Drag to move.\nTap to capture.")
                    .font(AppFont.display(30, weight: .bold))
                    .kerning(-0.9)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(LinearGradient(colors: [Theme.pink.opacity(0.07), Theme.cyan.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .frame(height: 240)
                VStack {
                    LetterTile(letter: "Q", value: 10, tier: 5, size: 40)
                        .offset(y: 30)
                    Rectangle()
                        .fill(LinearGradient(colors: [Theme.cyan.opacity(0.9), Theme.cyan.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 3, height: 70)
                        .shadow(color: Theme.cyan, radius: 4)
                        .opacity(0.7)
                    Ship(size: 48)
                        .padding(.top, 16)
                    Circle().fill(.white.opacity(0.85))
                        .frame(width: 18, height: 18)
                        .shadow(color: .white.opacity(0.6), radius: 12)
                        .padding(.top, 4)
                }
                .frame(maxHeight: 240)
            }
            .padding(.horizontal, 24)

            HStack(spacing: 10) {
                tipCard(title: "DRAG ANYWHERE", value: "Ship glides to your finger")
                tipCard(title: "TAP TO FIRE", value: "Quick taps · auto-aimed up")
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Step 4 · Word phase, scoring, power-ups

    private var stepWord: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                EyebrowText(text: "Step · 04 · Word phase")
                Text("Spell big.\nScore bigger.")
                    .font(AppFont.display(30, weight: .bold))
                    .kerning(-0.9)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 14) {
                Text("WORD · QUITS")
                    .font(AppFont.mono(10, weight: .regular))
                    .tracking(2.4)
                    .foregroundColor(Color.white.opacity(0.55))
                HStack(spacing: 4) {
                    LetterTile(letter: "Q", value: 10, tier: 5, size: 38, state: .word)
                    LetterTile(letter: "U", value: 1, tier: 1, size: 38, state: .word)
                    LetterTile(letter: "I", value: 1, tier: 1, size: 38, state: .word)
                    LetterTile(letter: "T", value: 1, tier: 1, size: 38, state: .word)
                    LetterTile(letter: "S", value: 1, tier: 1, size: 38, state: .word)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                VStack(alignment: .leading, spacing: 4) {
                    Text("base 14 · length ×1.25")
                    Text("rare letter +50 · speed ×1.3")
                    Text("= 73 pts").foregroundColor(Theme.yellow)
                }
                .font(AppFont.mono(11, weight: .regular))
                .foregroundColor(Color.white.opacity(0.7))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
            .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 10) {
                EyebrowText(text: "Power-ups")
                tool(name: "ZAP",  desc: "Capture every letter on screen.", color: Theme.yellow,    icon: "bolt.fill")
                tool(name: "WILD", desc: "Next capture becomes a wildcard.", color: Theme.pinkSoft, icon: "star.fill")
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Step 5 · Progression

    private var stepProgression: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                EyebrowText(text: "Step · 05 · Progression")
                Text("Earn, equip,\nadvance.")
                    .font(AppFont.display(30, weight: .bold))
                    .kerning(-0.9)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                Text("Letter Raiders rewards you for everything — long words, daily streaks, raid clears.")
                    .font(AppFont.mono(12, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.white.opacity(0.65))
                    .padding(.horizontal, 32)
            }

            // 2×2 grid of pillar cards. Each calls out one major system
            // the player will see from the home screen.
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                pillarCard(icon: "calendar",      label: "Daily Challenges",
                           sub: "One unique puzzle per day. Build a streak.", color: Theme.yellow)
                pillarCard(icon: "airplane",      label: "Hangar Ships",
                           sub: "16 ships, each with its own combat perk.", color: Theme.cyanSoft)
                pillarCard(icon: "rosette",       label: "Badges",
                           sub: "49 achievements to collect.", color: Theme.pinkSoft)
                pillarCard(icon: "chart.bar.fill", label: "Ranks & XP",
                           sub: "20 ranks unlock prestige ships.", color: Theme.violet)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Sub-views

    private func tipCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppFont.mono(9, weight: .regular))
                .tracking(1.8)
                .foregroundColor(Color.white.opacity(0.55))
            Text(value)
                .font(AppFont.display(13, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    private func tool(name: String, desc: String, color: Color, icon: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.13))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.5), radius: 8)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(AppFont.display(14, weight: .semibold)).foregroundColor(.white)
                Text(desc)
                    .font(AppFont.mono(11.5, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.55))
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    /// Single pillar in the progression-grid (step 5). Square-ish card,
    /// icon coin + label + 1-line sub.
    private func pillarCard(icon: String, label: String, sub: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.16))
                    .frame(width: 36, height: 36)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.4), lineWidth: 1))
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.6), radius: 6)
            }
            Text(label)
                .font(AppFont.display(13, weight: .semibold))
                .foregroundColor(.white)
            Text(sub)
                .font(AppFont.mono(10, weight: .regular))
                .tracking(0.4)
                .foregroundColor(Color.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.25), lineWidth: 1))
        )
    }

    // MARK: - Bottom bar (pager + primary CTA)

    private var bottomBar: some View {
        VStack(spacing: 18) {
            HStack(spacing: 6) {
                ForEach(1...Self.totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i == step
                              ? AnyShapeStyle(LinearGradient(colors: [Theme.pink, Theme.violet], startPoint: .leading, endPoint: .trailing))
                              : AnyShapeStyle(Color.white.opacity(0.2)))
                        .frame(width: i == step ? 22 : 6, height: 6)
                }
            }
            PrimaryButton(
                title: step == Self.totalSteps ? "DEPLOY" : "NEXT",
                icon: "arrow.right",
                fontSize: 16
            ) {
                if step == 1 {
                    advanceFromNickname()
                } else {
                    Haptics.impact(.light)
                    onNext()
                }
            }
            // Step 1 requires a non-empty callsign to advance.
            .opacity(canAdvance ? 1 : 0.5)
            .disabled(!canAdvance)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    /// Whether the primary CTA is currently tappable. Only step 1 gates
    /// on user input — every other step is always advanceable.
    private var canAdvance: Bool {
        if step == 1 {
            return !nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    /// Commit the typed callsign to PlayerProfile before continuing.
    private func advanceFromNickname() {
        let trimmed = nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        PlayerProfile.nickname = trimmed
        nicknameFocused = false
        Haptics.impact(.medium)
        onNext()
    }
}
