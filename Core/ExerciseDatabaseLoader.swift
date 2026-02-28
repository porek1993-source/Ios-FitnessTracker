// ExerciseDatabaseLoader.swift
// Seeding lokální databáze cviků z přibaleného JSON souboru.

import Foundation
import SwiftData

struct ExerciseDatabaseLoader {
    
    /// Provede prvotní import cviků, pokud je databáze prázdná.
    static func seedIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Exercise>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        
        guard count == 0 else {
            AppLogger.info("ℹ️ [ExerciseDatabaseLoader] Databáze cviků již obsahuje data (\(count) záznamů). Přeskakuji seed.")
            return
        }
        
        AppLogger.info("⏳ [ExerciseDatabaseLoader] Spouštím prvotní seed databáze cviků...")
        
        guard let url = Bundle.main.url(forResource: "ExerciseDatabase", withExtension: "json") else {
            AppLogger.error("❌ [ExerciseDatabaseLoader] Soubor ExerciseDatabase.json nebyl nalezen v bundle!")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let seeds = try decoder.decode([ExerciseSeedDTO].self, from: data)
            
            for seed in seeds {
                // Převod Stringů z JSONu na typované Enumy modelu
                let category = ExerciseCategory(rawValue: seed.category) ?? .chest
                let pattern = MovementPattern(rawValue: seed.movementPattern) ?? .isolation
                let equipment = seed.equipment.compactMap { Equipment(rawValue: $0) }
                
                // Svaly používají bezpečný mapper MuscleGroup.from(supabaseKey:)
                let target = seed.musclesTarget.compactMap { MuscleGroup.from(supabaseKey: $0) }
                let secondary = seed.musclesSecondary.compactMap { MuscleGroup.from(supabaseKey: $0) }
                
                let exercise = Exercise(
                    slug: seed.slug,
                    name: seed.name,
                    nameEN: seed.nameEN,
                    category: category,
                    movementPattern: pattern,
                    equipment: equipment,
                    musclesTarget: target,
                    musclesSecondary: secondary,
                    isUnilateral: seed.isUnilateral,
                    instructions: seed.instructions
                )
                modelContext.insert(exercise)
            }
            
            try modelContext.save()
            AppLogger.info("✅ [ExerciseDatabaseLoader] Úspěšně naimportováno \(seeds.count) cviků do SwiftData.")
            
        } catch {
            AppLogger.error("❌ [ExerciseDatabaseLoader] Chyba při parsování/ukládání seed dat: \(error)")
        }
    }
}

// MARK: - Private DTO for JSON Decoding

private struct ExerciseSeedDTO: Decodable {
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
}
