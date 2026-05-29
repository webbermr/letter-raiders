import SwiftUI

struct PlayResult {
    let rack: [CapturedLetter]
    let score: Int            // capture score earned this raid
    let reason: String
    let livesRemaining: Int
    let bestComboThisRaid: Int
    let lettersCapturedThisRaid: Int
    let coinsEarnedThisRaid: Int
    /// Charges still unspent at raid end. Hangar owns the persistent capped
    /// stock, so unused power-ups aren't wasted.
    let zapChargesRemaining: Int
    let wildChargesRemaining: Int
}

// MARK: - Bunker

struct BunkerData: Identifiable {
    let id = UUID()
    let originX: CGFloat
    let originY: CGFloat
    let cellSize: CGFloat
    let cols: Int
    let rows: Int
    var cells: [[Bool]]   // [rows][cols]

    var width: CGFloat { CGFloat(cols) * cellSize }
    var height: CGFloat { CGFloat(rows) * cellSize }

    init(originX: CGFloat, originY: CGFloat, cols: Int = 9, rows: Int = 4, cellSize: CGFloat = 10) {
        self.originX = originX
        self.originY = originY
        self.cols = cols
        self.rows = rows
        self.cellSize = cellSize
        var grid = Array(repeating: Array(repeating: true, count: cols), count: rows)
        // Round the top corners
        if rows > 0 && cols >= 2 {
            grid[0][0] = false
            grid[0][cols - 1] = false
        }
        // Carve a notch at the bottom middle
        if rows >= 2 {
            let mid = cols / 2
            grid[rows - 1][mid] = false
            if mid - 1 >= 0 { grid[rows - 1][mid - 1] = false }
            if mid + 1 < cols { grid[rows - 1][mid + 1] = false }
        }
        self.cells = grid
    }

    /// Damage cells overlapping a rectangle centered at `point` with given half-extents.
    /// Returns the number of cells destroyed.
    @discardableResult
    mutating func damage(at point: CGPoint, halfWidth: CGFloat, halfHeight: CGFloat) -> Int {
        let bounds = CGRect(x: originX, y: originY, width: width, height: height)
            .insetBy(dx: -halfWidth, dy: -halfHeight)
        guard bounds.contains(point) else { return 0 }
        var destroyed = 0
        for r in 0..<rows {
            for c in 0..<cols {
                guard cells[r][c] else { continue }
                let cx = originX + CGFloat(c) * cellSize + cellSize / 2
                let cy = originY + CGFloat(r) * cellSize + cellSize / 2
                if abs(cx - point.x) < cellSize / 2 + halfWidth,
                   abs(cy - point.y) < cellSize / 2 + halfHeight {
                    cells[r][c] = false
                    destroyed += 1
                }
            }
        }
        return destroyed
    }

    var aliveCellCount: Int {
        cells.reduce(0) { $0 + $1.filter { $0 }.count }
    }
}

// MARK: - Projectiles

struct Bullet2D: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vy: CGFloat
    /// Extra letters this bullet can still pierce through. 0 = next hit consumes it.
    var piercesLeft: Int = 0
}

struct Bomb2D: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vy: CGFloat
}

/// A wildcard ★ tile that scrolls across the top of the play field
/// (the Letter-Raiders analogue of the classic Space Invaders UFO).
struct FlybyLetter: Identifiable {
    let id = UUID()
    var x: CGFloat
    let y: CGFloat
    var vx: CGFloat
}

struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: Double
    var vy: Double
    var t: Double
    var life: Double
    var color: Color
}

// MARK: - Engine

@MainActor
final class ShooterEngine: ObservableObject {
    // Stage coords
    let stageWidth: CGFloat = 390
    let stageHeight: CGFloat = 844

    // Ship sits just slightly above the power-up row.
    let shipY: CGFloat = 628
    let bunkerY: CGFloat = 570  // top of bunkers — clears the ship by ~18pt

    // Configurable
    let holdLimit: Int
    let raidSeconds: Double
    let maxLives: Int
    /// 1-indexed raid number — drives the difficulty ramp.
    let raidNumber: Int
    /// Equipped ship parameters. Drives ship glide, combo grace, bullet
    /// hit-box, flyby coin payout, and bullet pierce.
    let loadout: ShipLoadout
    /// Daily-puzzle gameplay tweaks. `.none` for the standard endless run.
    let modifiers: PuzzleModifiers
    /// Precomputed weighted letter bag honouring the modifiers' filters.
    private let letterBag: [Character]

    // Published state
    @Published var shipX: CGFloat
    @Published var targetX: CGFloat
    @Published var letters: [FallingLetter] = []
    @Published var bullets: [Bullet2D] = []
    @Published var bombs: [Bomb2D] = []
    @Published var particles: [Particle] = []
    @Published var bunkers: [BunkerData] = []
    @Published var flyby: FlybyLetter? = nil
    @Published var rack: [CapturedLetter] = []
    @Published var score: Int = 0
    @Published var combo: Int = 0
    @Published var raidMs: Double
    @Published var lives: Int
    @Published var ended: Bool = false
    @Published var zapCharges: Int
    @Published var wildCharges: Int
    @Published var wildArmed: Bool = false
    @Published var zapFx: Double = 0
    @Published var hitFlash: Double = 0   // ms remaining on the red screen flash
    /// When true, `tick` short-circuits so the simulation freezes in place.
    /// `lastTimestamp` is also reset so a resume doesn't apply the elapsed
    /// pause duration as one giant dt.
    @Published var paused: Bool = false
    /// When true, the player just lost their last life AND has enough coins
    /// to buy at least one more. The view shows the CONTINUE overlay; the
    /// engine stays paused until the player either purchases (applyContinue)
    /// or declines (declineContinue). Suppressed entirely when
    /// `allowContinue` is false (e.g., daily puzzles).
    @Published var pendingContinue: Bool = false

    private var lastTimestamp: TimeInterval = 0
    private var spawnAccumulator: Double = 0
    private var bombAccumulator: Double = 0
    private var flybyAccumulator: Double = 0
    private var fireCooldown: Double = 0
    private var comboDecay: Double = 0
    private var invuln: Double = 0    // ship damage-immune window after a hit (ms)
    private var bestComboThisRaid: Int = 0
    private var lettersCapturedThisRaid: Int = 0
    private var coinsEarnedThisRaid: Int = 0
    /// Sentinel's one-time shield charge for this raid. Reset implicitly per
    /// raid because the engine is re-created on each new raid (.id(run.raid)).
    private var shieldUsedThisRaid: Bool = false
    /// Whether the continue-prompt flow is allowed when the ship is destroyed.
    /// Endless runs allow it; daily puzzles (`activeDailyPuzzle != nil`) pass
    /// false so the puzzle's life budget can't be bought past.
    private let allowContinue: Bool
    private(set) var onComplete: ((PlayResult) -> Void)?

    init(holdLimit: Int,
         raidSeconds: Double,
         raidNumber: Int = 1,
         initialLives: Int = 3,
         maxLives: Int = 3,
         initialRack: [CapturedLetter] = [],
         loadout: ShipLoadout = ShipLoadout.forID("viper"),
         modifiers: PuzzleModifiers = .none,
         initialZap: Int = 1,
         initialWild: Int = 1,
         allowContinue: Bool = true,
         onComplete: @escaping (PlayResult) -> Void) {
        self.holdLimit = holdLimit
        self.raidSeconds = raidSeconds
        self.raidNumber = max(1, raidNumber)
        self.maxLives = maxLives
        self.loadout = loadout
        self.modifiers = modifiers
        self.allowContinue = allowContinue
        self.letterBag = LetterData.bag(for: modifiers)
        self.shipX = 390 / 2
        self.targetX = 390 / 2
        self.raidMs = raidSeconds * 1000
        self.lives = max(1, min(maxLives, initialLives))
        self.rack = initialRack
        // Caller (RunState via PlayScreen) supplies the starting charge
        // counts so stockpiling between raids + Hangar purchases work.
        // Modifier gates (allowZap / allowWild) clamp to 0 for puzzles
        // that ban power-ups entirely.
        self.zapCharges = modifiers.allowZap ? max(0, initialZap) : 0
        self.wildCharges = modifiers.allowWild ? max(0, initialWild) : 0
        self.onComplete = onComplete

        // Three bunkers, evenly spaced across the stage width.
        // Bastion: bunkerSizeMul scales the per-bunker row count so each
        // bunker has ~50% more cells (default 4 rows → 6 rows). Cols and
        // cell size stay fixed so the horizontal layout doesn't shift.
        let cellSize: CGFloat = 5
        let cols = 9
        let rows = max(2, Int((Double(4) * loadout.bunkerSizeMul).rounded()))
        let bunkerW = CGFloat(cols) * cellSize   // = 45
        let gap = (stageWidth - bunkerW * 3) / 4
        for i in 0..<3 {
            let x = gap + CGFloat(i) * (bunkerW + gap)
            bunkers.append(BunkerData(originX: x, originY: bunkerY, cols: cols, rows: rows, cellSize: cellSize))
        }
    }

    // MARK: input
    func setTarget(_ x: CGFloat) {
        guard !ended else { return }
        targetX = max(28, min(stageWidth - 28, x))
    }

    func fire() {
        guard !ended, fireCooldown <= 0 else { return }
        // Cascade: fireCooldownMul < 1 means a shorter dead zone between shots.
        fireCooldown = 220 * loadout.fireCooldownMul
        bullets.append(Bullet2D(x: shipX, y: shipY - 14, vy: -0.6, piercesLeft: loadout.bulletPierces))
        GameAudio.shared.play("shoot")
        // Very light, intentionally weak — fires can be rapid; full impact
        // here would feel like sandpaper. selectionChanged is the cheapest tap.
        Haptics.select()
    }

    func activateZap() {
        // Source of truth = Hangar.zapStock. Decrement there first so a
        // pause-quit / app crash mid-raid can't lose the spend.
        guard !ended, modifiers.allowZap, Hangar.zapStock > 0 else { return }
        Hangar.zapStock -= 1
        zapCharges = Hangar.zapStock
        zapFx = 600
        GameAudio.shared.play("ufo_kill")
        Haptics.impact(.heavy)
        let remaining = holdLimit - rack.count
        let capture = Array(letters.prefix(remaining))
        for l in capture { captureLetter(l, viaZap: true) }
        letters.removeAll { l in capture.contains { $0.id == l.id } }
    }

    func armWild() {
        guard !ended, modifiers.allowWild, Hangar.wildStock > 0, !wildArmed else { return }
        wildArmed = true
        Hangar.wildStock -= 1
        wildCharges = Hangar.wildStock
        GameAudio.shared.play("wild_armed")
        Haptics.impact(.medium)
    }

    // MARK: loop
    func tick(_ now: TimeInterval) {
        if paused {
            // Drop the timestamp so the first tick after resume starts with
            // dt = 0 instead of catching up over the entire pause duration.
            lastTimestamp = 0
            return
        }
        if lastTimestamp == 0 { lastTimestamp = now }
        let dt = min(40, (now - lastTimestamp) * 1000)
        lastTimestamp = now
        step(dt)
    }

    private func step(_ dt: Double) {
        guard !ended else { return }

        // Ship glide — Magenta amplifies the lerp coefficient for snappier movement.
        shipX += (targetX - shipX) * min(1, dt * 0.018 * loadout.glideMul)

        // Timers
        raidMs -= dt
        if raidMs <= 0 { endRun(reason: "time_up"); return }
        if comboDecay > 0 { comboDecay -= dt; if comboDecay <= 0 { combo = 0 } }
        if zapFx > 0 { zapFx -= dt }
        if fireCooldown > 0 { fireCooldown -= dt }
        if invuln > 0 { invuln -= dt }
        if hitFlash > 0 { hitFlash -= dt }

        // Difficulty ramp — within-raid (elapsedFrac), across-raids (raidNumber),
        // and per-capture (lettersCapturedThisRaid). All three are capped so the
        // late game stays playable. The per-capture boost rewards aggression but
        // also penalises rack-camping: the more you've already shot down, the
        // faster the next wave comes at you.
        let elapsedFrac = 1 - raidMs / (raidSeconds * 1000)   // 0 → 1
        let withinRaidSpeed = 1.0 + elapsedFrac * 0.5         // 1.0 → 1.5×
        let raidSpeed = min(1.7, 1.0 + Double(raidNumber - 1) * 0.07)  // raid 1=1.0, raid 10=1.6
        let captureBoost = min(0.30, Double(lettersCapturedThisRaid) * 0.01)  // +1% per letter, cap +30%
        let speedMul = withinRaidSpeed * raidSpeed * (1 + captureBoost)
        let raidBombScale = max(0.55, 1.0 - Double(raidNumber - 1) * 0.06)

        // Spawn letters
        let remaining = holdLimit - rack.count
        if remaining > 0 {
            spawnAccumulator += dt
            let baseInterval = max(420, 720 - elapsedFrac * 300)
            let interval = baseInterval * raidBombScale   // tighter spawn cadence per raid
            if spawnAccumulator > interval {
                spawnAccumulator = 0
                // Pulsar: wildSpawnMul scales the wildcard probability for
                // this ship (e.g. 2× wild rate). Modifier and loadout
                // multipliers compound.
                let wildChance = modifiers.wildSpawnChance * loadout.wildSpawnMul
                var newL = LetterRoll.roll(wildChance: wildChance, bag: letterBag)
                newL.x = 30 + CGFloat.random(in: 0...(stageWidth - 60))
                // Combined within-raid + raid-number boost, then the daily
                // puzzle's letterSpeedMul (Speed Run 1.5×, Slow Motion 0.5×).
                newL.vy *= speedMul * modifiers.letterSpeedMul
                letters.append(newL)
            }
        }

        // Spawn enemy bombs from random letters.
        // Base interval was reduced 50%; further scales with elapsedFrac AND raid.
        bombAccumulator += dt
        let baseBomb = max(550, 1133 - elapsedFrac * 583)
        // bombRateMul > 1 = bombs spawn MORE often → divide interval.
        let bombMulSafe = max(0.1, modifiers.bombRateMul)
        let bombInterval = max(380, baseBomb * raidBombScale / bombMulSafe)
        if bombAccumulator > bombInterval, !letters.isEmpty {
            bombAccumulator = 0
            if let firer = letters.randomElement() {
                // Nebula: bombSpeedMul < 1 slows incoming bombs.
                bombs.append(Bomb2D(x: firer.x, y: firer.y + 16, vy: 0.32 * speedMul * modifiers.letterSpeedMul * loadout.bombSpeedMul))
            }
        }

        // Flyby wildcard — one at a time, scrolls across the top.
        if flyby == nil {
            flybyAccumulator += dt
            let flybyInterval: Double = 9000  // ~every 9s a chance opens up
            if flybyAccumulator > flybyInterval {
                flybyAccumulator = 0
                let fromLeft = Bool.random()
                flyby = FlybyLetter(
                    x: fromLeft ? -30 : stageWidth + 30,
                    y: 92,   // tucked right under the rack panel (rack moved up after chrome removal)
                    vx: (fromLeft ? 1 : -1) * 0.16
                )
            }
        } else if var fb = flyby {
            fb.x += fb.vx * dt
            if fb.x < -50 || fb.x > stageWidth + 50 {
                flyby = nil
            } else {
                flyby = fb
            }
        }

        // Move bullets (upward)
        bullets = bullets.compactMap { b in
            var b = b
            b.y += b.vy * dt
            return (b.y > 60 && b.y < stageHeight - 50) ? b : nil
        }

        // Move bombs (downward)
        bombs = bombs.compactMap { b in
            var b = b
            b.y += b.vy * dt
            return (b.y < stageHeight - 50) ? b : nil
        }

        // Move letters
        for i in letters.indices { letters[i].y += letters[i].vy * dt }

        // --- Collisions ---

        // Bullet vs letter (capture)
        //   • Twilight: `loadout.bulletHitRadius` widens the hit-box (20 → 28).
        //   • Nova:     `piercesLeft` lets one bullet hit multiple letters
        //               before being consumed.
        // We iterate `bullets.indices` so we can mutate piercesLeft in-place.
        let hit = loadout.bulletHitRadius
        var capturedIDs: Set<UUID> = []
        var spentBullets: Set<UUID> = []
        for i in bullets.indices {
            var b = bullets[i]
            for l in letters {
                if capturedIDs.contains(l.id) { continue }
                if abs(b.x - l.x) < hit, abs(b.y - l.y) < hit {
                    capturedIDs.insert(l.id)
                    captureLetter(l)
                    if b.piercesLeft > 0 {
                        b.piercesLeft -= 1
                        // Bullet survives; keep scanning letters this frame.
                    } else {
                        spentBullets.insert(b.id)
                        break
                    }
                }
            }
            bullets[i] = b
        }
        if !capturedIDs.isEmpty { letters.removeAll { capturedIDs.contains($0.id) } }
        if !spentBullets.isEmpty { bullets.removeAll { spentBullets.contains($0.id) } }

        // Bullet vs flyby — capture the scrolling wildcard UFO.
        // Hit-box is wider than tall to match the saucer silhouette.
        if let fb = flyby {
            for b in bullets {
                if abs(b.x - fb.x) < 34, abs(b.y - fb.y) < 18 {
                    bullets.removeAll { $0.id == b.id }
                    flyby = nil
                    captureFlyby(at: CGPoint(x: fb.x, y: fb.y))
                    break
                }
            }
        }

        // Bullet vs bunker (friendly fire damages bunkers from below)
        spentBullets.removeAll()
        for b in bullets {
            for i in bunkers.indices {
                let destroyed = bunkers[i].damage(
                    at: CGPoint(x: b.x, y: b.y),
                    halfWidth: 1.5, halfHeight: 3
                )
                if destroyed > 0 {
                    spentBullets.insert(b.id)
                    spawnImpactParticles(at: CGPoint(x: b.x, y: b.y), color: Theme.green)
                    break
                }
            }
        }
        if !spentBullets.isEmpty { bullets.removeAll { spentBullets.contains($0.id) } }

        // Bomb vs bunker
        var spentBombs: Set<UUID> = []
        for b in bombs {
            for i in bunkers.indices {
                let destroyed = bunkers[i].damage(
                    at: CGPoint(x: b.x, y: b.y),
                    halfWidth: 1.5, halfHeight: 3
                )
                if destroyed > 0 {
                    spentBombs.insert(b.id)
                    spawnImpactParticles(at: CGPoint(x: b.x, y: b.y), color: Theme.red)
                    break
                }
            }
        }

        // Bomb vs ship
        for b in bombs where !spentBombs.contains(b.id) {
            if abs(b.x - shipX) < 22, abs(b.y - shipY) < 22 {
                spentBombs.insert(b.id)
                spawnImpactParticles(at: CGPoint(x: b.x, y: b.y), color: Theme.red, count: 14)
                takeDamage()
            }
        }
        if !spentBombs.isEmpty { bombs.removeAll { spentBombs.contains($0.id) } }

        // Letter vs bunker — the letter punches into the bunker and is destroyed
        // (so it doesn't keep floating down through the cells). Half-extents
        // match the visible 36pt tile so ANY part touching a bunker counts as
        // a hit, not just the centre.
        var spentLetters: Set<UUID> = []
        for l in letters {
            var didHit = false
            for j in bunkers.indices {
                let destroyed = bunkers[j].damage(
                    at: CGPoint(x: l.x, y: l.y),
                    halfWidth: 18, halfHeight: 18
                )
                if destroyed > 0 { didHit = true }
            }
            if didHit {
                spentLetters.insert(l.id)
                spawnImpactParticles(at: CGPoint(x: l.x, y: l.y), color: l.color, count: 10)
                // Letter explosion against the bunker — re-uses the "bomb"
                // sample (low-thud impact) which is rate-limited inside
                // GameAudio so multi-hit frames don't pile up.
                GameAudio.shared.play("bomb")
                Haptics.impact(.medium, intensity: 0.7)
            }
        }

        // Letter vs ship
        for l in letters where !spentLetters.contains(l.id) {
            if abs(l.x - shipX) < 24, abs(l.y - shipY) < 24 {
                spentLetters.insert(l.id)
                spawnImpactParticles(at: CGPoint(x: l.x, y: l.y), color: l.color, count: 14)
                takeDamage()
            }
        }

        // Letters that escaped past the bottom of the ship area.
        // Phantom: `letterMagnet` intercepts them and tries to capture
        // into the rack instead of letting them die. If the rack is full,
        // remaining escapees still die with the normal thud.
        let escapeY = shipY + 30
        let escaping = letters.filter { $0.y > escapeY }
        if !escaping.isEmpty {
            if loadout.letterMagnet {
                let openSlots = max(0, holdLimit - rack.count)
                let captured = Array(escaping.prefix(openSlots))
                for l in captured { captureLetter(l, viaZap: true) }
                if escaping.count > openSlots {
                    GameAudio.shared.play("bomb")
                }
            } else {
                // One subdued bomb-thud per frame (rate-limited inside GameAudio).
                GameAudio.shared.play("bomb")
            }
        }
        spentLetters.formUnion(Set(escaping.map(\.id)))
        if !spentLetters.isEmpty { letters.removeAll { spentLetters.contains($0.id) } }

        // Particles
        particles = particles.compactMap { p in
            var p = p
            p.x += p.vx * dt
            p.y += p.vy * dt
            p.t -= dt
            return p.t > 0 ? p : nil
        }
    }

    private func takeDamage() {
        guard invuln <= 0, !ended else { return }
        // Sentinel: first hit each raid is absorbed by the shield. Player
        // still gets the brief invuln window + a flash so the absorb
        // reads visually as "a hit happened" — they just don't lose a life.
        if loadout.firstHitShield && !shieldUsedThisRaid {
            shieldUsedThisRaid = true
            invuln = 1000
            hitFlash = 200
            GameAudio.shared.play("shield")
            Haptics.impact(.medium)
            return
        }
        invuln = 1000
        hitFlash = 350
        lives -= 1
        GameAudio.shared.play("player_hit")
        // Hard thud on hit; on lethal hit also trigger an error notification
        // for the "you just died" gut-punch.
        Haptics.impact(.heavy)
        if lives <= 0 {
            // Continue prompt: if allowed, pause and let the player decide.
            // The prompt can route short balances to the coin store.
            if allowContinue {
                Haptics.notify(.warning)
                paused = true
                pendingContinue = true
            } else {
                Haptics.notify(.error)
                endRun(reason: "no_lives")
            }
        }
    }

    /// Player accepted the continue prompt and bought `count` lives. Deducts
    /// coins, restores lives, dismisses the overlay, and unpauses. Capped
    /// at `maxLives` so a daily-puzzle-style override is respected.
    func applyContinue(count: Int) {
        guard pendingContinue, count > 0 else { return }
        let cost = Hangar.lifePrice * count
        guard Hangar.coins >= cost else { return }
        Hangar.coins -= cost
        lives = max(1, min(maxLives, count))
        pendingContinue = false
        paused = false
        // Reset invuln so the player gets a brief grace window on resume —
        // otherwise the same bullet that killed them could double-hit on
        // the next frame.
        invuln = 1500
        hitFlash = 0
        GameAudio.shared.play("shield")
        Haptics.notify(.success)
    }

    /// Player declined the continue prompt. End the run with the same
    /// no-lives reason as a no-prompt path so RootView's handling is uniform.
    func declineContinue() {
        guard pendingContinue else { return }
        pendingContinue = false
        Haptics.notify(.error)
        endRun(reason: "no_lives")
    }

    private func spawnImpactParticles(at p: CGPoint, color: Color, count: Int = 6) {
        for _ in 0..<count {
            particles.append(Particle(
                x: p.x, y: p.y,
                vx: Double.random(in: -0.35...0.35),
                vy: Double.random(in: -0.35...0.15),
                t: 600, life: 600,
                color: color
            ))
        }
    }

    private func captureLetter(_ l: FallingLetter, viaZap: Bool = false) {
        guard rack.count < holdLimit else { return }
        let armed = wildArmed && !viaZap
        if armed { wildArmed = false }
        let captured = armed
            ? CapturedLetter(letter: "★", value: 0, tier: 5, wild: true)
            : CapturedLetter(letter: l.letter, value: l.value, tier: l.tier, wild: l.wild)
        rack.append(captured)

        combo = min(9, combo + 1)
        bestComboThisRaid = max(bestComboThisRaid, combo)
        // Argon stretches the combo grace window (1600ms × comboDecayMul).
        comboDecay = 1600 * loadout.comboDecayMul
        score += (l.wild ? 12 : l.value) * (1 + combo / 2) * 10
        lettersCapturedThisRaid += 1
        // Coin drip: +1 per regular letter capture (Aurora does NOT amplify this).
        Hangar.awardCoins(1)
        coinsEarnedThisRaid += 1
        // XP drip: +1 per capture. Mass-capture from ZAP also counts so a
        // well-timed ZAP at a packed screen is a meaningful XP burst.
        PlayerProfile.awardXP(1)

        // Light haptic per capture, scaled by combo so the device "feels" the
        // chain build (intensity 0.5 → 1.0 from combo 1 → 9). Skipped for ZAP
        // mass-capture so we don't fire 6+ taps in one frame — ZAP gets its
        // own heavy impact at activation time.
        if !viaZap {
            Haptics.impact(.light, intensity: 0.5 + min(1.0, Double(combo) / 9.0) * 0.5)
        }

        // SFX: alternating hit + ascending combo blip after each capture.
        // Skip per-letter cues when ZAP fires (mass capture) so we don't
        // stack 6 hits at once — ZAP plays `ufo_kill` instead.
        if !viaZap {
            GameAudio.shared.play(Bool.random() ? "hit_a" : "hit_b")
            GameAudio.shared.combo(combo)
        }

        for _ in 0..<8 {
            particles.append(Particle(
                x: l.x, y: l.y,
                vx: Double.random(in: -0.25...0.25),
                vy: Double.random(in: -0.30 ... -0.05),
                t: 700, life: 700,
                color: l.color
            ))
        }

        if rack.count >= holdLimit {
            GameAudio.shared.play("rack_full")
            endRun(reason: "rack_full")
        }
    }

    private func captureFlyby(at p: CGPoint) {
        guard rack.count < holdLimit else { return }
        rack.append(CapturedLetter(letter: "★", value: 0, tier: 5, wild: true))
        lettersCapturedThisRaid += 1
        combo = min(9, combo + 1)
        comboDecay = 1600 * loadout.comboDecayMul
        score += 200 * (1 + combo / 2)   // big bonus for the fly-by
        // UFO coin payout — Aurora's signature bonus multiplies this only.
        let baseFlybyCoins = 25
        let flybyCoins = Int((Double(baseFlybyCoins) * loadout.flybyCoinMul).rounded())
        Hangar.awardCoins(flybyCoins)
        coinsEarnedThisRaid += flybyCoins
        // UFO bounty also pays XP — harder target than a regular letter.
        PlayerProfile.awardXP(10)
        // Flyby = big bonus → success notification haptic.
        Haptics.notify(.success)
        spawnImpactParticles(at: p, color: TierTable.wildColor, count: 18)
        if rack.count >= holdLimit { endRun(reason: "rack_full") }
    }

    private func endRun(reason: String) {
        guard !ended else { return }
        ended = true
        // Reserve the big "raid over" cue for actual losses or time-up;
        // rack_full has its own cue.
        if reason != "rack_full" {
            GameAudio.shared.play("game_over")
            Haptics.notify(.error)
        } else {
            // Rack full = "good problem" (you captured everything) — a single
            // medium tick instead of the error pattern.
            Haptics.impact(.medium)
        }
        let result = PlayResult(
            rack: rack,
            score: score,
            reason: reason,
            livesRemaining: lives,
            bestComboThisRaid: bestComboThisRaid,
            lettersCapturedThisRaid: lettersCapturedThisRaid,
            coinsEarnedThisRaid: coinsEarnedThisRaid,
            zapChargesRemaining: zapCharges,
            wildChargesRemaining: wildCharges
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.onComplete?(result)
        }
    }
}

// MARK: - View

struct PlayScreen: View {
    var background: BackgroundVariant = .cosmos
    var holdLimit: Int = 10
    var raidSeconds: Double = 30
    var raidNumber: Int = 1
    var initialLives: Int = 3
    var initialRack: [CapturedLetter] = []
    /// Score banked from previous raids in this run. Added to `engine.score`
    /// for the running total displayed in the HUD. The current raid's score
    /// is still pending (only banks on a valid word), but surfacing it live
    /// gives the player a clear sense of run progress.
    var cumulativeScoreBase: Int = 0
    var loadout: ShipLoadout = ShipLoadout.forID("viper")
    /// Daily-puzzle modifiers. `.none` for the standard endless run.
    var modifiers: PuzzleModifiers = .none
    /// Starting power-up charges (carryover from prior raid + Hangar bank).
    /// Modifier gates may clamp these to 0.
    var initialZap: Int = 1
    var initialWild: Int = 1
    var showHorizon: Bool = true
    var onPause: () -> Void = {}
    var onComplete: (PlayResult) -> Void = { _ in }

    @StateObject private var engine: ShooterEngine
    @State private var stageSize: CGSize = .zero
    @State private var dragMoved: Bool = false
    @State private var showingPauseMenu: Bool = false
    /// First-time controls/power-ups overlay. Shown ONCE per install on
    /// the player's first Phase 1, then `seenPhase1Tutorial` is flipped.
    @State private var showingPhase1Tutorial: Bool = false
    @State private var showingCoinStore: Bool = false
    @AppStorage("seenPhase1Tutorial") private var seenPhase1Tutorial: Bool = false
    /// Live coin balance. Reads the same UserDefaults key the engine writes
    /// to via Hangar.awardCoins, so the HUD chip ticks up in real time.
    @AppStorage(Hangar.coinKey) private var coins: Int = Hangar.startingCoins

    init(background: BackgroundVariant = .cosmos,
         holdLimit: Int = 10,
         raidSeconds: Double = 30,
         raidNumber: Int = 1,
         initialLives: Int = 3,
         initialRack: [CapturedLetter] = [],
         cumulativeScoreBase: Int = 0,
         loadout: ShipLoadout = ShipLoadout.forID("viper"),
         modifiers: PuzzleModifiers = .none,
         initialZap: Int = 1,
         initialWild: Int = 1,
         allowContinue: Bool = true,
         showHorizon: Bool = true,
         onPause: @escaping () -> Void = {},
         onComplete: @escaping (PlayResult) -> Void = { _ in }) {
        self.background = background
        self.holdLimit = holdLimit
        self.raidSeconds = raidSeconds
        self.raidNumber = raidNumber
        self.initialLives = initialLives
        self.initialRack = initialRack
        self.cumulativeScoreBase = cumulativeScoreBase
        self.loadout = loadout
        self.modifiers = modifiers
        self.initialZap = initialZap
        self.initialWild = initialWild
        self.showHorizon = showHorizon
        self.onPause = onPause
        self.onComplete = onComplete
        _engine = StateObject(wrappedValue: ShooterEngine(
            holdLimit: holdLimit,
            raidSeconds: raidSeconds,
            raidNumber: raidNumber,
            initialLives: initialLives,
            // Cap maxLives at the modifier's lives so the LivesIndicator shows
            // the right denominator on puzzles like Glass Cannon (1 life).
            maxLives: modifiers.lives,
            initialRack: initialRack,
            loadout: loadout,
            modifiers: modifiers,
            initialZap: initialZap,
            initialWild: initialWild,
            allowContinue: allowContinue,
            onComplete: onComplete
        ))
    }

    var body: some View {
        PhoneShell(hasBg: true) {
            ZStack {
                // Background layer fills the entire screen (behind the HUD
                // insets too) — the safeAreaInset modifier below only reshapes
                // the stage area, not the background.
                GameBackground(variant: background)
                if showHorizon && background == .cosmos {
                    HorizonGrid(opacity: 0.4)
                }

                // The playable stage occupies the middle band between the
                // top HUD (PAUSE + LIVES + COINS + rack strip) and the bottom
                // powerup row. safeAreaInset reserves space for each, so the
                // GeometryReader inside only sees that middle band — the
                // 390×844 design stage stretches to fill it exactly with
                // independent X/Y scale. No more overlaps with the rack at
                // the top, no more empty gap above the powerups at the bottom.
                GeometryReader { geo in
                    // Uniform scale: same factor for X and Y so the letter
                    // tiles and ship sprite stay square. Use min of the two
                    // candidate scales so the entire playable region fits.
                    // The playable region is `topMargin` (just above the
                    // highest tier-5 spawn at y=40) down to shipY+30. Scaling
                    // this band, then offsetting upward by topMargin*scale,
                    // pins design y=topMargin to the top of the band — no
                    // dead space under the rack strip. Some devices will see
                    // small horizontal margins or a small bottom gap; the
                    // alternative is squished tiles.
                    let topMargin: CGFloat = 30
                    let playableHeight: CGFloat = engine.shipY + 30 - topMargin
                    let scaleX = geo.size.width / engine.stageWidth
                    let scaleY = geo.size.height / playableHeight
                    let scale = min(scaleX, scaleY)
                    stageView
                        .frame(width: engine.stageWidth, height: engine.stageHeight)
                        .scaleEffect(scale, anchor: .top)
                        .offset(y: -topMargin * scale)
                        // Outer frame matching geo so the scaled stage is
                        // centered horizontally regardless of which axis was
                        // the limiting factor.
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                        .onAppear { stageSize = geo.size }
                        .onChange(of: geo.size) { _, new in stageSize = new }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    VStack(spacing: 6) {
                        topHud
                        rackStrip
                    }
                    .padding(.top, 8)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    powerupRow
                        .padding(.bottom, 4)
                }

                if engine.hitFlash > 0 {
                    Rectangle()
                        .fill(Theme.red.opacity(0.25))
                        .ignoresSafeArea()
                        .opacity(engine.hitFlash / 350)
                        .allowsHitTesting(false)
                }

                // Scanlines are rendered globally in RootView so they
                // sit above every screen — not just gameplay.

                if showingPauseMenu {
                    pauseOverlay
                        .transition(.opacity)
                }

                if engine.pendingContinue {
                    LifePurchasePrompt(
                        mode: .inRaid,
                        onBuy: { count in engine.applyContinue(count: count) },
                        onDecline: { engine.declineContinue() },
                        onGetCoins: { showingCoinStore = true }
                    )
                    .transition(.opacity)
                }

                if showingPhase1Tutorial {
                    Phase1TutorialOverlay {
                        Haptics.impact(.light)
                        seenPhase1Tutorial = true
                        showingPhase1Tutorial = false
                        engine.paused = false
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: showingPauseMenu)
            .animation(.easeInOut(duration: 0.2), value: showingPhase1Tutorial)
            .animation(.easeInOut(duration: 0.2), value: engine.pendingContinue)
            .sheet(isPresented: $showingCoinStore) {
                CoinStoreSheet { showingCoinStore = false }
            }
            .onAppear {
                // First-ever Phase 1: pause the engine before any frames
                // tick and show the controls/power-ups tutorial. Dismiss
                // marks the flag so subsequent raids run straight through.
                if !seenPhase1Tutorial {
                    engine.paused = true
                    showingPhase1Tutorial = true
                }
            }
        }
        // Drive the simulation in lockstep with SwiftUI's render loop. The
        // `TimelineView(.animation)` schedule fires synchronised with the
        // display refresh (vsync), which is what makes the falling letters
        // and bullets read as smooth. A Combine Timer.publish drifts
        // relative to vsync and produces visible jitter.
        //
        // Note: this triggers an "onChange(of: Date) action tried to update
        // multiple times per frame" warning at runtime — that's accepted
        // noise. engine.tick deliberately mutates many @Published values
        // each frame, which is exactly the kind of state-churn SwiftUI 17+
        // flags. The alternatives (task(id:), Combine timer, manual
        // CADisplayLink) either fail to sync to vsync or add their own
        // scheduling layer that hurts smoothness.
        .background(
            TimelineView(.animation) { ctx in
                Color.clear.onChange(of: ctx.date) { _, newDate in
                    engine.tick(newDate.timeIntervalSince1970)
                }
            }
        )
    }

    // MARK: stage (in 390-wide design coordinates)
    private var stageView: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            // Bunkers
            ForEach(engine.bunkers) { bunker in
                BunkerView(bunker: bunker)
                    .frame(width: bunker.width, height: bunker.height)
                    .position(x: bunker.originX + bunker.width / 2,
                              y: bunker.originY + bunker.height / 2)
            }

            // Falling letters — subtle jiggle (small rotation + horizontal
            // sway) driven by their own falling y so each tile wobbles as it
            // descends. Phase derives from the tile's UUID so the cluster
            // doesn't move in sync. Visual only: collision math still uses
            // `l.x` so the actual hit position is unchanged.
            ForEach(engine.letters) { l in
                LetterTile(
                    letter: l.letter, value: l.value, tier: l.tier,
                    size: 36, wild: l.wild, state: .falling, pulse: 0.5
                )
                .rotationEffect(.degrees(letterJiggleAngle(l)))
                .position(x: l.x + letterJiggleSway(l), y: l.y)
            }

            // Flyby wildcard — UFO saucer that scrolls across the top.
            // Deliberately distinct from the square gold ★ wildcard tiles you
            // collect in the rack, so it reads as a special bonus prize.
            if let fb = engine.flyby {
                FlybyUFOView(direction: fb.vx > 0 ? 1 : -1)
                    .position(x: fb.x, y: fb.y)
            }

            // Enemy bombs
            ForEach(engine.bombs) { b in
                Bomb(color: Theme.red)
                    .position(x: b.x, y: b.y)
            }

            // Particles
            ForEach(engine.particles) { p in
                let alpha = p.t / p.life
                Circle()
                    .fill(p.color)
                    .frame(width: 4, height: 4)
                    .opacity(alpha)
                    .shadow(color: p.color, radius: 4)
                    .position(x: p.x, y: p.y)
            }

            // Friendly bullets
            ForEach(engine.bullets) { b in
                Bullet(color: Theme.cyan)
                    .position(x: b.x, y: b.y)
            }

            // Ship
            ZStack {
                if engine.wildArmed {
                    Circle()
                        .stroke(Theme.yellow.opacity(0.75), lineWidth: 1.5)
                        .frame(width: 60, height: 60)
                        .shadow(color: Theme.yellow.opacity(0.6), radius: 18)
                }
                Ship(size: 44, color: loadout.body, accent: loadout.accent)
                    .opacity(engine.hitFlash > 0 ? 0.55 : 1.0)
            }
            .position(x: engine.shipX, y: engine.shipY)

            if engine.zapFx > 0 {
                RadialGradient(
                    gradient: Gradient(colors: [Theme.yellow.opacity(0.45), .clear]),
                    center: .center, startRadius: 30, endRadius: 280
                )
                .frame(width: engine.stageWidth, height: 480)
                .opacity(engine.zapFx / 600)
                .position(x: engine.stageWidth / 2, y: 380)
                .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    // Promote to drag only after the finger has moved a few points.
                    // Until then, treat the touch as a tap and DON'T move the ship —
                    // so tapping anywhere fires from the ship's current position.
                    if !dragMoved {
                        let total = abs(v.translation.width) + abs(v.translation.height)
                        if total > 6 { dragMoved = true }
                    }
                    if dragMoved {
                        // The gesture is attached inside `stageView` (before
                        // the .scaleEffect applied by the body), so `v.location`
                        // is already in design coordinates (0…stageWidth).
                        // No scale conversion needed.
                        engine.setTarget(v.location.x)
                    }
                }
                .onEnded { _ in
                    if !dragMoved { engine.fire() }
                    dragMoved = false
                }
        )
    }

    // Small coin chip used in the HUD and pause overlay.
    private var coinChip: some View {
        HStack(spacing: 4) {
            Circle().fill(Theme.yellow).frame(width: 8, height: 8)
                .shadow(color: Theme.yellow, radius: 3)
            Text("\(coins)")
                .font(AppFont.mono(11, weight: .bold))
                .foregroundColor(Theme.yellow)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.4))
                .overlay(Capsule().stroke(Theme.yellow.opacity(0.35), lineWidth: 1))
        )
    }

    // MARK: Falling-letter jiggle
    //
    // Tiny rotation + horizontal sway driven by the letter's current y so
    // the wobble auto-animates as it falls (engine republishes letters every
    // frame). Phase is derived from the tile UUID so each letter wobbles on
    // its own beat. Amplitudes are small (±3.5°, ±2pt) — visible but easy
    // on the eyes.

    /// Stable 0…2π phase per letter — different per tile so the field
    /// doesn't wobble in lockstep.
    private func letterPhase(_ l: FallingLetter) -> Double {
        Double(abs(l.id.hashValue) % 1000) / 1000.0 * .pi * 2
    }

    private func letterJiggleAngle(_ l: FallingLetter) -> Double {
        sin(Double(l.y) * 0.05 + letterPhase(l)) * 3.5
    }

    private func letterJiggleSway(_ l: FallingLetter) -> CGFloat {
        CGFloat(cos(Double(l.y) * 0.05 + letterPhase(l))) * 2
    }

    // MARK: Pause overlay

    private var pauseOverlay: some View {
        ZStack {
            // Dim + block touches to the game beneath. Don't dismiss on tap-out:
            // a mis-tap shouldn't drop the player back into a hostile bullet wave.
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { /* swallow */ }

            VStack(spacing: 14) {
                Text("PAUSED")
                    .font(AppFont.mono(11, weight: .bold))
                    .tracking(3.2)
                    .foregroundColor(Color.white.opacity(0.6))

                Text("RAID \(raidNumber)")
                    .font(AppFont.display(40, weight: .bold))
                    .foregroundStyle(LinearGradient(
                        colors: [Theme.cyan, Theme.violet],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .shadow(color: Theme.cyan.opacity(0.4), radius: 20)

                VStack(spacing: 4) {
                    Text("\((cumulativeScoreBase + engine.score)) PTS")
                        .font(AppFont.display(28, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: Theme.cyan.opacity(0.4), radius: 10)
                    Text("+\(engine.score) THIS RAID · LIVES \(engine.lives)/\(engine.maxLives)")
                        .font(AppFont.mono(10, weight: .regular))
                        .tracking(2.2)
                        .foregroundColor(Color.white.opacity(0.55))
                    coinChip
                        .padding(.top, 6)
                }
                .padding(.bottom, 10)

                Button {
                    GameAudio.shared.play("ui_back")
                    Haptics.impact(.medium)
                    showingPauseMenu = false
                    engine.paused = false
                } label: {
                    Text("RESUME")
                        .font(AppFont.mono(13, weight: .semibold))
                        .tracking(2.6)
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(LinearGradient(
                                    colors: [Theme.cyan.opacity(0.35), Theme.violet.opacity(0.3)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cyan.opacity(0.5), lineWidth: 1.5))
                        )
                        .shadow(color: Theme.cyan.opacity(0.4), radius: 12)
                }
                .buttonStyle(.plain)

                Button {
                    GameAudio.shared.play("ui_back")
                    Haptics.notify(.warning)
                    // QUIT abandons the run; RootView treats this as Mission Aborted.
                    showingPauseMenu = false
                    onPause()
                } label: {
                    Text("ABORT MISSION")
                        .font(AppFont.mono(12, weight: .semibold))
                        .tracking(2.4)
                        .foregroundColor(Color.white.opacity(0.75))
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.05))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(26)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient(
                        colors: [Color(hex: 0x1A0B2E).opacity(0.92), Color(hex: 0x0C0729).opacity(0.92)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.violet.opacity(0.4), lineWidth: 1.5))
                    .shadow(color: Theme.violet.opacity(0.5), radius: 40)
            )
            .padding(.horizontal, 28)
        }
    }

    // MARK: First-Phase-1 tutorial overlay
    //
    // Shown ONCE per install when the player enters Phase 1 for the first
    // time. Walks through how to move, fire, and use ZAP / WILD. While
    // visible, `engine.paused` is true so nothing on the field moves —
    // the player can read at their own pace.

    /// Standalone view so we can swap content/styling without bloating the
    /// PlayScreen body. Caller passes a dismiss closure that's invoked on
    /// the GOT IT button.
    @ViewBuilder
    private func Phase1TutorialOverlay(onDismiss: @escaping () -> Void) -> some View {
        ZStack {
            // Dim + block underlying gestures. Tap-out is intentionally
            // not a dismiss — the player should read and then explicitly
            // confirm so the controls land.
            Color.black.opacity(0.78)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { /* swallow */ }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HOW TO PLAY · PHASE 1")
                        .font(AppFont.mono(10, weight: .bold))
                        .tracking(2.6)
                        .foregroundColor(Theme.cyanSoft)
                    Text("Capture letters")
                        .font(AppFont.display(26, weight: .bold))
                        .kerning(-0.6)
                        .foregroundColor(.white)
                }

                tutorialRow(icon: "hand.draw.fill",
                            tint: Theme.cyan,
                            title: "DRAG",
                            body: "Drag anywhere on screen. Your ship glides toward your finger.")
                tutorialRow(icon: "hand.tap.fill",
                            tint: Theme.cyan,
                            title: "TAP",
                            body: "Tap to fire a bullet straight up. Hit a falling tile to capture it.")
                tutorialRow(icon: "bolt.fill",
                            tint: Theme.yellow,
                            title: "ZAP",
                            body: "Instantly captures every letter on screen. Earned and bought charges persist between runs.")
                tutorialRow(icon: "star.fill",
                            tint: Theme.pinkSoft,
                            title: "WILD",
                            body: "Arms your ship — your next capture becomes a wildcard ★ usable as any letter.")

                Button(action: onDismiss) {
                    Text("GOT IT")
                        .font(AppFont.mono(13, weight: .semibold))
                        .tracking(2.6)
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(LinearGradient(colors: [Theme.cyan.opacity(0.4), Theme.violet.opacity(0.3)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cyan.opacity(0.5), lineWidth: 1.5))
                        )
                        .shadow(color: Theme.cyan.opacity(0.4), radius: 12)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(22)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient(colors: [Color(hex: 0x1A0B2E).opacity(0.95), Color(hex: 0x0C0729).opacity(0.95)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.violet.opacity(0.4), lineWidth: 1.5))
                    .shadow(color: Theme.violet.opacity(0.5), radius: 40)
            )
            .padding(.horizontal, 24)
        }
    }

    /// One bullet row in a tutorial card — colored icon coin + bold label +
    /// description. Used by both phase tutorials so they look consistent.
    private func tutorialRow(icon: String, tint: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tint.opacity(0.18))
                    .frame(width: 36, height: 36)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(tint.opacity(0.45), lineWidth: 1))
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(tint)
                    .shadow(color: tint.opacity(0.55), radius: 6)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.mono(11, weight: .bold))
                    .tracking(1.8)
                    .foregroundColor(.white)
                Text(body)
                    .font(AppFont.mono(11.5, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: HUD

    private var topHud: some View {
        let timeLeft = max(0, engine.raidMs / 1000)
        let pct = max(0, min(1, engine.raidMs / (raidSeconds * 1000)))
        let danger = pct < 0.25
        return HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        GameAudio.shared.play("ui_back")
                        Haptics.impact(.light)
                        engine.paused = true
                        showingPauseMenu = true
                    } label: {
                        Text("‖ PAUSE")
                            .font(AppFont.mono(11, weight: .semibold))
                            .tracking(2)
                            .foregroundColor(Color.white.opacity(0.7))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.4)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1)))
                    }
                    .buttonStyle(.plain)

                    LivesIndicator(lives: engine.lives, max: engine.maxLives)

                    coinChip
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("RAID \(raidNumber)")
                        .font(AppFont.mono(9, weight: .regular))
                        .tracking(2)
                        .foregroundColor(Color.white.opacity(0.55))
                    Text("\(cumulativeScoreBase + engine.score)")
                        .font(AppFont.display(22, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: Theme.cyan.opacity(0.4), radius: 8)
                    if engine.score > 0 {
                        Text("+\(engine.score) RAID")
                            .font(AppFont.mono(8, weight: .regular))
                            .tracking(1.6)
                            .foregroundColor(Theme.cyan.opacity(0.75))
                    }
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("TIME")
                        .font(AppFont.mono(9, weight: .regular))
                        .tracking(2)
                        .foregroundColor(Color.white.opacity(0.55))
                    Text(String(format: "%.1fs", timeLeft))
                        .font(AppFont.mono(16, weight: .bold))
                        .foregroundColor(danger ? Theme.red : .white)
                    Capsule().fill(Color.white.opacity(0.1)).frame(width: 70, height: 3)
                        .overlay(
                            GeometryReader { g in
                                Capsule().fill(danger ? Theme.red : Theme.cyan)
                                    .frame(width: g.size.width * pct)
                                    .shadow(color: danger ? Theme.red : Theme.cyan, radius: 3)
                            }
                        )
                }
                .frame(width: 78)
            }
            .padding(.horizontal, 16)
    }

    private var rackStrip: some View {
        HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("LETTERS")
                        .font(AppFont.mono(9, weight: .regular))
                        .tracking(2)
                        .foregroundColor(Color.white.opacity(0.55))
                    Text("\(engine.rack.count)/\(holdLimit)")
                        .font(AppFont.mono(12, weight: .bold))
                        .foregroundColor(engine.rack.count >= holdLimit - 1 ? Theme.red : .white)
                }
                Spacer()
                // Tile size dropped to 22pt so all 10 slots fit comfortably across
                // the rack strip. Values hidden on these tiles — they're already
                // tiny and the pip noise distracts from the count read.
                HStack(spacing: 3) {
                    ForEach(0..<max(0, holdLimit - engine.rack.count), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .frame(width: 22, height: 22)
                    }
                    ForEach(engine.rack) { t in
                        LetterTile(letter: t.wild ? "★" : t.letter, value: t.value, tier: t.tier, size: 22, wild: t.wild, showValue: false)
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: 0x06031A).opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(engine.rack.count >= holdLimit - 1 ? Theme.red.opacity(0.45) : Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: engine.rack.count >= holdLimit - 1 ? Theme.red.opacity(0.35) : .clear, radius: 12)
            )
            .padding(.horizontal, 14)
    }

    private var powerupRow: some View {
        VStack(spacing: 8) {
            // Combo chip is rendered ALWAYS so it claims layout space even
            // when inactive — otherwise the safeAreaInset shrinks and the
            // stage shifts every time a combo starts/expires.
            Text("COMBO ×\(1 + engine.combo / 2)")
                .font(AppFont.mono(11, weight: .regular))
                .tracking(2)
                .foregroundColor(Theme.pinkSoft)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(
                    Capsule().fill(Theme.pink.opacity(0.18))
                        .overlay(Capsule().stroke(Theme.pink.opacity(0.4), lineWidth: 1))
                )
                .opacity(engine.combo > 1 ? 1 : 0)
            HStack(spacing: 10) {
                PowerButton(label: "ZAP", icon: "bolt.fill", charges: engine.zapCharges, active: engine.zapFx > 0, color: Theme.yellow) {
                    engine.activateZap()
                }
                Text("DRAG · TAP TO FIRE")
                    .font(AppFont.mono(10, weight: .regular))
                    .tracking(1.8)
                    .foregroundColor(Color.white.opacity(0.55))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color.black.opacity(0.4))
                            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    )
                PowerButton(label: "WILD", icon: "star.fill", charges: engine.wildCharges, active: engine.wildArmed, color: Theme.pinkSoft) {
                    engine.armWild()
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 4)
        }
    }
}

// MARK: - Flyby UFO

/// The scrolling bonus wildcard — drawn as a neon UFO saucer so it doesn't
/// look like a regular ★ tile. Tap to capture it as a wildcard in the rack.
struct FlybyUFOView: View {
    /// +1 if heading right, -1 if heading left (slight forward tilt).
    var direction: Double = 1

    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            // Outer halo
            Capsule()
                .fill(Theme.violet.opacity(0.5))
                .frame(width: 92, height: 28)
                .blur(radius: 14)

            // Saucer body — flattened ellipse with a metallic gradient
            Ellipse()
                .fill(LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Theme.cyanSoft,    location: 0.0),
                        .init(color: Theme.cyan,        location: 0.45),
                        .init(color: Theme.violet,      location: 0.85),
                        .init(color: Color(hex: 0x1F0F4D), location: 1.0),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 66, height: 18)
                .overlay(
                    Ellipse()
                        .stroke(Theme.cyanSoft.opacity(0.9), lineWidth: 1)
                )
                .shadow(color: Theme.violet.opacity(0.7), radius: 8)

            // Equatorial rim highlight
            Capsule()
                .fill(Color.white.opacity(0.7))
                .frame(width: 50, height: 1.5)
                .blur(radius: 0.6)
                .offset(y: -2)

            // Dome with the mystery ★
            ZStack {
                Ellipse()
                    .fill(RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.95),
                            Theme.cyanSoft.opacity(0.8),
                            Theme.cyan.opacity(0.5),
                        ]),
                        center: .init(x: 0.35, y: 0.25),
                        startRadius: 1,
                        endRadius: 16
                    ))
                    .frame(width: 28, height: 20)
                    .overlay(
                        Ellipse().stroke(Color.white.opacity(0.7), lineWidth: 1)
                    )

                Text("★")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(Theme.pink)
                    .shadow(color: Theme.pink.opacity(0.85), radius: 4)
                    .scaleEffect(pulse ? 1.15 : 1.0)
            }
            .offset(y: -8)

            // Underside thruster lights
            HStack(spacing: 7) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i % 2 == 0 ? Theme.yellow : Theme.pinkSoft)
                        .frame(width: 3.5, height: 3.5)
                        .shadow(color: i % 2 == 0 ? Theme.yellow : Theme.pinkSoft, radius: 4)
                        .opacity(pulse ? 1.0 : 0.55)
                }
            }
            .offset(y: 9)
        }
        .frame(width: 92, height: 44)
        .rotationEffect(.degrees(direction > 0 ? 5 : -5))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Bunker view

struct BunkerView: View {
    let bunker: BunkerData

    var body: some View {
        Canvas { ctx, _ in
            let rows = bunker.rows
            let cols = bunker.cols
            let cs = bunker.cellSize

            for r in 0..<rows {
                for c in 0..<cols {
                    guard bunker.cells[r][c] else { continue }
                    let rect = CGRect(
                        x: CGFloat(c) * cs,
                        y: CGFloat(r) * cs,
                        width: cs, height: cs
                    )

                    // Depth: top rows brighter teal, bottom rows deeper emerald.
                    // Reads as a lit voxel mass instead of a flat 2D shape.
                    let depth = rows > 1 ? CGFloat(r) / CGFloat(rows - 1) : 0
                    let top = Color(hex: 0x6EE7C8)   // light mint highlight
                    let bot = Color(hex: 0x047857)   // deep emerald shadow
                    let body = top.blended(with: bot, t: depth)
                    ctx.fill(Path(rect), with: .color(body))

                    // Per-cell top half wash → fakes a vertical gradient so each
                    // voxel has its own highlight without paying for a real gradient fill.
                    let topHalf = CGRect(x: rect.minX, y: rect.minY,
                                         width: rect.width, height: rect.height * 0.5)
                    ctx.fill(Path(topHalf), with: .color(Color.white.opacity(0.14)))

                    let botHalf = CGRect(x: rect.minX, y: rect.midY,
                                         width: rect.width, height: rect.height * 0.5)
                    ctx.fill(Path(botHalf), with: .color(Color.black.opacity(0.18 + depth * 0.10)))

                    // Edge lighting: any cell face exposed to empty space gets a
                    // bevel. Top/left = highlight (lit from above-left); bottom/right
                    // = shadow. Adjacency-checked so internal cell borders stay flush.
                    let topExposed = r == 0 || !bunker.cells[r - 1][c]
                    let botExposed = r == rows - 1 || !bunker.cells[r + 1][c]
                    let leftExposed = c == 0 || !bunker.cells[r][c - 1]
                    let rightExposed = c == cols - 1 || !bunker.cells[r][c + 1]

                    if topExposed {
                        ctx.fill(
                            Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 1)),
                            with: .color(Color.white.opacity(0.65))
                        )
                    }
                    if leftExposed {
                        ctx.fill(
                            Path(CGRect(x: rect.minX, y: rect.minY, width: 1, height: rect.height)),
                            with: .color(Color.white.opacity(0.28))
                        )
                    }
                    if botExposed {
                        ctx.fill(
                            Path(CGRect(x: rect.minX, y: rect.maxY - 1, width: rect.width, height: 1)),
                            with: .color(Color.black.opacity(0.55))
                        )
                    }
                    if rightExposed {
                        ctx.fill(
                            Path(CGRect(x: rect.maxX - 1, y: rect.minY, width: 1, height: rect.height)),
                            with: .color(Color.black.opacity(0.32))
                        )
                    }
                }
            }
        }
        // Layered glow — tight green core, soft cyan halo. Matches the
        // multi-layer shadow treatment used on letter tiles + the ship.
        .shadow(color: Theme.green.opacity(0.85), radius: 3)
        .shadow(color: Theme.green.opacity(0.45), radius: 10)
        .shadow(color: Theme.cyan.opacity(0.25), radius: 22)
    }
}

private extension Color {
    /// Lerp between two colors in sRGB; `t` in 0...1.
    func blended(with other: Color, t: CGFloat) -> Color {
        let tt = max(0, min(1, t))
        #if canImport(UIKit)
        let a = UIColor(self), b = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(
            red: Double(r1 + (r2 - r1) * tt),
            green: Double(g1 + (g2 - g1) * tt),
            blue: Double(b1 + (b2 - b1) * tt),
            opacity: Double(a1 + (a2 - a1) * tt)
        )
        #else
        return tt < 0.5 ? self : other
        #endif
    }
}

// MARK: - Lives indicator

struct LivesIndicator: View {
    let lives: Int
    let max: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max, id: \.self) { i in
                let alive = i < lives
                Image(systemName: "airplane")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(alive ? Theme.cyan : Color.white.opacity(0.18))
                    .shadow(color: alive ? Theme.cyan.opacity(0.7) : .clear, radius: 4)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.4))
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        )
    }
}

// MARK: - Power button

struct PowerButton: View {
    let label: String
    let icon: String
    let charges: Int
    let active: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16, weight: .bold))
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(AppFont.mono(10, weight: .regular))
                        .tracking(1.8)
                        .foregroundColor(Color.white.opacity(0.55))
                    Text("×\(charges)")
                        .font(AppFont.mono(12, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(active ? color.opacity(0.33) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(charges > 0 ? color.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .opacity(charges > 0 ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(charges <= 0)
    }
}

// MARK: - LifePurchasePrompt
//
// Shared overlay used in two places:
//   • PlayScreen, when the ship is destroyed mid-raid and the player can
//     afford at least one life — pauses the engine and lets the player
//     pick how many lives to buy (1, 2, or 3, capped by coin balance).
//   • RootView, when the player taps Launch Mission with Hangar.lifeStock
//     at 0 — gates the run on a purchase (or a NOT NOW decline).
//
// Caller wires `onBuy(count:)` and `onDecline()` to handle coin deduction,
// life persistence, and follow-on flow (resume raid vs. start run). The
// prompt itself never mutates state — it just gathers the player's intent.
struct LifePurchasePrompt: View {
    enum Mode { case inRaid, preLaunch }

    let mode: Mode
    let onBuy: (Int) -> Void
    let onDecline: () -> Void
    var onGetCoins: (() -> Void)? = nil

    @AppStorage(Hangar.coinKey) private var coins: Int = Hangar.startingCoins

    var body: some View {
        ZStack {
            Color.black.opacity(0.78)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { /* swallow */ }

            VStack(spacing: 14) {
                Text(mode == .inRaid ? "SHIP DESTROYED" : "OUT OF LIVES")
                    .font(AppFont.mono(11, weight: .bold))
                    .tracking(3.2)
                    .foregroundColor(Theme.red)

                Text(mode == .inRaid ? "CONTINUE?" : "REFUEL?")
                    .font(AppFont.display(36, weight: .bold))
                    .foregroundStyle(LinearGradient(
                        colors: [Theme.red, Theme.amber],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .shadow(color: Theme.red.opacity(0.4), radius: 20)

                Text(mode == .inRaid
                     ? "Buy lives to keep this mission going."
                     : "You need at least 1 life to launch a mission.")
                    .font(AppFont.display(13, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Circle().fill(Theme.yellow).frame(width: 8, height: 8)
                        .shadow(color: Theme.yellow, radius: 3)
                    Text("\(coins) COINS")
                        .font(AppFont.mono(10, weight: .bold))
                        .tracking(1.6)
                        .foregroundColor(Theme.yellow)
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Theme.yellow.opacity(0.12))
                        .overlay(Capsule().stroke(Theme.yellow.opacity(0.3), lineWidth: 1))
                )
                .padding(.top, 4)

                VStack(spacing: 8) {
                    ForEach(1...Hangar.maxLives, id: \.self) { n in
                        buyButton(count: n)
                    }
                }
                .padding(.top, 6)

                if coins < Hangar.lifePrice, let onGetCoins {
                    Button {
                        Haptics.select()
                        onGetCoins()
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Theme.yellow)
                                .frame(width: 9, height: 9)
                                .shadow(color: Theme.yellow, radius: 4)
                            Text("GET COINS")
                                .font(AppFont.mono(12, weight: .bold))
                                .tracking(2.4)
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Theme.yellow.opacity(0.16))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.yellow.opacity(0.4), lineWidth: 1.2))
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    Haptics.notify(.warning)
                    onDecline()
                } label: {
                    Text(mode == .inRaid ? "GIVE UP" : "NOT NOW")
                        .font(AppFont.mono(12, weight: .semibold))
                        .tracking(2.4)
                        .foregroundColor(Color.white.opacity(0.7))
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.05))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .padding(22)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient(
                        colors: [Color(hex: 0x2A0B1E).opacity(0.95), Color(hex: 0x0C0729).opacity(0.95)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.red.opacity(0.45), lineWidth: 1.5))
                    .shadow(color: Theme.red.opacity(0.45), radius: 40)
            )
            .padding(.horizontal, 28)
        }
    }

    private func buyButton(count: Int) -> some View {
        let cost = Hangar.lifePrice * count
        let canAfford = coins >= cost
        let title = count == 1 ? "1 LIFE" : "\(count) LIVES"
        return Button {
            guard canAfford else {
                Haptics.notify(.warning)
                return
            }
            Haptics.notify(.success)
            onBuy(count)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(canAfford ? Theme.red : Color.white.opacity(0.35))
                Text(title)
                    .font(AppFont.mono(13, weight: .bold))
                    .tracking(2.4)
                    .foregroundColor(.white)
                Spacer(minLength: 6)
                Text("\(cost)")
                    .font(AppFont.mono(13, weight: .bold))
                    .foregroundColor(canAfford ? Theme.yellow : Color.white.opacity(0.35))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(canAfford
                          ? AnyShapeStyle(LinearGradient(
                              colors: [Theme.red.opacity(0.32), Theme.amber.opacity(0.22)],
                              startPoint: .topLeading, endPoint: .bottomTrailing))
                          : AnyShapeStyle(Color.white.opacity(0.04)))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(
                        canAfford ? Theme.red.opacity(0.5) : Color.white.opacity(0.08),
                        lineWidth: 1.2
                    ))
            )
            .opacity(canAfford ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!canAfford)
    }
}
