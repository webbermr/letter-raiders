# Letter Raiders

iOS SwiftUI game — two-phase neon arcade word game. Phase 1 is a
Space-Invaders-style shooter where the player captures falling letter
tiles; Phase 2 spends those letters on a valid dictionary word for
score.

## Build & verify

```bash
xcodebuild -project LetterRaiders.xcodeproj -target LetterRaiders \
  -configuration Debug -sdk iphonesimulator -arch arm64 build
```

The build is the test suite for this project. **Always run it before
reporting work complete** — the user has been burned by uncaught compile
errors. Filter the output:

```bash
... build 2>&1 | grep -iE "error:|warning:.*\.swift|build (succeeded|failed)" | head -40
```

## Architecture

Everything routes through a single `AppRoute` enum in
[RootView.swift](LetterRaiders/Screens/RootView.swift). `RootView` owns
the `@StateObject run = RunState()` and decides route transitions; every
screen is a thin SwiftUI view that takes data via params + closures (no
global view state).

### Models — [LetterRaiders/Models/](LetterRaiders/Models/)

- [RunState.swift](LetterRaiders/Models/RunState.swift) — per-run state:
  `raid`, `lives`, `carriedLetters`, `cumulativeScore`, `pendingRaidScore`,
  `xpAtRunStart`, `unlockedAtRunStart`. `resetForNewRun()` is the source
  of truth for "fresh run".
- [PlayerProfile.swift](LetterRaiders/Models/PlayerProfile.swift) — XP
  store + 20-rank ladder (start 250, ×1.35 per level). Editable
  nickname. `awardXP(_:)` side-effects rank-up coin bonuses.
- [Hangar.swift](LetterRaiders/Models/Hangar.swift) — persistent
  inventory: coins, owned ships, equipped ship, ZAP/WILD charge stocks
  (capped at 20 each, persist across runs). `ShipLoadout` struct exposes
  per-ship perks consumed by the engine + scorer.
- [Achievements.swift](LetterRaiders/Models/Achievements.swift) — 49
  achievements, UserDefaults stats backing, *exact-length* word
  counters (a 7-letter word does NOT bump the 6-letter counter).
- [DailyPuzzle.swift](LetterRaiders/Models/DailyPuzzle.swift) — 15
  daily puzzles + `PuzzleModifiers` struct; deterministic per-date
  selection via a calendar hash.
- [DailyState.swift](LetterRaiders/Models/DailyState.swift) — attempt
  tracking + streak.
- [ScoreCalculator.swift](LetterRaiders/Models/ScoreCalculator.swift) —
  pure function: word + rack + modifiers + loadout → `ScoreBreakdown`.
- [Letter.swift](LetterRaiders/Models/Letter.swift) — tile definitions,
  tier table, letter-bag builder.
- [WordDictionary.swift](LetterRaiders/Models/WordDictionary.swift) —
  loads ENABLE word list once; no need to read [enable1.txt](LetterRaiders/Resources/enable1.txt).

### Screens — [LetterRaiders/Screens/](LetterRaiders/Screens/)

Each is a SwiftUI `View` routed from `RootView`. Key ones:

| Screen | Role |
|---|---|
| TitleScreen | Home — avatar pill, hero tiles, LAUNCH MISSION, daily teaser, tab bar |
| PlayScreen | Phase 1, contains `ShooterEngine` |
| WordScreen | Phase 2 |
| DailyScreen | Daily puzzle hero card + streak + reset countdown |
| BadgesScreen | All 49 achievements with progress bars |
| SkinsScreen | Hangar — 16 ships + power-up purchases |
| SettingsScreen | Audio, controls, account (nickname rename), credits, rate |
| HelpScreen | Gameplay rules + scoring + progression |
| GameOverScreen | Final score + stats + rank-up + badge-earned celebration queue |
| OnboardingScreen | 5-step intro (nickname → mission → controls → word → progression) |

### Engine

`ShooterEngine` lives inside [PlayScreen.swift](LetterRaiders/Screens/PlayScreen.swift).
It's an `ObservableObject` with `@Published` fields for
letters/bullets/bombs/particles/bunkers/etc. Driven by `tick()` at ~60Hz
via a `TimelineView(.animation)` + nested `.onChange(of: ctx.date)`.

> **Known noise**: that pattern triggers `onChange(of: Date) action
> tried to update multiple times per frame` at runtime. It's accepted —
> any alternative (Timer.publish, task(id:), etc.) produces visible
> jitter because they drift from vsync. See the in-line comment block in
> `PlayScreen.body` where it's set up. **Don't "fix" this.**

The engine reads `ShipLoadout` for per-ship perks and `PuzzleModifiers`
for daily-puzzle tweaks. It writes through to `Hangar` (coins, charge
stocks) and `PlayerProfile` (XP) inline so a pause-quit can't lose
progress.

The engine is re-created per raid via `.id(run.raid)` in `RootView` —
guarantees a fresh `@StateObject`, fresh letter spawns, fresh shield, etc.

### Persistence

Everything player-facing is `@AppStorage` keyed off constants on the
owning model. The full list of keys in use:

| Key | Source | Notes |
|---|---|---|
| `coinBalance` | `Hangar.coinKey` | starting 500 |
| `equippedShipID` | `Hangar.equippedKey` | default "viper" |
| `ownedShipIDsCSV` | `Hangar.ownedKey` | default "viper,magenta,argon" |
| `bonusZapCharges` / `bonusWildCharges` | `Hangar.bonusZapKey`/`bonusWildKey` | persistent charge pool |
| `playerXP` | `PlayerProfile.xpKey` | |
| `playerNickname` | `PlayerProfile.nicknameKey` | default "Cmdr Nyx" |
| `dailyLastAttemptDay` | `DailyState.lastAttemptDayKey` | "YYYY-MM-DD" |
| `dailyStreak` / `dailyStreakLastDay` / `dailyLastScore` / `dailyLastQualified` | DailyState | |
| `achStat.<name>` | `AchievementStore` | one per stat (runsCompleted, longestWord, wordsExact5…10, etc.) |
| `highScore` | RootView | |
| `music` / `sfx` / `haptics` | Settings | |
| `scanlines` | RootView | always-on overlay toggle (removed from Settings UI) |
| `onboardingDone` | RootView | one-shot |
| `seenPhase1Tutorial` / `seenPhase2Tutorial` | PlayScreen/WordScreen | one-shot |

## Typography

- [AppFont.display](LetterRaiders/Theme/Typography.swift) and
  [AppFont.mono](LetterRaiders/Theme/Typography.swift) both resolve to
  **Audiowide-Regular** — keeps a single neon-arcade voice everywhere.
- [AppFont.tile](LetterRaiders/Theme/Typography.swift) → **SpaceGrotesk**
  (only used inside `LetterTile` so the glyph stays legible at small
  sizes; Audiowide's variable-axis weight can't be driven through
  `Font.custom`).
- Audiowide is single-weight; `.weight()` modifiers compile but no-op.
  Bold and regular look identical — by design.

## Theme

[Theme.swift](LetterRaiders/Theme/Theme.swift) palette: `pink`, `violet`,
`cyan` / `cyanSoft`, `yellow`, `amber`, `green`, `red`, `pinkSoft`, plus
`void` (near-black background). Reference colors by name; don't hardcode
hex except inside `Theme` itself.

## Conventions

- **No emoji** in code or copy unless the user explicitly asks.
- **No comments restating what code does.** Comment only non-obvious
  *why* — hidden constraints, invariants, gotchas.
- **No new `*.md` files** unless the user asks for them.
- **`@AppStorage` keys are constants** on the owning model; never
  inline string literals at call sites.
- **Pure functions for scoring** — `ScoreCalculator.score(...)` takes
  everything as params; no globals.
- **Screens take callbacks, not bindings.** `RootView` owns transitions.
- **Confirm destructive git** (force push, reset --hard, etc.) before
  doing it. Routine commits the user has authorized are fine.

## Audio + haptics

- [GameAudio.swift](LetterRaiders/Audio/GameAudio.swift) — singleton
  over `AVAudioPlayer` pools. New SFX: drop `.caf` into
  [Audio/sfx/](LetterRaiders/Audio/sfx/) and register in the
  `presets` dictionary.
- Music: [Audio/music/](LetterRaiders/Audio/music/) — currently
  `Asteroid_Breach.mp3` (AI-generated via Google Gemini).
- [Haptics.swift](LetterRaiders/Audio/Haptics.swift) — respects the
  `haptics` AppStorage flag; calls UIKit's UIImpactFeedbackGenerator /
  UINotificationFeedbackGenerator / UISelectionFeedbackGenerator.

## Things to know

- **Engine timing**: don't change the TimelineView+onChange tick pattern.
  The runtime warning is the lesser evil vs. visual jitter.
- **Daily puzzles**: single-raid (no raid loop). Endless runs do
  `play → word → play → …` via `handleWordResult`.
- **Charges persist forever**: anything earned or bought is the
  player's to keep. Don't reintroduce caps without asking.
- **Word-length badges are exact**: a 7-letter word bumps ONLY
  `wordsExact7`. Don't try to "spread" credit across lower lengths.
- **Celebrations queue**: rank-ups and badge-earned sheets pop in order
  on `GameOverScreen` via a tagged-enum queue. Each sheet's dismiss
  handler calls `advanceCelebration()`.
- **Tutorials are one-shot**: reset by deleting
  `seenPhase1Tutorial` / `seenPhase2Tutorial` from UserDefaults, or by
  deleting the app.
- **Onboarding first**: fresh installs land on `.onboarding(step: 1)`
  via the `onboardingDone` AppStorage gate set in `RootView.init`.

## StoreKit coin packs

Pricing locked in 2026-05 and implemented with StoreKit 2 consumables.
App Store Connect still needs matching products before real/sandbox
prices load:

- Five consumable tiers (`com.markwebber.letterraiders.coins.<slug>`):
  - **Pocket Change** $0.99 → 1,500 coins
  - **Cadet Pack** $2.99 → 5,500 coins
  - **Captain Pack** $4.99 → 12,000 coins · POPULAR
  - **Commander Pack** $9.99 → 30,000 coins · BEST VALUE
  - **Admiral Vault** $19.99 → 65,000 coins · BIGGEST
- $/coin declines monotonically (entry 1,515 c/$, top 3,252 c/$).
- **Raise Eclipse 50,000 → 80,000 coins** so the top pack alone can't
  buy it. Other ship costs unchanged.
- `CoinStore` listens to `Transaction.updates`, verifies purchases,
  deduplicates delivered transaction IDs in UserDefaults, and calls
  `Hangar.awardCoins(_:)`.
- `CoinStoreSheet` is reachable from the title coins chip, the Hangar
  header coin pill, and the LifePurchasePrompt footer when the balance is
  too low.
- First-purchase 2× bonus remains a possible conversion add-on, but is not
  active.
- Post-v1: one-time $1.99 Starter Pack, weekly rotating $0.99 deal slot.
  No subscriptions.

## When in doubt

Run `xcodebuild ... build` before reporting work complete. If the user
reports a runtime issue, repro mentally before changing the code — half
the time the cause is in a different screen than they pointed at.
