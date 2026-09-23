import Foundation
import CryptoKit

/// A small on-device cache of AI results, shared across the app and its extensions via the App
/// Group. The same input (same text, same system prompt, same model) returns the stored result
/// instead of calling the AI again, so re-translating an identical message costs nothing.
///
/// Keyed by a hash of model + system prompt + text, so a different target language, tone, or
/// provider never collides. Bounded in size with simple oldest-first eviction.
actor TranslationCache {
    static let shared = TranslationCache()

    private struct Entry: Codable { let out: String; var at: Double }
    private var map: [String: Entry]?          // loaded lazily from disk
    private let maxEntries = 800

    private var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Configuration.appGroupIdentifier)?
            .appendingPathComponent("translation-cache.json")
    }

    /// Stable key for a request. `modelID` distinguishes KeyGlot vs a specific Custom provider/model.
    static func key(modelID: String, systemPrompt: String, text: String) -> String {
        let joined = modelID + "\u{1F}" + systemPrompt + "\u{1F}" + text
        return SHA256.hash(data: Data(joined.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func value(for key: String) -> String? {
        loadIfNeeded()
        return map?[key]?.out
    }

    func store(_ value: String, for key: String) {
        loadIfNeeded()
        map?[key] = Entry(out: value, at: Date().timeIntervalSince1970)
        evictIfNeeded()
        save()
    }

    private func loadIfNeeded() {
        if map != nil { return }
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            map = [:]
            return
        }
        map = decoded
    }

    private func evictIfNeeded() {
        guard var m = map, m.count > maxEntries else { return }
        // Drop the oldest entries (plus a little headroom so we don't evict on every write).
        let overflow = m.count - maxEntries + 100
        for (k, _) in m.sorted(by: { $0.value.at < $1.value.at }).prefix(overflow) {
            m.removeValue(forKey: k)
        }
        map = m
    }

    private func save() {
        guard let fileURL, let m = map, let data = try? JSONEncoder().encode(m) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

/// Wraps any `AIProvider` with the on-device cache. A cache hit skips the network/AI entirely.
struct CachedProvider: AIProvider {
    let wrapped: any AIProvider
    /// Identifies the model behind the result so cached outputs never mix across providers.
    let modelID: String

    func generate(text: String, systemPrompt: String) async throws -> String {
        let key = TranslationCache.key(modelID: modelID, systemPrompt: systemPrompt, text: text)
        if let hit = await TranslationCache.shared.value(for: key) { return hit }
        let out = try await wrapped.generate(text: text, systemPrompt: systemPrompt)
        await TranslationCache.shared.store(out, for: key)
        return out
    }
}
