// AIResponseCache.swift
// Lokální souborová cache pro Gemini AI odpovědi (TTL: 24h).
// Klíč = SHA256 hash systémového promptu + user promptu.
// Výhoda: při opakovaném dotazu se stejným kontextem se API nevolá.

import Foundation
import CryptoKit

actor AIResponseCache {
    static let shared = AIResponseCache()

    private let cacheDir: URL
    private let ttl: TimeInterval = 60 * 60 * 24 // 24 hodin

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDir = base.appendingPathComponent("AIResponseCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Vrátí cachedovanou odpověď, pokud existuje a je platná (< 24h).
    func get(systemPrompt: String, userMessage: String) -> String? {
        let key  = cacheKey(system: systemPrompt, user: userMessage)
        let file = cacheDir.appendingPathComponent("\(key).json")
        guard let data = try? Data(contentsOf: file) else { return nil }
        guard let entry = try? JSONDecoder().decode(CacheEntry.self, from: data) else { return nil }

        // TTL check
        if Date().timeIntervalSince(entry.cachedAt) > ttl {
            try? FileManager.default.removeItem(at: file)
            AppLogger.info("🗑️ [AICache] Cache expirována pro klíč: \(key.prefix(12))…")
            return nil
        }
        AppLogger.info("✅ [AICache] Cache HIT — klíč: \(key.prefix(12))…")
        return entry.response
    }

    /// Uloží odpověď do cache.
    func set(systemPrompt: String, userMessage: String, response: String) {
        let key   = cacheKey(system: systemPrompt, user: userMessage)
        let file  = cacheDir.appendingPathComponent("\(key).json")
        let entry = CacheEntry(response: response, cachedAt: .now)
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? data.write(to: file)
        AppLogger.info("💾 [AICache] Odpověď uložena — klíč: \(key.prefix(12))…")
    }

    /// Vymaže celou cache.
    func clearAll() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) else { return }
        files.forEach { try? FileManager.default.removeItem(at: $0) }
        AppLogger.info("🧹 [AICache] Cache smazána (\(files.count) položek).")
    }

    /// Počet položek v cache.
    func count() -> Int {
        (try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil))?.count ?? 0
    }

    // MARK: - Private

    private func cacheKey(system: String, user: String) -> String {
        let combined = system + "|||" + user
        let digest   = SHA256.hash(data: Data(combined.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private struct CacheEntry: Codable {
        let response: String
        let cachedAt: Date
    }
}
