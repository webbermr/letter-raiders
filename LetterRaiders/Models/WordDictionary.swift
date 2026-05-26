import Foundation

/// Word validation backed by the ENABLE1 word list (~172k words).
/// The file ships in the app bundle as `enable1.txt` and is loaded lazily on
/// first access. `preload()` can be called at launch on a background queue to
/// avoid the small one-time cost when the user first reaches the Word screen.
final class WordDictionary {
    static let shared = WordDictionary()

    private let lock = NSLock()
    private var words: Set<String>? = nil
    private var loading = false

    private init() {}

    /// Trigger a background load so the dictionary is ready by the time
    /// the player needs it. Safe to call multiple times.
    func preload() {
        lock.lock()
        if loading || words != nil { lock.unlock(); return }
        loading = true
        lock.unlock()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            _ = self?.load()
        }
    }

    func isValid(_ s: String) -> Bool {
        guard s.count >= 2 else { return false }
        let set = load()
        return set.contains(s.lowercased())
    }

    @discardableResult
    private func load() -> Set<String> {
        lock.lock()
        if let cached = words { lock.unlock(); return cached }
        lock.unlock()

        let parsed = WordDictionary.parseBundledList()

        lock.lock()
        words = parsed
        loading = false
        lock.unlock()
        return parsed
    }

    private static func parseBundledList() -> Set<String> {
        guard let url = Bundle.main.url(forResource: "enable1", withExtension: "txt"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            assertionFailure("enable1.txt missing from app bundle")
            return []
        }
        var set = Set<String>()
        set.reserveCapacity(180_000)
        text.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { set.insert(trimmed.lowercased()) }
        }
        return set
    }
}
