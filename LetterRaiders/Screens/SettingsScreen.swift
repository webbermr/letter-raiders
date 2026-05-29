import SwiftUI
import StoreKit

struct SettingsScreen: View {
    var onBack: () -> Void = {}

    @AppStorage("music") private var music: Bool = true
    @AppStorage("sfx") private var sfx: Bool = true
    @AppStorage("haptics") private var haptics: Bool = true
    @AppStorage(PlayerProfile.xpKey) private var playerXP: Int = 0
    @AppStorage(PlayerProfile.nicknameKey) private var playerNickname: String = PlayerProfile.defaultNickname
    /// SwiftUI-native bridge to SKStoreReviewController. iOS shows the
    /// system rating sheet; if Apple decides to throttle (max ~3 prompts
    /// per year per user) it silently no-ops.
    @Environment(\.requestReview) private var requestReview

    /// Drives the rename sheet for the player's nickname.
    @State private var showingNicknameEditor = false
    /// Drives the credits sheet (moved here from the Help view).
    @State private var showingCredits = false
    /// Drives the in-app privacy policy required by App Store review.
    @State private var showingPrivacyPolicy = false

    var body: some View {
        PhoneShell {
            VStack(spacing: 0) {
                PageHeader(title: "Settings", onBack: onBack)
                    .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Section(title: "Audio") {
                            Row(icon: "music.note", label: "Music", sub: "Synth ambient soundtrack") {
                                NeonToggle(on: $music)
                                    .onChange(of: music) { _, newValue in
                                        GameAudio.shared.setMusicEnabled(newValue)
                                    }
                            }
                            Row(icon: "speaker.wave.2.fill", label: "Sound effects", sub: "Shots, hits, UI", isLast: true) {
                                NeonToggle(on: $sfx)
                            }
                        }
                        Section(title: "Controls") {
                            Row(icon: "waveform.path.ecg", label: "Haptic feedback", sub: "Subtle pulses on hits & shots", isLast: true) {
                                NeonToggle(on: $haptics)
                            }
                        }
                        Section(title: "Account") {
                            // Tap to rename — opens a sheet with a TextField.
                            // Sub-line tracks rank live so renaming + ranking
                            // up both feel reactive without a screen change.
                            Button {
                                Haptics.select()
                                showingNicknameEditor = true
                            } label: {
                                Row(icon: "person.fill",
                                    label: playerNickname,
                                    sub: "Rank \(RankSystem.rank(forXP: playerXP)) · \(RankSystem.title(forRank: RankSystem.rank(forXP: playerXP)))",
                                    isLast: true) { Chevron() }
                            }
                            .buttonStyle(.plain)
                            // Game Center + Restore Purchases rows hidden
                            // until the underlying systems are wired up —
                            // shipping placeholder taps is worse than
                            // omitting them.
                        }
                        Section(title: "About") {
                            Button {
                                Haptics.select()
                                showingPrivacyPolicy = true
                            } label: {
                                Row(icon: "shield.fill", label: "Privacy", sub: "Privacy Policy") { Chevron() }
                            }
                            .buttonStyle(.plain)
                            Button {
                                Haptics.select()
                                showingCredits = true
                            } label: {
                                Row(icon: "info.circle.fill", label: "Credits", sub: "Fonts, audio, dictionary") { Chevron() }
                            }
                            .buttonStyle(.plain)
                            Button {
                                Haptics.select()
                                requestReview()
                            } label: {
                                Row(icon: "star.fill", label: "Rate Letter Raiders", sub: "Opens the App Store rating prompt", isLast: true) { Chevron() }
                            }
                            .buttonStyle(.plain)
                        }

                        Text("v 1.0.0 · build 1")
                            .font(AppFont.mono(10, weight: .regular))
                            .tracking(2)
                            .foregroundColor(Color.white.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                            .padding(.bottom, 40)
                    }
                }
            }
        }
        .sheet(isPresented: $showingNicknameEditor) {
            NicknameEditView(initial: playerNickname) { newValue in
                PlayerProfile.nickname = newValue
                // Keep the @AppStorage binding in sync so the row label
                // refreshes the moment the sheet dismisses.
                playerNickname = PlayerProfile.nickname
                showingNicknameEditor = false
            } onCancel: {
                showingNicknameEditor = false
            }
        }
        .sheet(isPresented: $showingCredits) {
            CreditsSheet { showingCredits = false }
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicySheet { showingPrivacyPolicy = false }
        }
    }
}

private struct Section<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowText(text: title).padding(.leading, 24)
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
            .padding(.horizontal, 16)
        }
    }
}

private struct Row<Right: View>: View {
    let icon: String
    let label: String
    var sub: String? = nil
    var isLast: Bool = false
    @ViewBuilder var right: () -> Right

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.06)).frame(width: 32, height: 32)
                    Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(label).font(AppFont.display(14.5, weight: .medium))
                    if let sub {
                        Text(sub)
                            .font(AppFont.mono(11.5, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                }
                Spacer()
                right()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            if !isLast {
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
            }
        }
    }
}

private struct NeonToggle: View {
    @Binding var on: Bool

    var body: some View {
        Button {
            GameAudio.shared.play("toggle")
            on.toggle()
        } label: {
            ZStack(alignment: on ? .trailing : .leading) {
                Capsule()
                    .fill(on
                          ? AnyShapeStyle(LinearGradient(colors: [Theme.pink, Theme.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
                          : AnyShapeStyle(Color.white.opacity(0.12)))
                    .frame(width: 46, height: 28)
                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    .shadow(color: on ? Theme.pink.opacity(0.45) : .clear, radius: 12)
                Circle().fill(.white).frame(width: 22, height: 22).padding(.horizontal, 3)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: on)
    }
}

private struct Segmented: View {
    @Binding var value: String
    let options: [(String, String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { opt in
                Button {
                    value = opt.0
                } label: {
                    let on = value == opt.0
                    Text(opt.1)
                        .font(AppFont.display(11, weight: .semibold))
                        .foregroundColor(on ? Theme.void : Color.white.opacity(0.65))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(on ? Color.white : Color.clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().fill(Color.white.opacity(0.08)))
    }
}

private struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(Color.white.opacity(0.35))
    }
}

/// Renaming sheet for the player nickname. Capped at
/// `PlayerProfile.nicknameMaxLength`; empty input is rejected so the
/// player can't end up with an unlabeled avatar pill.
private struct NicknameEditView: View {
    let initial: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var text: String
    @FocusState private var focused: Bool

    init(initial: String,
         onSave: @escaping (String) -> Void,
         onCancel: @escaping () -> Void) {
        self.initial = initial
        self.onSave = onSave
        self.onCancel = onCancel
        _text = State(initialValue: initial)
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            GameBackground(variant: .cosmos)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Spacer()
                    Button {
                        Haptics.select()
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.10))
                                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)

                Text("CHANGE NICKNAME")
                    .font(AppFont.mono(11, weight: .bold))
                    .tracking(2.6)
                    .foregroundColor(Theme.cyanSoft)

                Text("How you appear on the home screen and leaderboards.")
                    .font(AppFont.mono(12, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)

                TextField("Nickname", text: $text)
                    .font(AppFont.display(20, weight: .bold))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                    .submitLabel(.done)
                    .focused($focused)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cyan.opacity(0.4), lineWidth: 1))
                    )
                    .onSubmit { commit() }

                Text("Up to \(PlayerProfile.nicknameMaxLength) characters. Whitespace trimmed.")
                    .font(AppFont.mono(10, weight: .regular))
                    .tracking(1.4)
                    .foregroundColor(Color.white.opacity(0.45))

                Spacer()

                Button(action: commit) {
                    Text("SAVE")
                        .font(AppFont.mono(13, weight: .semibold))
                        .tracking(2.6)
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(LinearGradient(colors: [Theme.cyan.opacity(0.35), Theme.violet.opacity(0.3)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cyan.opacity(0.5), lineWidth: 1.5))
                        )
                        .shadow(color: Theme.cyan.opacity(0.4), radius: 12)
                        .opacity(trimmed.isEmpty ? 0.5 : 1)
                }
                .buttonStyle(.plain)
                .disabled(trimmed.isEmpty)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
        .onAppear { focused = true }
    }

    private func commit() {
        guard !trimmed.isEmpty else { return }
        Haptics.impact(.medium)
        onSave(trimmed)
    }
}

/// In-app privacy policy. App Store Connect still needs a public policy URL,
/// but App Review also expects the policy to be easily accessible in-app.
private struct PrivacyPolicySheet: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GameBackground(variant: .cosmos)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("PRIVACY POLICY")
                        .font(AppFont.mono(11, weight: .bold))
                        .tracking(3)
                        .foregroundColor(Theme.cyanSoft)

                    Text("Letter Raiders")
                        .font(AppFont.display(28, weight: .bold))
                        .kerning(-0.6)
                        .foregroundColor(.white)

                    Text("Last updated: May 29, 2026")
                        .font(AppFont.mono(10.5, weight: .regular))
                        .tracking(1.4)
                        .foregroundColor(Color.white.opacity(0.45))

                    policySection("Overview",
                                  "Letter Raiders is designed as a local-first arcade word game. The app does not require an account, does not include advertising, does not use third-party analytics, and does not track you across apps or websites.")

                    policySection("Data Stored On Your Device",
                                  "The app stores gameplay and preference data on your device so the game can work between launches. This may include your nickname, high score, XP, rank progress, coins, lives, ship ownership and selection, power-up counts, achievements, daily challenge status, and settings for music, sound effects, haptics, and onboarding.")

                    policySection("Data We Collect",
                                  "Letter Raiders does not transmit gameplay data, nickname data, device identifiers, location, contacts, photos, camera data, microphone data, or similar personal data to a developer-operated server. Data processed only on your device is used for app functionality.")

                    policySection("Apple Services",
                                  "If you download, update, rate, review, purchase coins, or otherwise interact with Letter Raiders through the App Store, Apple may process information under Apple's own privacy policy. In-app purchases are handled by StoreKit and the App Store; Letter Raiders receives purchase status and product information needed to grant coins, but does not receive your payment card details, App Store review text, or Apple Account password.")

                    policySection("Third Parties",
                                  "Letter Raiders does not share user data with advertising networks, analytics providers, data brokers, or other third-party SDKs. If future versions add online services, ads, analytics, or Game Center features, this policy and the App Store privacy details will be updated before those features are released.")

                    policySection("Children",
                                  "Letter Raiders is not directed to children under 13 and does not knowingly collect personal information from children.")

                    policySection("Retention And Deletion",
                                  "Local game data remains on your device until you delete the app or erase the app's data through iOS. Because Letter Raiders does not maintain a developer-operated user account or server database, there is no remote account data for us to delete.")

                    policySection("Your Choices",
                                  "You can change your nickname and audio, sound effect, and haptic preferences from Settings. You can remove locally stored Letter Raiders data by deleting the app from your device.")

                    policySection("Contact",
                                  "For privacy questions, contact Mark Webber through the support contact listed for Letter Raiders on the App Store.")

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Haptics.select()
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .preferredColorScheme(.dark)
    }

    private func policySection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(AppFont.mono(9.5, weight: .bold))
                .tracking(2.0)
                .foregroundColor(Theme.cyanSoft)
            Text(body)
                .font(AppFont.mono(11, weight: .regular))
                .foregroundColor(Color.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
    }
}

/// Credits + copyright sheet. Surfaces the third-party attributions that
/// used to live on the Help screen. Pulled into Settings so the Help view
/// stays focused on gameplay rules.
private struct CreditsSheet: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GameBackground(variant: .cosmos)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("CREDITS")
                        .font(AppFont.mono(11, weight: .bold))
                        .tracking(3)
                        .foregroundColor(Theme.cyanSoft)

                    Text("Letter Raiders")
                        .font(AppFont.display(28, weight: .bold))
                        .kerning(-0.6)
                        .foregroundColor(.white)

                    creditLine("Fonts",
                               "Audiowide by Astigmatic · SpaceGrotesk by Florian Karsten · " +
                               "MajorMonoDisplay by Emre Parlak · JetBrainsMono by JetBrains. " +
                               "All licensed under the SIL Open Font License.")
                    creditLine("Sound Effects",
                               "Kenney Interface Sounds and Sci-Fi Sounds packs (kenney.nl) — " +
                               "Creative Commons Zero (CC0).")
                    creditLine("Music",
                               "\"Asteroid Breach\" — AI-generated via Google Gemini.")
                    creditLine("Dictionary",
                               "ENABLE word list (public domain).")

                    let year = String(Calendar.current.component(.year, from: Date()))
                    VStack(spacing: 4) {
                        Text("© \(year) Mark Webber")
                            .font(AppFont.mono(11, weight: .bold))
                            .tracking(1.4)
                            .foregroundColor(Color.white.opacity(0.65))
                        Text("All rights reserved.")
                            .font(AppFont.mono(9.5, weight: .regular))
                            .tracking(1.6)
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Haptics.select()
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
        .preferredColorScheme(.dark)
    }

    private func creditLine(_ label: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(AppFont.mono(9.5, weight: .bold))
                .tracking(2.0)
                .foregroundColor(Theme.cyanSoft)
            Text(body)
                .font(AppFont.mono(11, weight: .regular))
                .foregroundColor(Color.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
    }
}
