// AIReschedulingEngine.swift
// Motor pro přeskládání tréninků v rámci 7denního okna přes Gemini.

import Foundation

struct RescheduledDay: Codable {
    let dayIndex: Int
    let label: String
    let focus: String

    /// Datum dne (kalkulováno lokálně, ne z AI).
    var date: Date {
        Calendar.current.date(byAdding: .day, value: dayIndex, to: Calendar.current.startOfDay(for: .now))!
    }
}

struct RescheduleResponse: Codable {
    let days: [RescheduledDay]
    let reasoning: String
}

enum AIReschedulingEngine {

    /// Přepočítá rozložení tréninků v 7denním okně na základě nového stavu dnů.
    static func recalculateWeek(
        currentDays: [WeekDay],
        availableWorkoutDays: Int,
        totalDays: Int
    ) async throws -> [RescheduledDay] {

        let apiClient = GeminiAPIClient(apiKey: AppConstants.geminiAPIKey)

        let systemPrompt = """
        Jsi expertní fitness plánovač. Tvým úkolem je přeskládat tréninkový týden.
        VŽDY odpovídej POUZE v češtině. Nikdy nepoužívej angličtinu.
        Odpovídej POUZE validním JSON objektem.

        Pravidla:
        - Rozlož tréninky tak, aby se za daný počet dnů procvičilo celé tělo.
        - Pokud je k dispozici 4–5 dnů → Push/Pull/Legs/Upper/Lower split.
        - Pokud je k dispozici 3 dny → Upper/Lower/Fullbody nebo Push/Pull/Legs.
        - Pokud je k dispozici 2 dny → 2× Fullbody.
        - Pokud je k dispozici 1 den → 1× Fullbody.
        - Nikdy neplánuj dva po sobě jdoucí dny se stejnou svalovou skupinou.
        - Zohledni, které dny uživatel označil jako volno nebo jiný sport.
        """

        // Sestavíme popis aktuálního stavu týdne
        let dayDescriptions = currentDays.enumerated().map { idx, day in
            let status: String
            switch day.dayType {
            case .workout:
                status = day.isOverridden ? "TRÉNINK (uživatelem potvrzený)" : "TRÉNINK (původní plán: \(day.label))"
            case .rest:
                status = "VOLNO"
            case .sport:
                status = "JINÝ SPORT (\(day.label))"
            case .cardio:
                status = "KARDIO"
            }
            return "Den \(idx) (\(day.czechDayName) \(day.dayNumber).): \(status)"
        }.joined(separator: "\n")

        let userMessage = """
        Uživatel má tento týden následující rozložení:

        \(dayDescriptions)

        K dispozici pro silový trénink: \(availableWorkoutDays) dnů ze \(totalDays).

        Přeskládej POUZE tréninkové dny. Dny označené jako VOLNO, JINÝ SPORT nebo KARDIO NEMĚŇ.
        Vrať nový plán pro tréninkové dny s optimálním rozložením svalových skupin.
        """

        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "days": [
                    "type": "ARRAY",
                    "items": [
                        "type": "OBJECT",
                        "properties": [
                            "dayIndex": ["type": "INTEGER"],
                            "label":    ["type": "STRING"],
                            "focus":    ["type": "STRING"]
                        ],
                        "required": ["dayIndex", "label", "focus"]
                    ]
                ],
                "reasoning": ["type": "STRING"]
            ],
            "required": ["days", "reasoning"]
        ]

        let rawJSON = try await apiClient.generate(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            responseSchema: schema
        )

        let cleaned = rawJSON
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw GeminiError.jsonParsingFailed("Nelze převést AI odpověď")
        }

        let response = try JSONDecoder().decode(RescheduleResponse.self, from: data)
        return response.days
    }
}
