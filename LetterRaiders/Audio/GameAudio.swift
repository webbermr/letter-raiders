import Foundation
import AVFoundation
import UIKit

/// Game audio engine — mirrors the prototype's `window.gameAudio`:
///   • named sounds with per-sound presets (gain, pitch, jitter, polyphony…)
///   • pitch shift via AVAudioPlayer's `rate` (pitch + speed couple; fine for
///     short SFX and avoids the AVAudioEngine format-matching minefield)
///   • rate-limiting and polyphony caps so rapid events don't clip
///   • Settings → Music / SFX `@AppStorage` toggles honoured
///   • Audio session activates lazily on the first `play()`
@MainActor
final class GameAudio {
    static let shared = GameAudio()

    // MARK: - Configuration

    struct Preset {
        var file: String          // basename in Audio/sfx/ (no extension)
        var gain: Float = 0.6
        var pitch: Float = 0      // semitones (base offset)
        var pitchJitter: Float = 0 // semitones (±)
        var duck: Bool = false
        var minIntervalMs: Int = 0
        var polyphony: Int = 4
    }

    struct PlayOpts {
        var gain: Float? = nil
        var pitch: Float? = nil
        var pitchJitter: Float? = nil
        var duck: Bool? = nil
        var minIntervalMs: Int? = nil

        static let `default` = PlayOpts()
    }

    private let presets: [String: Preset] = [
        // Shooter
        "shoot":      Preset(file: "shoot",      gain: 0.42, pitchJitter: 2, polyphony: 4),
        "hit_a":      Preset(file: "hit_a",      gain: 0.55, pitchJitter: 2, polyphony: 4),
        "hit_b":      Preset(file: "hit_b",      gain: 0.55, pitchJitter: 2, polyphony: 4),
        "combo":      Preset(file: "combo",      gain: 0.35, polyphony: 6),
        "bomb":       Preset(file: "bomb",       gain: 0.28, pitch: -3, pitchJitter: 1, minIntervalMs: 120, polyphony: 4),
        "ufo_kill":   Preset(file: "ufo_kill",   gain: 0.7,  duck: true,  polyphony: 2),
        "wild_armed": Preset(file: "wild_armed", gain: 0.5,  polyphony: 2),
        "rack_full":  Preset(file: "rack_full",  gain: 0.62, duck: true,  polyphony: 2),
        "ufo_in":     Preset(file: "ufo_in",     gain: 0.45, polyphony: 2),
        "shield":     Preset(file: "shield",     gain: 0.45, polyphony: 2),
        "triple":     Preset(file: "triple",     gain: 0.55, polyphony: 2),
        "player_hit": Preset(file: "player_hit", gain: 0.7,  duck: true,  polyphony: 3),
        "game_over":  Preset(file: "game_over",  gain: 0.85, pitch: -2, duck: true, polyphony: 1),

        // Word screen
        "tile_tap":     Preset(file: "tile_tap",     gain: 0.55, pitchJitter: 1.5, minIntervalMs: 30, polyphony: 4),
        "tile_remove":  Preset(file: "tile_remove",  gain: 0.4,  pitchJitter: 1,   polyphony: 3),
        "shuffle":      Preset(file: "shuffle",      gain: 0.45, polyphony: 2),
        "wild_pick":    Preset(file: "wild_pick",    gain: 0.4,  polyphony: 2),
        "timer_tick":   Preset(file: "timer_tick",   gain: 0.4,  polyphony: 3),
        "submit_word":  Preset(file: "submit_word",  gain: 0.65, duck: true, polyphony: 1),
        "valid_word":   Preset(file: "valid_word",   gain: 0.5,  polyphony: 1),
        "invalid_word": Preset(file: "invalid_word", gain: 0.55, polyphony: 1),
        "score_tick":   Preset(file: "score_tick",   gain: 0.32, pitchJitter: 0.5, polyphony: 6),

        // UI
        "ui_tap":  Preset(file: "ui_tap",  gain: 0.45, minIntervalMs: 40, polyphony: 3),
        "ui_back": Preset(file: "ui_back", gain: 0.45, minIntervalMs: 40, polyphony: 3),
        "confirm": Preset(file: "confirm", gain: 0.55, polyphony: 2),
        "toggle":  Preset(file: "toggle",  gain: 0.4,  polyphony: 3),
    ]

    // MARK: - State

    /// `presets.file` → pool of AVAudioPlayers, each pre-loaded with the asset.
    /// Polyphony comes from cycling through idle players in the pool.
    private var pools: [String: [AVAudioPlayer]] = [:]
    private var lastPlayedAt: [String: Date] = [:]
    private var didActivate = false
    private var sessionConfigured = false

    // Looping background music.
    private var musicPlayer: AVAudioPlayer?
    private let musicTrackName = "Asteroid_Breach"
    private let musicTrackExt = "mp3"
    private let musicVolume: Float = 0.32   // leaves headroom for SFX

    private var sfxEnabled: Bool {
        UserDefaults.standard.object(forKey: "sfx") as? Bool ?? true
    }
    private var musicEnabled: Bool {
        UserDefaults.standard.object(forKey: "music") as? Bool ?? true
    }

    // MARK: - Init

    private init() {
        configureSession()
        loadPools()
        loadMusic()
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleForeground),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleBackground),
            name: UIApplication.willResignActiveNotification, object: nil
        )
        // Music is allowed to start immediately under `.ambient` — no
        // user-gesture unlock required for this session category.
        if musicEnabled { startMusic() }
    }

    private func loadMusic() {
        guard let url = Bundle.main.url(forResource: musicTrackName, withExtension: musicTrackExt) else {
            return
        }
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.numberOfLoops = -1          // infinite loop
        p.volume = musicVolume
        p.prepareToPlay()
        musicPlayer = p
    }

    private func configureSession() {
        guard !sessionConfigured else { return }
        sessionConfigured = true
        // `.ambient` mixes with other audio (Spotify keeps playing) and never
        // pauses other apps — the right category for an arcade game.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }

    private func loadPools() {
        for (_, preset) in presets {
            guard let url = Bundle.main.url(forResource: preset.file, withExtension: "caf") else {
                continue
            }
            var pool: [AVAudioPlayer] = []
            for _ in 0..<max(1, preset.polyphony) {
                if let player = try? AVAudioPlayer(contentsOf: url) {
                    player.enableRate = true       // must be set before prepareToPlay
                    player.numberOfLoops = 0
                    player.prepareToPlay()
                    pool.append(player)
                }
            }
            pools[preset.file] = pool
        }
    }

    /// Lazy session activation on first play.
    private func unlock() {
        guard !didActivate else { return }
        didActivate = true
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    @objc private func handleForeground() {
        try? AVAudioSession.sharedInstance().setActive(true)
        if musicEnabled, musicPlayer?.isPlaying == false {
            musicPlayer?.play()
        }
    }

    @objc private func handleBackground() {
        musicPlayer?.pause()
    }

    // MARK: - Music control

    /// Start (or resume) the looping background track. Call this when the
    /// player toggles music ON in Settings, or after first launch.
    func startMusic() {
        guard let p = musicPlayer else { return }
        p.volume = musicVolume
        if !p.isPlaying { p.play() }
    }

    /// Pause the background music — used when the user disables music in
    /// Settings. The track keeps its position so flipping back on resumes
    /// where it left off.
    func stopMusic() {
        musicPlayer?.pause()
    }

    /// Convenience for the Settings toggle.
    func setMusicEnabled(_ enabled: Bool) {
        if enabled { startMusic() } else { stopMusic() }
    }

    // MARK: - Public API

    /// Play a named sound. No-op if the user has SFX disabled in Settings.
    func play(_ name: String, opts: PlayOpts = .default) {
        guard sfxEnabled,
              let preset = presets[name],
              let pool = pools[preset.file],
              !pool.isEmpty else { return }

        // Rate-limit per name.
        let minIntervalMs = opts.minIntervalMs ?? preset.minIntervalMs
        if minIntervalMs > 0,
           let last = lastPlayedAt[name],
           Date().timeIntervalSince(last) * 1000 < Double(minIntervalMs) {
            return
        }
        lastPlayedAt[name] = Date()

        unlock()

        // Pick an idle player from the pool; fall back to stealing the
        // first one if every voice is busy (polyphony cap reached).
        let player = pool.first(where: { !$0.isPlaying }) ?? pool[0]
        if player.isPlaying { player.stop() }

        // Pitch via rate. AVAudioPlayer rate range is 0.5x..2x (±12 semis).
        let basePitch = opts.pitch ?? preset.pitch
        let jitter = opts.pitchJitter ?? preset.pitchJitter
        let jitterAmount = jitter == 0 ? 0 : Float.random(in: -jitter...jitter)
        let semitones = max(-12, min(18, basePitch + jitterAmount))   // clamp to AVAudioPlayer max
        let rate = pow(2.0, semitones / 12.0)
        player.rate = max(0.5, min(2.0, rate))

        player.volume = max(0, min(1, opts.gain ?? preset.gain))
        player.currentTime = 0
        player.play()
    }

    /// Combo helper — pitches the combo blip up 1.5 semis per step (cap +18).
    func combo(_ n: Int) {
        let semis = min(18, max(0, Float(n - 1) * 1.5))
        play("combo", opts: .init(pitch: semis))
    }

    /// Celebratory cue: confirm + 3-note ascending arpeggio of `combo`.
    func waveClear() {
        play("confirm")
        let delays: [(Double, Float)] = [(0.0, 0), (0.12, 4), (0.24, 7), (0.36, 12)]
        for (delay, semis) in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.play("combo", opts: .init(pitch: semis))
            }
        }
    }
}
