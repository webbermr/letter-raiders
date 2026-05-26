import Foundation

/// Persistent state for the daily-puzzle feature. UserDefaults-backed so the
/// daily screen, attempt gate, and streak chip all read the same values.
enum DailyState {
    // Keys are also referenced via @AppStorage in DailyScreen so the UI
    // refreshes automatically when DailyState mutates them.
    static let lastAttemptDayKey  = "dailyLastAttemptDay"   // String "YYYY-MM-DD"
    static let lastScoreKey       = "dailyLastScore"        // Int
    static let lastQualifiedKey   = "dailyLastQualified"    // Bool: submitted valid word
    static let streakKey          = "dailyStreak"           // Int
    static let streakLastDayKey   = "dailyStreakLastDay"    // String "YYYY-MM-DD"

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = .current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayString(_ date: Date = Date()) -> String {
        dayFormatter.string(from: date)
    }

    static var lastAttemptDay: String {
        UserDefaults.standard.string(forKey: lastAttemptDayKey) ?? ""
    }

    static var hasAttemptedToday: Bool {
        lastAttemptDay == dayString()
    }

    static var lastScore: Int {
        UserDefaults.standard.integer(forKey: lastScoreKey)
    }

    /// True if the player's last attempt qualified — i.e. they submitted a
    /// valid word during the run. Drives the streak update.
    static var lastQualified: Bool {
        UserDefaults.standard.bool(forKey: lastQualifiedKey)
    }

    static var streak: Int {
        UserDefaults.standard.integer(forKey: streakKey)
    }

    static var streakLastDay: String {
        UserDefaults.standard.string(forKey: streakLastDayKey) ?? ""
    }

    /// Record the outcome of today's attempt and (if qualified) bump the
    /// streak. Idempotent within the same day — a second call won't
    /// double-count, since `lastAttemptDay` already matches.
    ///
    /// Streak rule: counts only if the player submitted a valid word during
    /// the run. Missing a day resets the streak to 0; completing today after
    /// completing yesterday → +1.
    static func recordAttempt(score: Int, submittedValidWord: Bool) {
        let today = dayString()
        let d = UserDefaults.standard
        d.set(today, forKey: lastAttemptDayKey)
        d.set(score, forKey: lastScoreKey)
        d.set(submittedValidWord, forKey: lastQualifiedKey)

        guard submittedValidWord else { return }

        let last = streakLastDay
        let current = streak
        if last == today {
            // Already counted today; nothing to do.
            return
        }
        let yesterday = dayString(Date().addingTimeInterval(-86_400))
        if last == yesterday {
            d.set(current + 1, forKey: streakKey)
        } else {
            // Either first ever (last == "") or a missed day (gap > 1).
            d.set(1, forKey: streakKey)
        }
        d.set(today, forKey: streakLastDayKey)
    }
}
