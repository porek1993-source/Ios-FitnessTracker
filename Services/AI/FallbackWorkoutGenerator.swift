// FallbackWorkoutGenerator.swift
import Foundation
import SwiftData

final class FallbackWorkoutGenerator {
    
    /// Generuje statický (záchranný) trénink na základě dne a dostupné historie.
    /// V produkční verzi by zde byl komplexnější algoritmus pro progresivní přetížení.
    static func generateFallbackPlan(for profile: UserContextProfile, day: PlannedWorkoutDay, context: ModelContext) -> ResponsePlan {
        
        // Škálování vah podle fitness levelu
        let baseSets = profile.fitnessLevel == "Pokročilý" ? 4 : 3
        let baseRepsMin = 8
        let baseRepsMax = 12
        
        // Základní váha škálovaná podle úrovně (místo hardcoded 50 kg)
        let defaultWeight: Double
        switch profile.fitnessLevel.lowercased() {
        case "expert", "pokročilý": defaultWeight = 60.0
        case "intermediate", "středně pokročilý": defaultWeight = 40.0
        default: defaultWeight = 25.0  // začátečník
        }
        
        var fallbackExercises = [ResponseExercise]()
        
        switch day.label.lowercased() {
        case _ where day.label.lowercased().contains("push"):
            fallbackExercises = [
                ResponseExercise(name: "Benchpress s jednoručkami", slug: "db-bench-press",
                    sets: baseSets, repsMin: baseRepsMin, repsMax: baseRepsMax,
                    weightKg: defaultWeight, rir: nil, rpe: 7, restSeconds: 90,
                    tempo: "2111", coachTip: "Soustřeď se na čistou techniku. Offline záloha."),
                ResponseExercise(name: "Tlaky na ramenou vsedě (jednorucky)", slug: "db-shoulder-press",
                    sets: baseSets, repsMin: 10, repsMax: 14,
                    weightKg: defaultWeight * 0.4, rir: nil, rpe: 7, restSeconds: 75,
                    tempo: "2111", coachTip: "Lokty mírně před tělem. Nestrkej bradu dopředu."),
                ResponseExercise(name: "Rozpažování vsedě (lateral raise)", slug: "db-lateral-raise",
                    sets: 3, repsMin: 12, repsMax: 16,
                    weightKg: defaultWeight * 0.2, rir: nil, rpe: 8, restSeconds: 60,
                    tempo: "2013", coachTip: "Dlaně dolů, palce mírně dolů. Pohyb vychází z loktů."),
                ResponseExercise(name: "Triceps pushdown (kabel/guma)", slug: "tricep-pushdown",
                    sets: 3, repsMin: 12, repsMax: 15,
                    weightKg: defaultWeight * 0.3, rir: nil, rpe: 8, restSeconds: 60,
                    tempo: "2011", coachTip: "Lokty přitisknuty k tělu. Celý pohyb z předloktí.")
            ]
        case _ where day.label.lowercased().contains("pull"):
            fallbackExercises = [
                ResponseExercise(name: "Přítahy v předklonu (jednorucky)", slug: "db-row",
                    sets: baseSets, repsMin: baseRepsMin, repsMax: baseRepsMax,
                    weightKg: defaultWeight, rir: nil, rpe: 7, restSeconds: 90,
                    tempo: "2111", coachTip: "Táhneš loktem, ne dlaní. Offline záloha."),
                ResponseExercise(name: "Face pull (guma / kabel)", slug: "face-pull",
                    sets: 3, repsMin: 15, repsMax: 20,
                    weightKg: defaultWeight * 0.25, rir: nil, rpe: 7, restSeconds: 60,
                    tempo: "2013", coachTip: "Taháš k obličeji, palce za hlavou. Výborná prevence zranění ramen."),
                ResponseExercise(name: "Bicepsový zdvih s jednoručkami", slug: "db-bicep-curl",
                    sets: 3, repsMin: 10, repsMax: 14,
                    weightKg: defaultWeight * 0.35, rir: nil, rpe: 8, restSeconds: 60,
                    tempo: "2012", coachTip: "Lokty zůstávají u těla. Nekývej trupem."),
                ResponseExercise(name: "Kladivový zdvih (hammer curl)", slug: "hammer-curl",
                    sets: 3, repsMin: 10, repsMax: 14,
                    weightKg: defaultWeight * 0.35, rir: nil, rpe: 8, restSeconds: 60,
                    tempo: "2011", coachTip: "Neutrální grip. Zapojuješ brachialis i biceps.")
            ]
        case _ where day.label.lowercased().contains("leg") || day.label.lowercased().contains("nohy") || day.label.lowercased() == "legs":
            fallbackExercises = [
                ResponseExercise(name: "Goblet Dřep (kettlebell/jednorucka)", slug: "goblet-squat",
                    sets: baseSets, repsMin: 10, repsMax: 15,
                    weightKg: defaultWeight * 0.5, rir: nil, rpe: 7, restSeconds: 90,
                    tempo: "3111", coachTip: "Drž váhu blízko hrudníku. Kolena sledují palce."),
                ResponseExercise(name: "Rumunský mrtvý tah s jednoručkami", slug: "db-rdl",
                    sets: baseSets, repsMin: 10, repsMax: 14,
                    weightKg: defaultWeight * 0.7, rir: nil, rpe: 7, restSeconds: 90,
                    tempo: "3011", coachTip: "Hrbíš záda → zábrzda! Tlačíš kyčlemi zpátky, ne dolů."),
                ResponseExercise(name: "Výpady s jednoručkami (alternující)", slug: "db-lunge",
                    sets: 3, repsMin: 12, repsMax: 16,
                    weightKg: defaultWeight * 0.4, rir: nil, rpe: 8, restSeconds: 75,
                    tempo: "2111", coachTip: "Krok vpřed, koleno předního chodidla nad špičkou."),
                ResponseExercise(name: "Lýtkový zdvih (stojíš/sedíš)", slug: "calf-raise",
                    sets: 4, repsMin: 15, repsMax: 20,
                    weightKg: defaultWeight * 0.3, rir: nil, rpe: 8, restSeconds: 45,
                    tempo: "2013", coachTip: "Plný rozsah pohybu. Dole protáhni, nahoře stiski.")
            ]
        case _ where day.label.lowercased().contains("upper") || day.label.lowercased().contains("vrsek"):
            fallbackExercises = [
                ResponseExercise(name: "Benchpress s jednoručkami", slug: "db-bench-press",
                    sets: baseSets, repsMin: baseRepsMin, repsMax: baseRepsMax,
                    weightKg: defaultWeight, rir: nil, rpe: 7, restSeconds: 90,
                    tempo: "2111", coachTip: "Offline záloha – upper den."),
                ResponseExercise(name: "Přítahy v předklonu (jednorucky)", slug: "db-row",
                    sets: baseSets, repsMin: baseRepsMin, repsMax: baseRepsMax,
                    weightKg: defaultWeight, rir: nil, rpe: 7, restSeconds: 90,
                    tempo: "2111", coachTip: "Superserie s pressem pro úsporu času."),
                ResponseExercise(name: "Tlaky na ramenou vsedě (jednorucky)", slug: "db-shoulder-press",
                    sets: 3, repsMin: 10, repsMax: 14,
                    weightKg: defaultWeight * 0.4, rir: nil, rpe: 7, restSeconds: 75,
                    tempo: "2111", coachTip: nil),
                ResponseExercise(name: "Bicepsový zdvih s jednoručkami", slug: "db-bicep-curl",
                    sets: 3, repsMin: 10, repsMax: 14,
                    weightKg: defaultWeight * 0.35, rir: nil, rpe: 8, restSeconds: 60,
                    tempo: "2012", coachTip: nil)
            ]
        case _ where day.label.lowercased().contains("full") || day.label.lowercased().contains("celotelo"):
            fallbackExercises = [
                ResponseExercise(name: "Goblet Dřep", slug: "goblet-squat",
                    sets: 3, repsMin: 10, repsMax: 15,
                    weightKg: defaultWeight * 0.5, rir: nil, rpe: 7, restSeconds: 75, tempo: "3111", coachTip: nil),
                ResponseExercise(name: "Benchpress s jednoručkami", slug: "db-bench-press",
                    sets: 3, repsMin: baseRepsMin, repsMax: baseRepsMax,
                    weightKg: defaultWeight, rir: nil, rpe: 7, restSeconds: 75, tempo: "2111", coachTip: nil),
                ResponseExercise(name: "Přítahy v předklonu (jednorucky)", slug: "db-row",
                    sets: 3, repsMin: baseRepsMin, repsMax: baseRepsMax,
                    weightKg: defaultWeight, rir: nil, rpe: 7, restSeconds: 75, tempo: "2111", coachTip: nil),
                ResponseExercise(name: "Rumunský mrtvý tah", slug: "db-rdl",
                    sets: 3, repsMin: 10, repsMax: 14,
                    weightKg: defaultWeight * 0.7, rir: nil, rpe: 7, restSeconds: 75, tempo: "3011", coachTip: nil)
            ]
        default:
            fallbackExercises = [
                ResponseExercise(
                    name: "Full Body Mix (Fallback)", slug: "full-body",
                    sets: baseSets, repsMin: 10, repsMax: 12,
                    weightKg: defaultWeight, rir: nil, rpe: 7, restSeconds: 60,
                    tempo: "2020", coachTip: "Nouzový režim. Dneska to odjedeme na pocit."
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
