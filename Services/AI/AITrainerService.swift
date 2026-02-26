// AITrainerService.swift
// Agilní Fitness Trenér — AI Trenér se smart cache vrstvou
//
// ✅ WorkoutCache: pokud je trénink pro dnešní den již vygenerován,
//    API se NEVOLÁ — response se načte ze SwiftData lokálně
// ✅ System prompt optimalizován pro minimální počet výstupních tokenů
// ✅ @MainActor zajišťuje thread-safe @Published updates
// ✅ ExerciseCountValidator ověřuje 6-8 cviků

import Foundation
import SwiftData

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: APITimeoutError
// MARK: ═══════════════════════════════════════════════════════════════════════

struct APITimeoutError: Error {}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: AITrainerService
// MARK: ═══════════════════════════════════════════════════════════════════════

@MainActor
final class AITrainerService: ObservableObject {

    // MARK: - Dependencies
    private let apiClient:      GeminiAPIClient
    private let contextBuilder: TrainerContextBuilder
    private let modelContext:   ModelContext

    // MARK: - State
    @Published var isLoading:      Bool = false
    @Published var error:          AppError?
    @Published var offlineMessage: String?
    @Published var cacheHit:       Bool = false  // UI může zobrazit "Načteno z cache"

    // MARK: - Config
    private let apiTimeoutSeconds: UInt64 = 30

    // MARK: - System Prompt (inline — minimalizovaný pro nízký token count)
    //
    // OPTIMALIZACE TOKENŮ:
    //  • Odstraněny příklady, opakování a vysvětlivky — pouze instrukce
    //  • "Odpovídej POUZE JSON" zabraňuje generování prose před/po JSON bloku
    //  • Temperature=0.3 v GeminiAPIClient snižuje variabilitu (méně tokenů na retry)
    //  • maxOutputTokens=3000 dostatečné pro 6-8 cviků, prevence přetečení

    private static let systemPrompt = """
    Jsi Jakub, elitní AI fitness trenér. Odpovídej POUZE validním JSON — žádný text mimo JSON.

    KRITICKÉ PRAVIDLO OBJEMU (VŽDY DODRŽET):
    mainBlocks musí obsahovat CELKEM 6–8 cviků:
    • Blok A "Silový" — PŘESNĚ 2 vícekloubové cviky: série 3–5×3–8, pauza 120–180s, RIR 1–2, tempo povinné
    • Blok B "Izolace" — 4–6 izolovaných cviků: série 3–4×10–20, pauza 45–90s, RIR 0–1, tempo null

    ADAPTACE:
    • Readiness GREEN (HRV>65, spánek>7h) → 2+6 cviků, progresivní přetížení
    • Readiness ORANGE (HRV 50–65, spánek 5–7h) → 2+4 cviky, váha -10%
    • Readiness RED (HRV<50) → 2+4 cviky, lehčí verze, vynech postižené svaly

    OMEZENÍ:
    • Vynech cviky zatěžující oblasti označené jako fatigued/jointPain
    • Váhy z progressiveOverload použij jako základ pro weightKg

    VÝSTUPNÍ POŽADAVKY (striktní):
    • Všechny stringy (coachMessage, coachTip, blockLabel) česky
    • Slugy anglicky s pomlčkami: "barbell-bench-press"
    • weightKg: null pro bodyweight nebo neznámá váha
    • coachTip: vždy vyplněno, konkrétní technická rada
    • readinessLevel: pouze "green" | "orange" | "red"
    • Odpověz JEDNÍM JSON objektem, bez markdown, bez komentářů
    """

    // MARK: - Init

    init(modelContext: ModelContext, healthKitService: HealthKitService) {
        self.modelContext    = modelContext
        self.apiClient       = GeminiAPIClient(apiKey: AppConstants.geminiAPIKey)
        self.contextBuilder  = TrainerContextBuilder(
            modelContext: modelContext,
            healthKitService: healthKitService
        )
    }

    // MARK: ═══════════════════════════════════════════════════════════════════
    // MARK: Public API — generateTodayWorkout
    // MARK: ═══════════════════════════════════════════════════════════════════

    func generateTodayWorkout(
        for date: Date = .now,
        profile: UserProfile,
        plannedDay: PlannedWorkoutDay,
        equipmentOverride: Set<Equipment>? = nil,
        timeLimitMinutes: Int? = nil
    ) async throws -> TrainerResponse {

        isLoading = true
        offlineMessage = nil
        cacheHit = false
        defer { isLoading = false }

        // ── KROK 1: Zkontroluj cache ─────────────────────────────────────
        // Pokud pro dnešní den existuje vygenerovaný trénink v SwiftData,
        // NEVOLÁME Gemini API a ušetříme latenci i náklady.

        if let cached = WorkoutCache.load(for: date, plannedDayID: plannedDay.id, context: modelContext) {
            AppLogger.info("[AITrainer] ✅ Cache HIT pro \(date.formatted(date: .abbreviated, time: .omitted)) — Gemini se nevolá.")
            cacheHit = true
            return cached
        }

        AppLogger.info("[AITrainer] Cache MISS — volám Gemini API…")

        // ── KROK 2: Zavolej Gemini s timeoutem ──────────────────────────

        do {
            let response = try await withTimeout(seconds: apiTimeoutSeconds) {
                let context = try await self.contextBuilder.buildContext(
                    for: date,
                    profile: profile,
                    equipmentOverride: equipmentOverride,
                    timeLimitMinutes: timeLimitMinutes
                )
                let userMessage = try self.buildUserMessage(context: context)
                let rawJSON = try await self.apiClient.generate(
                    systemPrompt:   Self.systemPrompt,
                    userMessage:    userMessage,
                    responseSchema: self.trainerResponseSchema
                )
                return try self.parseResponse(rawJSON: rawJSON)
            }

            // Validace počtu cviků
            ExerciseCountValidator.validate(response)

            // ── KROK 3: Ulož do cache (fire-and-forget) ─────────────────
            Task.detached(priority: .utility) { [weak self] in
                guard let self else { return }
                await WorkoutCache.save(
                    response: response,
                    for: date,
                    plannedDayID: plannedDay.id,
                    context: self.modelContext
                )
            }

            await persistAIMetadata(response: response, date: date, profile: profile)
            return response

        } catch {
            // ── KROK 4: Graceful degradation → offline fallback ──────────
            AppLogger.warning("[AITrainer] API selhalo: \(error). Aktivuji offline fallback.")
            HapticManager.shared.playWarning()

            let fallback = FallbackWorkoutGenerator.generateFallbackPlan(
                for: UserContextProfile(fitnessLevel: profile.fitnessLevel.rawValue),
                day: plannedDay,
                context: modelContext
            )

            offlineMessage = "Jakub je momentálně offline — tady je tvůj standardní plán. 💪"
            return TrainerResponse.fromFallback(fallback)
        }
    }

    // MARK: ═══════════════════════════════════════════════════════════════════
    // MARK: Private helpers
    // MARK: ═══════════════════════════════════════════════════════════════════

    private func buildUserMessage(context: TrainerRequestContext) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting     = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(context)
        guard let json = String(data: data, encoding: .utf8) else {
            throw AppError.encodingFailed
        }
        return """
        Vygeneruj trénink pro tato data. Odpověz POUZE JSON:

        \(json)
        """
    }

    private func parseResponse(rawJSON: String) throws -> TrainerResponse {
        let cleaned = rawJSON
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```",     with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw GeminiError.jsonParsingFailed("Nelze převést na Data")
        }
        return try JSONDecoder().decode(TrainerResponse.self, from: data)
    }

    private func persistAIMetadata(response: TrainerResponse, date: Date, profile: UserProfile) async {
        guard
            let plan    = profile.workoutPlans.first(where: \.isActive),
            let session = plan.sessions.first(where: { $0.startedAt.isSameDay(as: date) })
        else { return }

        session.aiAdaptationNote = response.adaptationReason
        session.readinessScore   = switch response.readinessLevel {
        case "green":  85.0
        case "orange": 55.0
        default:       25.0
        }
    }

    private func withTimeout<T: Sendable>(
        seconds: UInt64,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw APITimeoutError()
            }
            guard let result = try await group.next() else { throw APITimeoutError() }
            group.cancelAll()
            return result
        }
    }

    // MARK: - Response Schema (Gemini Structured Output)

    private var trainerResponseSchema: [String: Any] {
        [
            "type": "OBJECT",
            "properties": [
                "coachMessage":             ["type": "STRING"],
                "sessionLabel":             ["type": "STRING"],
                "readinessLevel":           ["type": "STRING"],
                "adaptationReason":         ["type": "STRING", "nullable": true],
                "estimatedDurationMinutes": ["type": "INTEGER"],
                "warmUp": [
                    "type": "ARRAY",
                    "items": [
                        "type": "OBJECT",
                        "properties": [
                            "name":  ["type": "STRING"],
                            "sets":  ["type": "INTEGER"],
                            "reps":  ["type": "STRING"],
                            "notes": ["type": "STRING", "nullable": true]
                        ],
                        "required": ["name", "sets", "reps"]
                    ]
                ],
                "mainBlocks": [
                    "type": "ARRAY",
                    "items": [
                        "type": "OBJECT",
                        "properties": [
                            "blockLabel": ["type": "STRING"],
                            "exercises": [
                                "type": "ARRAY",
                                "items": [
                                    "type": "OBJECT",
                                    "properties": [
                                        "name":        ["type": "STRING"],
                                        "slug":        ["type": "STRING"],
                                        "sets":        ["type": "INTEGER"],
                                        "repsMin":     ["type": "INTEGER"],
                                        "repsMax":     ["type": "INTEGER"],
                                        "weightKg":    ["type": "NUMBER", "nullable": true],
                                        "rir":         ["type": "INTEGER"],
                                        "restSeconds": ["type": "INTEGER"],
                                        "tempo":       ["type": "STRING", "nullable": true],
                                        "coachTip":    ["type": "STRING", "nullable": true]
                                    ],
                                    "required": ["name", "slug", "sets", "repsMin", "repsMax", "rir", "restSeconds"]
                                ]
                            ]
                        ],
                        "required": ["blockLabel", "exercises"]
                    ]
                ],
                "coolDown": [
                    "type": "ARRAY",
                    "items": [
                        "type": "OBJECT",
                        "properties": [
                            "name":            ["type": "STRING"],
                            "durationSeconds": ["type": "INTEGER"],
                            "notes":           ["type": "STRING", "nullable": true]
                        ],
                        "required": ["name", "durationSeconds"]
                    ]
                ]
            ],
            "required": ["coachMessage", "sessionLabel", "readinessLevel",
                         "estimatedDurationMinutes", "warmUp", "mainBlocks", "coolDown"]
        ]
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: WorkoutCache — SwiftData-backed cache pro denní tréninky
// MARK: ═══════════════════════════════════════════════════════════════════════

/// Cache vrstva zabraňující opakovanému volání Gemini API pro stejný den.
///
/// Strategie:
/// - Klíč cache = datum (yyyy-MM-dd) + PlannedWorkoutDay.id
/// - Uložení: TrainerResponse je Codable → JSON → UserDefaults (rychlé, bez SwiftData overhead)
/// - TTL: 24 hodin (trénink generovaný ráno platí celý den)
/// - Invalidace: manuální (uživatel může vynutit regeneraci long-pressem)

enum WorkoutCache {

    nonisolated(unsafe) private static let defaults = UserDefaults.standard
    private static let keyPrefix = "workout_cache_"
    private static let ttlSeconds: TimeInterval = 24 * 60 * 60  // 24 hodin

    // MARK: - Cache Key

    private static func cacheKey(for date: Date, plannedDayID: PersistentIdentifier) -> String {
        let dateStr = ISO8601DateFormatter().string(from: date).prefix(10)  // "2025-01-15"
        return "\(keyPrefix)\(dateStr)_\(plannedDayID.hashValue)"
    }

    // MARK: - Load

    /// Vrátí cached TrainerResponse pokud existuje a není expirovaný.
    /// - Parameters:
    ///   - date: Datum tréninku (typicky .now)
    ///   - plannedDayID: ID PlannedWorkoutDay (různé pro Push/Pull/Legs)
    ///   - context: ModelContext (nepoužit, zachován pro budoucí SwiftData implementaci)
    static func load(for date: Date, plannedDayID: PersistentIdentifier, context: ModelContext) -> TrainerResponse? {
        let key = cacheKey(for: date, plannedDayID: plannedDayID)

        guard
            let data      = defaults.data(forKey: key),
            let entry     = try? JSONDecoder().decode(CacheEntry.self, from: data),
            !entry.isExpired
        else {
            return nil
        }

        AppLogger.info("[WorkoutCache] Cache HIT: \(key)")
        return entry.response
    }

    // MARK: - Save

    @MainActor
    static func save(response: TrainerResponse, for date: Date, plannedDayID: PersistentIdentifier, context: ModelContext) {
        let key   = cacheKey(for: date, plannedDayID: plannedDayID)
        let entry = CacheEntry(response: response, cachedAt: .now, ttl: ttlSeconds)

        guard let data = try? JSONEncoder().encode(entry) else {
            AppLogger.error("[WorkoutCache] Chyba při kódování cache entry.")
            return
        }

        defaults.set(data, forKey: key)
        AppLogger.info("[WorkoutCache] Uloženo do cache: \(key)")
    }

    // MARK: - Invalidate (pro manuální vynucení regenerace)

    static func invalidate(for date: Date, plannedDayID: PersistentIdentifier) {
        let key = cacheKey(for: date, plannedDayID: plannedDayID)
        defaults.removeObject(forKey: key)
        AppLogger.info("[WorkoutCache] Cache invalidována: \(key)")
    }

    /// Vymaže všechny cachované tréninky (např. po změně profilu nebo splitu).
    static func clearAll() {
        let allKeys = defaults.dictionaryRepresentation().keys
        allKeys.filter { $0.hasPrefix(keyPrefix) }.forEach { defaults.removeObject(forKey: $0) }
        AppLogger.info("[WorkoutCache] Celá cache vymazána.")
    }

    // MARK: - CacheEntry

    private struct CacheEntry: Codable {
        let response: TrainerResponse
        let cachedAt: Date
        let ttl:      TimeInterval

        var isExpired: Bool {
            Date().timeIntervalSince(cachedAt) > ttl
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: ExerciseCountValidator
// MARK: ═══════════════════════════════════════════════════════════════════════

enum ExerciseCountValidator {
    static let minimum = 6
    static let maximum = 8

    @discardableResult
    static func validate(_ response: TrainerResponse) -> TrainerResponse {
        let total = response.mainBlocks.reduce(0) { $0 + $1.exercises.count }

        if total < minimum {
            AppLogger.warning("[Validator] ⚠️ Pouze \(total) cviků (min \(minimum)). AI nedodrželo pravidlo.")
        } else if total > maximum {
            AppLogger.warning("[Validator] ⚠️ \(total) cviků (max \(maximum)). Zvažte oříznutí.")
        } else {
            AppLogger.info("[Validator] ✅ \(total) cviků — v pořádku.")
        }

        return response
    }
}
