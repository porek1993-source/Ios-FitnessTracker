// ExerciseAIEnrichmentService.swift
// Služba pro dogenerování chybějících dat o cvicích přes Gemini API.

import Foundation

actor ExerciseAIEnrichmentService {

    private let apiClient: GeminiAPIClient

    init(apiKey: String = AppConstants.geminiAPIKey) {
        self.apiClient = GeminiAPIClient(apiKey: apiKey)
    }

    /// Vygeneruje chybějící data (vybavení, svaly, instrukce) pro cvik.
    /// Prompt vynucuje výstup STRIKTNĚ v češtině.
    func enrichExercise(nameCz: String) async throws -> AIEnrichedExerciseData {
        let systemPrompt = """
        Jsi odborný fitness trenér a databázový kurátor. Tvým úkolem je doplnit chybějící informace o cvicích.
        VŽDY odpovídej POUZE v češtině. Nikdy nepoužívej angličtinu.
        Odpovídej POUZE validním JSON objektem bez jakéhokoli dalšího textu.
        """

        let userMessage = """
        Doplň chybějící data pro cvik: "\(nameCz)"

        Vrať JSON v tomto přesném formátu:
        {
            "equipment": "název vybavení česky (např. Velká činka, Jednoručky, Vlastní váha, Kabelový stroj, Posilovací stroj)",
            "primaryMuscles": ["Hlavní sval česky", "Sekundární sval česky"],
            "instructions": "1. 💡 Správná technika: [popis]\\n2. 🫁 Dýchání: [popis]\\n3. ⚠️ Časté chyby: [popis]\\n4. 🎯 Na co se soustředit: [popis]"
        }

        Příklady názvů svalů v češtině: Hrudník, Triceps, Biceps, Přední deltoid, Boční deltoid, Zadní deltoid, Latissimus, Trapéz, Romboid, Kvadriceps, Hamstringy, Hýžďové svaly, Lýtka, Core, Předloktí.
        Příklady vybavení v češtině: Velká činka, Jednoručky, EZ činka, Vlastní váha, Kabelový stroj, Posilovací stroj, TRX, Kettlebell, Odporová guma.
        """

        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "equipment":      ["type": "STRING"],
                "primaryMuscles": ["type": "ARRAY", "items": ["type": "STRING"]],
                "instructions":   ["type": "STRING"]
            ],
            "required": ["equipment", "primaryMuscles", "instructions"]
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
            throw GeminiError.jsonParsingFailed("Nelze převést AI odpověď na Data")
        }

        return try JSONDecoder().decode(AIEnrichedExerciseData.self, from: data)
    }
}
