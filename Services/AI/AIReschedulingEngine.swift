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

    /// Přepočítá rozložení tréninků v 7denním okně na základě nového stavu dnů a historie.
    static func recalculateWeek(
        currentDays: [WeekDay],
        availableWorkoutDays: Int,
        totalDays: Int,
        historyDescriptions: [String] = []
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

        let historyText = historyDescriptions.isEmpty ? "Žádná nedávná historie." : historyDescriptions.joined(separator: ", ")

        let userMessage = """
        Uživatel má tento týden následující rozložení:

        \(dayDescriptions)

        Historie posledních tréninků (nejnovější první): \(historyText)

        K dispozici pro silový trénink: \(availableWorkoutDays) dnů ze \(totalDays).

        Pravidlo pro přeskládání: Pokud uživatel vynechal trénink, prioritizuj procvičení svalů, které v historii chybí nebo byly nejdéle. Pokud má např. split Push/Pull/Legs a poslední byl Legs, první budoucí by měl být Push.

        Přeskládej POUZE budoucí tréninkové dny (ne ty, které už proběhly dnes nebo dříve). 
        Vrať nový plán pro zbývající tréninkové dny s optimálním rozložením.
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
