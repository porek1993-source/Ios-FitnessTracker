// AITrainerService.swift

import Foundation
import SwiftData

/// Chyba vyhozená při překročení časového limitu pro API request.
struct APITimeoutError: Error {}

@MainActor
final class AITrainerService: ObservableObject {

    private let apiClient:      GeminiAPIClient
    private let contextBuilder: TrainerContextBuilder
    private let systemPrompt:   String
    private let modelContext:   ModelContext

    @Published var isLoading = false
    @Published var error: AppError?
    /// Zpráva viditelná v UI, pokud se aktivoval offline fallback.
    @Published var offlineMessage: String?

    /// Timeout pro Gemini API v sekundách.
    private let apiTimeoutSeconds: UInt64 = 15

    init(modelContext: ModelContext, healthKitService: HealthKitService) {
        self.modelContext    = modelContext
        self.apiClient       = GeminiAPIClient(apiKey: AppConstants.geminiAPIKey)
        self.contextBuilder  = TrainerContextBuilder(
            modelContext: modelContext,
            healthKitService: healthKitService
        )
        self.systemPrompt = SystemPromptLoader.load()
    }

    // MARK: - Public API

    func generateTodayWorkout(
        for date: Date = .now,
        profile: UserProfile,
        plannedDay: PlannedWorkoutDay,
        equipmentOverride: Set<Equipment>? = nil,
        timeLimitMinutes: Int? = nil
    ) async throws -> TrainerResponse {
        isLoading = true
        offlineMessage = nil
        defer { isLoading = false }

        do {
            // Pokusíme se o standardní API volání s timeoutem
            let response = try await withTimeout(seconds: apiTimeoutSeconds) {
                let context     = try await self.contextBuilder.buildContext(
                    for: date, 
                    profile: profile,
                    equipmentOverride: equipmentOverride,
                    timeLimitMinutes: timeLimitMinutes
                )
                let userMessage = try await self.buildUserMessage(context: context)
                let rawJSON     = try await self.apiClient.generate(
                    systemPrompt:   self.systemPrompt,
                    userMessage:    userMessage,
                    responseSchema: self.trainerResponseSchema
                )
                return try await self.parseResponse(rawJSON: rawJSON)
            }

            await persistAIMetadata(response: response, date: date, profile: profile)
            return response

        } catch {
            // ─── Graceful Degradation ─────────────────────────────────
            // API selhalo (timeout, síť, parsing...) → generujeme offline.
            HapticManager.shared.playWarning()

            let userContext = UserContextProfile(
                fitnessLevel: profile.fitnessLevel.rawValue
            )
            let fallbackPlan = FallbackWorkoutGenerator.generateFallbackPlan(
                for: userContext,
                day: plannedDay,
                context: modelContext
            )

            offlineMessage = "Trenér Jakub je momentálně offline, ale tady je tvůj standardní plán na dnešek. 💪"

            // Převedeme ResponsePlan na TrainerResponse (fallback kompatibilita)
            return TrainerResponse.fromFallback(fallbackPlan)
        }
    }

    // MARK: - Timeout Helper

    /// Spustí danou async operaci s časovým limitem. Pokud operace nestihne doběhnout,
    /// vyhodí `APITimeoutError`.
    private func withTimeout<T: Sendable>(
        seconds: UInt64,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw APITimeoutError()
            }

            // První dokončený task vyhrává (buď výsledek, nebo timeout)
            guard let result = try await group.next() else {
                throw APITimeoutError()
            }
            group.cancelAll()
            return result
        }
    }

    // MARK: - Private

    private func buildUserMessage(context: TrainerRequestContext) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting     = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(context)
        guard let json = String(data: data, encoding: .utf8) else {
            throw AppError.encodingFailed
        }
        return """
        Toto jsou moje dnešní data. Vygeneruj mi optimální trénink podle zadaného schématu.

        \(json)
        """
    }

    private var trainerResponseSchema: [String: Any] {
        return [
            "type": "OBJECT",
            "properties": [
                "coachMessage": ["type": "STRING"],
                "sessionLabel": ["type": "STRING"],
                "readinessLevel": ["type": "STRING"],
                "adaptationReason": ["type": "STRING", "nullable": true],
                "estimatedDurationMinutes": ["type": "INTEGER"],
                "warmUp": [
                    "type": "ARRAY",
                    "items": [
                        "type": "OBJECT",
                        "properties": [
                            "name": ["type": "STRING"],
                            "sets": ["type": "INTEGER"],
                            "reps": ["type": "STRING"],
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
                                        "name": ["type": "STRING"],
                                        "slug": ["type": "STRING"],
                                        "sets": ["type": "INTEGER"],
                                        "repsMin": ["type": "INTEGER"],
                                        "repsMax": ["type": "INTEGER"],
                                        "weightKg": ["type": "NUMBER", "nullable": true],
                                        "rir": ["type": "INTEGER"],
                                        "restSeconds": ["type": "INTEGER"],
                                        "tempo": ["type": "STRING", "nullable": true],
                                        "coachTip": ["type": "STRING", "nullable": true]
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
                            "name": ["type": "STRING"],
                            "durationSeconds": ["type": "INTEGER"],
                            "notes": ["type": "STRING", "nullable": true]
                        ],
                        "required": ["name", "durationSeconds"]
                    ]
                ]
            ],
            "required": ["coachMessage", "sessionLabel", "readinessLevel", "estimatedDurationMinutes", "warmUp", "mainBlocks", "coolDown"]
        ]
    }

    private func parseResponse(rawJSON: String) throws -> TrainerResponse {
        let cleaned = rawJSON
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```",     with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw GeminiError.jsonParsingFailed("Nelze převést na Data")
        }
        do {
            return try JSONDecoder().decode(TrainerResponse.self, from: data)
        } catch {
            throw GeminiError.jsonParsingFailed(error.localizedDescription)
        }
    }

    @discardableResult
    private func persistAIMetadata(
        response: TrainerResponse,
        date: Date,
        profile: UserProfile
    ) async -> Bool {
        guard
            let plan    = profile.workoutPlans.first(where: \.isActive),
            let session = plan.sessions.first(where: { $0.startedAt.isSameDay(as: date) })
        else { return false }

        session.aiAdaptationNote = response.adaptationReason
        session.readinessScore   = switch response.readinessLevel {
        case "green":  85.0
        case "orange": 55.0
        default:       25.0
        }
        return true
    }
}

// MARK: - SystemPromptLoader

enum SystemPromptLoader {
    static func load() -> String {
        guard
            let url  = Bundle.main.url(forResource: "SystemPrompt", withExtension: "txt"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            assertionFailure("SystemPrompt.txt nenalezen v bundle!")
            return AppConstants.fallbackSystemPrompt
        }
        return text
    }
}
