# Letter Raiders

A neon-arcade word game for iOS. Shoot down falling letters, then spend them on the highest-scoring word you can build before the clock runs out.

Two phases. One mission. Synthwave forever.

---

## The game

Each raid is a two-phase loop:

1. **Phase 1 — Letter Raid.** Pilot your ship through a Space-Invaders-style barrage. Capture falling letter tiles, dodge enemy bombs, and survive long enough to fill your rack.
2. **Phase 2 — Word Build.** Spend the letters you captured on a valid dictionary word. Longer words score more. Bonus tiles, ship perks, and rack-clears stack into massive combos.

Clear the word, carry leftover letters to the next raid, and chase your high score across an endless run — or take on today's themed daily puzzle for streak rewards.

---

## Features

- **16 ships**, each with a distinct gameplay perk — faster fire rate, slower bombs, letter magnets, score multipliers, longer racks, starting shields, and more. Earn them by rank or buy them with coins in the Hangar.
- **49 badges** to unlock across word length, score milestones, daily streaks, ship collection, and survival feats.
- **20-rank progression ladder** from Recruit to Grand Admiral, with coin bonuses at every promotion.
- **15 daily puzzles** with unique modifiers — banned letters, vowel-only racks, double-bomb chaos, pure-word challenges, speed runs, and more. New puzzle every day, deterministic worldwide.
- **Persistent power-ups.** ZAP clears the board; WILD turns a letter into any other. Earned or bought, they're yours to keep — no draining between runs.
- **Editable pilot nickname** with an avatar monogram on every screen.
- **First-time tutorials** for both phases, with one-shot overlays that won't bother veterans.
- **Haptics, SFX, and a synthwave soundtrack** — all toggleable in Settings.

---

## Tech

- SwiftUI, iOS 17+
- iPhone (portrait)
- ~60Hz game engine driven by `TimelineView(.animation)`
- All persistence via `@AppStorage` (no external backend)
- ENABLE word list for dictionary validation

---

## Build

```bash
xcodebuild -project LetterRaiders.xcodeproj -target LetterRaiders \
  -configuration Debug -sdk iphonesimulator -arch arm64 build
```

Open `LetterRaiders.xcodeproj` in Xcode to run on a simulator or device.

---

## Credits

- **Type** — [Audiowide](https://fonts.google.com/specimen/Audiowide), [Space Grotesk](https://fonts.google.com/specimen/Space+Grotesk), [Major Mono Display](https://fonts.google.com/specimen/Major+Mono+Display), [JetBrains Mono](https://www.jetbrains.com/lp/mono/) — via the SIL Open Font License.
- **Sound effects** — [Kenney](https://kenney.nl/) Sci-Fi Sounds and Interface Sounds (CC0).
- **Music** — *Asteroid Breach*, AI-generated via Google Gemini.
- **Dictionary** — [ENABLE](https://github.com/dolph/dictionary) word list.

---

© 2026 Mark Webber. All rights reserved.
