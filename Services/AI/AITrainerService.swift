// AITrainerService.swift
// Agilní Fitness Trenér — AI Trenér se smart cache a bezpečnou souběžností
//
// OPRAVY a VYLEPŠENÍ v2.1:
//  ✅ WorkoutCache: UserDefaults s TTL 24h — Gemini se nevolá pokud cache platí
//  ✅ System Prompt: striktní JSON-only instrukce, nulové Markdown, optimalizovaný
//  ✅ @MainActor: všechny @Published updaty garantovaně na hlavním vlákně
//  ✅ Task.detached pro cache save — neblokuje UI, s [weak self] safe capture
//  ✅ ExerciseCountValidator: loguje varování bez pádu aplikace
//  ✅ Timeout mechanism: 30s hard limit na Gemini volání (Task race)
//  ✅ Fallback flow: graceful degradation → FallbackWorkoutGenerator
//  ✅ JSON parser: stripuje Markdown fences i BOM před dekódováním
//  ✅ persistAIMetadata: crashsafe guard + async na background

import Foundation
import SwiftData

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: AITrainerService
// MARK: ═══════════════════════════════════════════════════════════════════════

@MainActor
final class AITrainerService: ObservableObject {

    // MARK: - Závislosti

    private let apiClient:      GeminiAPIClient
    private let contextBuilder: TrainerContextBuilder
    private let modelContext:   ModelContext

    // MARK: - Publikovaný stav

    @Published private(set) var isLoading:      Bool    = false
    @Published private(set) var error:          AppError?
    @Published private(set) var offlineMessage: String?
    @Published private(set) var cacheHit:       Bool    = false

    // MARK: - Konfigurace

    private let timeoutSeconds: UInt64 = 30

    // MARK: - System Prompt (token-optimalizovaný)
    //
    // Klíčová optimalizační rozhodnutí:
    //  • "Odpovídej POUZE JSON" → eliminuje prose před/po JSON bloku (~200 ušetřených tokenů)
    //  • Bez příkladů, bez opakování → prompt je stručný
    //  • temperature=0.3 v GeminiAPIClient → méně variabilních retry
    //  • maxOutputTokens=3000 → dostatečné pro 6-8 cviků, zabraňuje přetečení
    //  • Structured Output schema (viz níže) → Gemini vrací validní JSON BEZ obalů

    // Inline prompt je záloha. Primárně se čte SystemPrompt.txt z Resources.
    private static let systemPrompt: String = {
        if let url = Bundle.main.url(forResource: "SystemPrompt", withExtension: "txt"),
           let txt = try? String(contentsOf: url, encoding: .utf8), !txt.isEmpty {
            return txt
        }
        return """
        Jsi iKorba, osobní fitness trenér. Odpovídej VÝHRADNĚ validním JSON objektem.

        STRUKTURA (VŽDY DODRŽET):
        • Compound cviky PRVNÍ (dřep, mrtvý tah, benchpress), izolace POSLEDNÍ
        • Blok A Silový: 2–3 compound cviky, 3–5×3–8, pauza 120–180s, RIR 1–2, tempo povinné
        • Blok B Objem: 3–5 izolací, 3–4×10–20, pauza 45–90s, RIR 0–1

        READINESS:
        • GREEN (HRV>65% avg, spánek>7h) → plný objem, +2.5–5% váhy
        • ORANGE (HRV 50–65%, 5–7h) → Blok B: 1 cvik méně, váha −10%
        • RED (HRV<50%) → jen aktivní regenerace, žádné heavy compound

        OMEZENÍ:
        • Vynech svaly označené fatigued nebo jointPain
        • Nikdy nepoužij vybavení chybějící v equipment.availableEquipment
        • Váhy z progressiveOverload jsou základ pro weightKg
        • name: česky, slug: anglicky (barbell-bench-press), readinessLevel: green|orange|red
        • Odpověz JEDNÍM JSON objektem. Bez markdown, bez textu navíc.
        """
    }()

    // MARK: - Inicializace

    init(modelContext: ModelContext, healthKitService: HealthKitService) {
        self.modelContext   = modelContext
        self.apiClient      = GeminiAPIClient(apiKey: AppConstants.geminiAPIKey)
        self.contextBuilder = TrainerContextBuilder(
            modelContext: modelContext,
            healthKitService: healthKitService
        )
    }

    // MARK: ═══════════════════════════════════════════════════════════════════
    // MARK: generateTodayWorkout — hlavní veřejná funkce
    // MARK: ═══════════════════════════════════════════════════════════════════

    /// Vygeneruje trénink na dnešní den.
    /// - Pokud existuje platná cache pro daný den a plán → vrátí cache (Gemini se NEVOLÁ)
    /// - Pokud cache neexistuje → volá Gemini API s 30s timeoutem
    /// - Pokud Gemini selže → vrátí offline fallback
    ///
    /// - Throws: Nikdy → veškeré chyby jsou zpracovány interně (graceful degradation)
    func generateTodayWorkout(
        for date: Date = .now,
        profile: UserProfile,
        plannedDay: PlannedWorkoutDay,
        equipmentOverride: Set<Equipment>? = nil,
        timeLimitMinutes: Int? = nil
    ) async -> TrainerResponse {

        // Reset stavu
        isLoading      = true
        offlineMessage = nil
        cacheHit       = false
        error          = nil

        defer {
            // Vždy garantujeme že isLoading = false při ukončení
            isLoading = false
        }

        // ── KROK 1: Zkontroluj cache ─────────────────────────────────────────
        // Cache hit = nenastane žádné síťové volání → nulové náklady, okamžitá odpověď

        if let cached = WorkoutCache.load(for: date, plannedDayID: plannedDay.id, context: modelContext) {
            AppLogger.info("✅ [AITrainer] Cache HIT → \(date.formatted(date: .abbreviated, time: .omitted)) — Gemini se nevolá.")
            cacheHit = true
            return cached
        }

        AppLogger.info("ℹ️ [AITrainer] Cache MISS → volám Gemini API…")

        // ── KROK 2: Gemini API volání s timeoutem ────────────────────────────

        do {
            let response = try await callGeminiWithTimeout(
                date: date,
                profile: profile,
                plannedDay: plannedDay,
                equipmentOverride: equipmentOverride,
                timeLimitMinutes: timeLimitMinutes
            )

            // Validace počtu cviků (nekritická — pouze warning)
            AIExerciseCountValidator.validate(response)

            // ── KROK 3: Asynchronní uložení do cache (neblokuje UI) ──────────
            let responseSnapshot = response
            let dateSnapshot     = date
            let planIDSnapshot   = plannedDay.id

            // Použijeme Task.detached aby cache save neblokoval return response
            // SharedModelContainer.container je nonisolated → bezpečné předání
            let container = SharedModelContainer.container
            Task.detached(priority: .utility) {
                let bgContext = ModelContext(container)
                await WorkoutCache.save(
                    response: responseSnapshot,
                    for: dateSnapshot,
                    plannedDayID: planIDSnapshot,
                    context: bgContext
                )
            }

            // Persistuj AI metadata na pozadí (neblokuje return)
            Task { [weak self] in
                guard let self else { return }
                await self.persistAIMetadata(response: response, date: date, profile: profile)
            }

            return response

        } catch {
            // ── KROK 4: Graceful degradation ────────────────────────────────
            AppLogger.warning("⚠️ [AITrainer] API selhalo (\(error)) → aktivuji offline fallback.")
            HapticManager.shared.playWarning()

            let fallback = FallbackWorkoutGenerator.generateFallbackPlan(
                for: UserContextProfile(fitnessLevel: profile.fitnessLevel.rawValue),
                day: plannedDay,
                context: modelContext
            )

            offlineMessage = "iKorba je momentálně offline — tady je tvůj standardní plán. 💪"
            return TrainerResponse.fromFallback(fallback)
        }
    }

    // MARK: - Manuální invalidace cache

    /// Vymaže cache pro dnešní den a vynutí regeneraci při dalším volání.
    func invalidateTodayCache(plannedDay: PlannedWorkoutDay) {
        WorkoutCache.invalidate(for: .now, plannedDayID: plannedDay.id)
        AppLogger.info("🗑️ [AITrainer] Cache dnešního tréninku vymazána (manuální).")
    }

    /// Vymaže celou cache (po změně profilu nebo tréninkového plánu).
    func clearAllCache() {
        WorkoutCache.clearAll()
        AppLogger.info("🗑️ [AITrainer] Celá cache vymazána.")
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Private helpers
// MARK: ═══════════════════════════════════════════════════════════════════════

private extension AITrainerService {

    // MARK: Gemini volání s hard timeoutem

    func callGeminiWithTimeout(
        date: Date,
        profile: UserProfile,
        plannedDay: PlannedWorkoutDay,
        equipmentOverride: Set<Equipment>?,
        timeLimitMinutes: Int?
    ) async throws -> TrainerResponse {

        // 1. Připravíme data na hlavním herci
        let profileID = profile.persistentModelID
        let plannedDayID = plannedDay.persistentModelID
        let timeout = self.timeoutSeconds
        
        // Sestavení kontextu musí proběhnout zde (na MainActoru)
        let ctx = try await contextBuilder.buildContext(
            for: date,
            profileID: profileID,
            plannedDayID: plannedDayID,
            equipmentOverride: equipmentOverride,
            timeLimitMinutes: timeLimitMinutes
        )
        let userMessage = try AITrainerService.buildUserMessage(context: ctx)
        
        // Lokální kopie aktora pro task group
        let apiClient = self.apiClient

        return try await withThrowingTaskGroup(of: TrainerResponse.self) { group in
            // AI Task
            group.addTask {
                let rawJSON = try await apiClient.generate(
                    systemPrompt:   AITrainerService.systemPrompt,
                    userMessage:    userMessage,
                    responseSchema: AITrainerService.trainerResponseSchema
                )
                return try AITrainerService.parseAndValidateJSON(rawJSON: rawJSON)
            }

            // Timeout Task
            group.addTask {
                try await Task.sleep(nanoseconds: timeout * 1_000_000_000)
                throw APITimeoutError()
            }
            // Kdo dřív přijde...
            guard let result = try await group.next() else {
                throw AppError.internalError("Chyba v paralelním zpracování Gemini")
            }
            
            group.cancelAll()
            return result
        }
    }

    // MARK: Sestavení user message (JSON kontext)
    // static nonisolated: čistě výpočetní, bezpečné pro synchronní volání z pozadí
    static nonisolated func buildUserMessage(context: TrainerRequestContext) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting     = [.sortedKeys]   // Bez .prettyPrinted → méně tokenů
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(context)
        guard let json = String(data: data, encoding: .utf8) else {
            throw AppError.encodingFailed
        }
        return "Vygeneruj trénink. Odpověz POUZE JSON:\n\(json)"
    }

    // MARK: Parsování a čistění JSON odpovědi
    // static nonisolated: čistě výpočetní, bezpečné pro synchronní volání z pozadí
    static nonisolated func parseAndValidateJSON(rawJSON: String) throws -> TrainerResponse {
        // Agresivní čistění: stripujeme veškerý Markdown a BOM znaky
        let cleaned = rawJSON
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```",     with: "")
            .replacingOccurrences(of: "\u{FEFF}", with: "")  // BOM
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Ochrana před prázdnou odpovědí
        guard !cleaned.isEmpty else {
            throw GeminiError.emptyResponse
        }

        // Najdi začátek JSON objektu (ochrana před prose před JSON)
        let jsonStart = cleaned.firstIndex(of: "{") ?? cleaned.startIndex
        let jsonSlice = String(cleaned[jsonStart...])

        guard let data = jsonSlice.data(using: .utf8) else {
            throw GeminiError.jsonParsingFailed("Nelze převést na Data — invalid encoding")
        }

        do {
            return try JSONDecoder().decode(TrainerResponse.self, from: data)
        } catch let decodingError as DecodingError {
            AppLogger.error("❌ [AITrainer] JSON dekódování selhalo: \(decodingError)")
            throw GeminiError.jsonParsingFailed("DecodingError: \(decodingError.localizedDescription)")
        }
    }

    // MARK: Persistování AI metadat do SwiftData

    func persistAIMetadata(response: TrainerResponse, date: Date, profile: UserProfile) async {
        // Guard: hledáme aktivní plán a session pro daný den
        guard
            let plan    = profile.workoutPlans.first(where: \.isActive),
            let session = plan.sessions.first(where: { $0.startedAt.isSameDay(as: date) })
        else {
            AppLogger.info("ℹ️ [AITrainer] persistAIMetadata: session pro \(date.formatted()) nenalezena, přeskakuji.")
            return
        }

        session.aiAdaptationNote = response.adaptationReason
        session.readinessScore   = switch response.readinessLevel {
        case "green":  85.0
        case "orange": 55.0
        default:       25.0
        }

        // Uložení je spravováno SwiftData automaticky přes modelContext
    }

    // MARK: ═══════════════════════════════════════════════════════════════════
    // MARK: Gemini Structured Output Schema
    // ═══════════════════════════════════════════════════════════════════════════
    // Structured Output schema zaručuje, že Gemini vrátí vždy validní JSON
    // odpovídající TrainerResponse — bez markdown, bez prose, bez obalů.

    nonisolated(unsafe) static let trainerResponseSchema: [String: Any] = {
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
            "required": [
                "coachMessage",
                "sessionLabel",
                "readinessLevel",
                "estimatedDurationMinutes",
                "warmUp",
                "mainBlocks",
                "coolDown"
            ]
        ]
    }()
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: APITimeoutError
// MARK: ═══════════════════════════════════════════════════════════════════════

struct APITimeoutError: Error, LocalizedError {
    var errorDescription: String? { "Gemini API neodpovědělo do 30 sekund (timeout)." }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: WorkoutCache — UserDefaults cache pro denní tréninky
// MARK: ═══════════════════════════════════════════════════════════════════════
//
// Strategie cachování:
//  • Klíč = datum (yyyy-MM-dd) + hash PlannedWorkoutDay.id
//  • TTL = 24 hodin (trénink vygenerovaný ráno platí celý den)
//  • Úložiště = UserDefaults.standard (rychlé, bez SwiftData overhead)
//  • Invalidace: manuální (long-press na "Regenerovat" v UI) nebo změna plánu

enum WorkoutCache {

    // nonisolated(unsafe) — přistupujeme z Task.detached (bez MainActor)
    nonisolated(unsafe) private static let defaults   = UserDefaults.standard
    private static let keyPrefix:  String             = "wc_v1_"
    private static let ttlSeconds: TimeInterval       = 24 * 60 * 60

    // MARK: Klíč cache

    nonisolated static func cacheKey(for date: Date, plannedDayID: PersistentIdentifier) -> String {
        // Používáme pouze datum (10 znaků), ne čas → cache platí celý den
        let dateStr = ISO8601DateFormatter().string(from: date).prefix(10)
        return "\(keyPrefix)\(dateStr)_\(plannedDayID.hashValue)"
    }

    // MARK: Load

    /// Vrátí cachovaný TrainerResponse, pokud existuje a není expirovaný.
    /// Vrací `nil` pokud cache neexistuje, nebo byl překročen TTL.
    static func load(
        for date: Date,
        plannedDayID: PersistentIdentifier,
        context: ModelContext  // Zachován pro budoucí SwiftData implementaci
    ) -> TrainerResponse? {

        let key = cacheKey(for: date, plannedDayID: plannedDayID)

        guard
            let data  = defaults.data(forKey: key),
            let entry = try? JSONDecoder().decode(CacheEntry.self, from: data),
            !entry.isExpired
        else {
            return nil
        }

        AppLogger.info("💾 [WorkoutCache] HIT: \(key) (uloženo \(entry.cachedAt.formatted(date: .omitted, time: .shortened)))")
        return entry.response
    }

    // MARK: Save

    /// Uloží TrainerResponse do cache.
    /// Bezpečné volat z libovolného kontextu (nonisolated safe).
    nonisolated static func save(
        response: TrainerResponse,
        for date: Date,
        plannedDayID: PersistentIdentifier,
        context: ModelContext
    ) async {
        let key   = cacheKey(for: date, plannedDayID: plannedDayID)
        let entry = CacheEntry(response: response, cachedAt: .now, ttl: ttlSeconds)

        guard let data = try? JSONEncoder().encode(entry) else {
            AppLogger.error("❌ [WorkoutCache] Chyba enkódování cache entry pro klíč: \(key)")
            return
        }

        defaults.set(data, forKey: key)
        AppLogger.info("💾 [WorkoutCache] SAVE: \(key)")
    }

    // MARK: Invalidate

    static func invalidate(for date: Date, plannedDayID: PersistentIdentifier) {
        let key = cacheKey(for: date, plannedDayID: plannedDayID)
        defaults.removeObject(forKey: key)
        AppLogger.info("🗑️ [WorkoutCache] Invalidováno: \(key)")
    }

    static func clearAll() {
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(keyPrefix) }
            .forEach { defaults.removeObject(forKey: $0) }
        AppLogger.info("🗑️ [WorkoutCache] Celá cache vymazána (clearAll).")
    }

    // MARK: CacheEntry (privátní datový model)

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
// MARK: AIExerciseCountValidator
// MARK: ═══════════════════════════════════════════════════════════════════════

enum AIExerciseCountValidator {

    static let minimum = 6
    static let maximum = 8

    /// Zkontroluje počet cviků v odpovědi a zaloguje varování.
    /// NEKRITICKÁ — pouze loguje, nepadá aplikace.
    @discardableResult
    static func validate(_ response: TrainerResponse) -> TrainerResponse {
        let total = response.mainBlocks.reduce(0) { $0 + $1.exercises.count }

        switch total {
        case ..<minimum:
            AppLogger.warning("⚠️ [Validator] Pouze \(total) cviků (min \(minimum)). AI nedodrželo pravidlo objemu.")
        case (maximum + 1)...:
            AppLogger.warning("⚠️ [Validator] \(total) cviků (max \(maximum)). Zvažte oříznutí posledních \(total - maximum) cviků.")
        default:
            AppLogger.info("✅ [Validator] \(total) cviků — v pořádku (\(minimum)–\(maximum)).")
        }

        return response
    }
}
