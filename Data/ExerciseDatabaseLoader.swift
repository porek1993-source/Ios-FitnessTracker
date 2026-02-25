// ExerciseDatabaseLoader.swift
// Načte ExerciseDatabase.json do SwiftData při prvním spuštění aplikace.

import SwiftData
import Foundation

/// Dekódovatelná struktura z ExerciseDatabase.json
private struct ExerciseJSON: Decodable {
    let slug: String
    let name: String
    let nameEN: String
    let category: String
    let movementPattern: String
    let equipment: [String]
    let musclesTarget: [String]
    let musclesSecondary: [String]
    let isUnilateral: Bool
    let instructions: String
    let breathingTip: String?
    let commonMistakes: String?
    let videoURL: String?
}

enum ExerciseDatabaseLoader {

    /// Seeduje databázi cviků z JSON souboru.
    /// Volá se při startu aplikace — pokud cviky už existují, přeskočí.
    static func seedIfNeeded(context: ModelContext) {
        let existingCount = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        guard existingCount == 0 else {
            AppLogger.info("ExerciseDatabaseLoader: \(existingCount) cviků již existuje, seed přeskočen.")
            return
        }

        guard let url = Bundle.main.url(forResource: "ExerciseDatabase", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            AppLogger.error("ExerciseDatabaseLoader: Nelze načíst ExerciseDatabase.json z bundle!")
            return
        }

        let decoder = JSONDecoder()
        guard let exercises = try? decoder.decode([ExerciseJSON].self, from: data) else {
            AppLogger.error("ExerciseDatabaseLoader: Chyba při dekódování JSON!")
            return
        }

        var inserted = 0
        for json in exercises {
            let exercise = Exercise(
                slug: json.slug,
                name: json.name,
                nameEN: json.nameEN,
                category: ExerciseCategory(rawValue: json.category) ?? .chest,
                movementPattern: MovementPattern(rawValue: json.movementPattern) ?? .isolation,
                equipment: json.equipment.compactMap { Equipment(rawValue: $0) },
                musclesTarget: json.musclesTarget.compactMap { MuscleGroup(rawValue: $0) },
                musclesSecondary: json.musclesSecondary.compactMap { MuscleGroup(rawValue: $0) },
                isUnilateral: json.isUnilateral,
                instructions: buildInstructions(json: json)
            )
            exercise.videoURL = json.videoURL
            context.insert(exercise)
            inserted += 1
        }

        do {
            try context.save()
            AppLogger.info("ExerciseDatabaseLoader: Seedováno \(inserted) cviků.")
        } catch {
            AppLogger.error("ExerciseDatabaseLoader: Chyba při ukládání: \(error)")
        }
    }

    // MARK: - Private helpers

    private static func buildInstructions(json: ExerciseJSON) -> String {
        var parts: [String] = []
        if !json.instructions.isEmpty {
            parts.append(json.instructions)
        }
        if let breathing = json.breathingTip, !breathing.isEmpty {
            parts.append("🫁 Dýchání: \(breathing)")
        }
        if let mistakes = json.commonMistakes, !mistakes.isEmpty {
            parts.append("⚠️ Časté chyby: \(mistakes)")
        }
        return parts.joined(separator: "\n\n")
    }
}
