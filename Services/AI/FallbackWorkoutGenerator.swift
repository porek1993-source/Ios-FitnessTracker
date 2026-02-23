// FallbackWorkoutGenerator.swift
import Foundation
import SwiftData

final class FallbackWorkoutGenerator {
    
    /// Generuje statický (záchranný) trénink na základě dne a dostupné historie.
    /// V produkční verzi by zde byl komplexnější algoritmus pro progresivní přetížení.
    static func generateFallbackPlan(for profile: UserContextProfile, day: PlannedWorkoutDay, context: ModelContext) -> ResponsePlan {
        
        // Simulujeme jednoduchá pravidla na základě profilu
        let baseSets = profile.fitnessLevel == "Pokročilý" ? 4 : 3
        let baseRepsMin = 8
        let baseRepsMax = 12
        let defaultWeight = 50.0 // Záložní váha
        
        var fallbackExercises = [ResponseExercise]()
        
        switch day.label.lowercased() {
        case _ where day.label.lowercased().contains("push"):
            fallbackExercises = [
                ResponseExercise(
                    name: "Tlaky s jednoručkami (Fallback)", slug: "db-bench-press",
                    coachTip: "Soustřeď se na čistou techniku. Trenér Jakub je momentálně offline, ale tohle tě udrží ve hře.",
                    sets: baseSets, repsMin: baseRepsMin, repsMax: baseRepsMax,
                    weightKg: defaultWeight, rpe: 7, tempo: "2111", restSeconds: 90
                ),
                ResponseExercise(
                    name: "Rozpažování s jednoručkami", slug: "db-fly",
                    coachTip: "Kontroluj pohyb směrem dolů.",
                    sets: baseSets, repsMin: 10, repsMax: 15,
                    weightKg: 15.0, rpe: 8, tempo: "3111", restSeconds: 60
                )
            ]
        case _ where day.label.lowercased().contains("pull"):
            fallbackExercises = [
                ResponseExercise(
                    name: "Přítahy v předklonu (Fallback)", slug: "db-row",
                    coachTip: "Táhneš loktem, ne dlaní. Offline záloha.",
                    sets: baseSets, repsMin: baseRepsMin, repsMax: baseRepsMax,
                    weightKg: defaultWeight, rpe: 7, tempo: "2111", restSeconds: 90
                )
            ]
        case _ where day.label.lowercased().contains("leg"):
            fallbackExercises = [
                ResponseExercise(
                    name: "Goblet Dřep (Fallback)", slug: "goblet-squat",
                    coachTip: "Drž váhu blízko těla. Offline záloha.",
                    sets: baseSets, repsMin: 10, repsMax: 15,
                    weightKg: defaultWeight * 0.5, rpe: 7, tempo: "3111", restSeconds: 90
                )
            ]
        default:
            fallbackExercises = [
                ResponseExercise(
                    name: "Full Body Mix (Fallback)", slug: "full-body",
                    coachTip: "Nouzový režim. Dneska to odjedeme na pocit.",
                    sets: baseSets, repsMin: 10, repsMax: 12,
                    weightKg: defaultWeight, rpe: 7, tempo: "2020", restSeconds: 60
                )
            ]
        }
        
        return ResponsePlan(
            motivationalMessage: "Záchranná brzda aktivována. 🛟 Trenér Jakub je momentálně offline (výpadek spojení), ale trénink tím nekončí. Vygeneroval jsem pro tebe tento základní offline plán. Jdeme na to!",
            warmupUrl: "https://example.com/warmup",
            exercises: fallbackExercises
        )
    }
}
