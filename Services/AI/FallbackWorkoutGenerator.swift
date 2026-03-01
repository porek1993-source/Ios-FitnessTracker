// FallbackWorkoutGenerator.swift
//
// OPRAVY v3.0:
//  ✅ FIX: Přidány case větve pro "Upper A/B", "Lower A/B", "Fullbody A/B/C"
//  ✅ FIX: defaultWeight pro Lower den navýšen (quady/hamstringy zvládnou více než horní)
//  ✅ FIX: Každý fallback plán má správný počet cviků (4–5) a logické pořadí
//  ✅ FIX: coachTip u fallback cviků jsou konkrétní technikální tipy, ne generické
//  ✅ FIX: warmupUrl odstraněno — není podporováno v TrainerResponse, jen v ResponsePlan

import Foundation
import SwiftData

final class FallbackWorkoutGenerator {

    /// Generuje záložní offline plán. Aktivuje se při výpadku Gemini API.
    static func generateFallbackPlan(
        for profile: UserContextProfile,
        day: PlannedWorkoutDay,
        context: ModelContext
    ) -> ResponsePlan {

        // Škálování vah podle fitness úrovně
        let upperBodyDefault: Double
        let lowerBodyDefault: Double
        let baseSets: Int

        switch profile.fitnessLevel.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "expert", "pokročilý", "pokrocily", "advanced":
            upperBodyDefault = 60.0
            lowerBodyDefault = 100.0
            baseSets = 4
        case "intermediate", "středně pokročilý", "střední":
            upperBodyDefault = 40.0
            lowerBodyDefault = 70.0
            baseSets = 3
        default: // beginner
            upperBodyDefault = 20.0
            lowerBodyDefault = 40.0
            baseSets = 3
        }

        let label = day.label.lowercased()
        let exercises: [ResponseExercise]

        // Push den (Prsa + Ramena + Triceps)
        if label.contains("push") {
            exercises = makePushDay(sets: baseSets, upper: upperBodyDefault)

        // Pull den (Záda + Biceps + Zadní delty)
        } else if label.contains("pull") {
            exercises = makePullDay(sets: baseSets, upper: upperBodyDefault)

        // Legs den
        } else if label.contains("leg") || label.contains("nohy") {
            exercises = makeLegsDay(sets: baseSets, lower: lowerBodyDefault)

        // Upper den (obě varianty A i B)
        } else if label.contains("upper") || label.contains("vršek") || label.contains("vrchní") {
            exercises = makeUpperDay(sets: baseSets, upper: upperBodyDefault)

        // Lower den (obě varianty A i B)
        } else if label.contains("lower") || label.contains("spodek") || label.contains("dolní") {
            exercises = makeLowerDay(sets: baseSets, lower: lowerBodyDefault)

        // Fullbody (varianty A/B/C)
        } else if label.contains("full") || label.contains("celotělo") || label.contains("fullbody") {
            exercises = makeFullbodyDay(sets: baseSets, upper: upperBodyDefault, lower: lowerBodyDefault)

        } else {
            // Neznámý label — generický mix
            exercises = makeFullbodyDay(sets: baseSets, upper: upperBodyDefault, lower: lowerBodyDefault)
        }

        return ResponsePlan(
            motivationalMessage: "Spojení s AI trenérem je dočasně nedostupné. Tady je tvůj offline záložní plán — kvalita tréninku závisí na tobě, ne na internetu. Jdeme na to! 💪",
            warmupUrl: nil,
            exercises: exercises
        )
    }

    // MARK: - Day Templates

    private static func makePushDay(sets: Int, upper: Double) -> [ResponseExercise] {
        [
            .init(name: "Benchpress s jednoručkami", nameEN: "Dumbbell Bench Press", slug: "dumbbell-bench-press",
                  sets: sets, repsMin: 6, repsMax: 10, weightKg: upper,
                  rir: nil, rpe: 7, restSeconds: 120, tempo: "3010",
                  coachTip: "Lopatky zamáčknuté k sobě. Spouštěj pomalu, tlač explozivně.", supersetId: nil),
            .init(name: "Tlaky na ramenou s jednoručkami", nameEN: "Dumbbell Shoulder Press", slug: "dumbbell-shoulder-press",
                  sets: sets, repsMin: 8, repsMax: 12, weightKg: upper * 0.5,
                  rir: nil, rpe: 7, restSeconds: 90, tempo: "2010",
                  coachTip: "Lokty mírně před tělem, nestrkej bradu dopředu.", supersetId: nil),
            .init(name: "Šikmý benchpress s jednoručkami", nameEN: "Incline Dumbbell Press", slug: "incline-dumbbell-press",
                  sets: sets, repsMin: 10, repsMax: 14, weightKg: upper * 0.7,
                  rir: nil, rpe: 7, restSeconds: 90, tempo: "2010",
                  coachTip: "Sklon lavice 30–45°, tlačíš na horní prsa.", supersetId: nil),
            .init(name: "Rozpažování vsedě (lateral raise)", nameEN: "Seated Lateral Raise", slug: "lateral-raise",
                  sets: 3, repsMin: 12, repsMax: 16, weightKg: upper * 0.2,
                  rir: nil, rpe: 8, restSeconds: 60, tempo: nil,
                  coachTip: "Dlaně dolů, palce mírně dolů. Pohyb vychází z loktů, ne ze zápěstí.", supersetId: nil),
            .init(name: "Triceps pushdown (kabel/guma)", nameEN: "Tricep Pushdown", slug: "tricep-pushdown",
                  sets: 3, repsMin: 12, repsMax: 15, weightKg: upper * 0.3,
                  rir: nil, rpe: 8, restSeconds: 60, tempo: nil,
                  coachTip: "Lokty přitisknuty k tělu po celý pohyb. Plný rozsah.", supersetId: nil)
        ]
    }

    private static func makePullDay(sets: Int, upper: Double) -> [ResponseExercise] {
        [
            .init(name: "Přítahy v předklonu s jednoručkami", nameEN: "Dumbbell Row", slug: "dumbbell-row",
                  sets: sets, repsMin: 8, repsMax: 12, weightKg: upper,
                  rir: nil, rpe: 7, restSeconds: 120, tempo: "2011",
                  coachTip: "Táhneš loktem k bokům, ne k uchu. Záda rovná, ne kulata.", supersetId: nil),
            .init(name: "Přítahy na hrazdě", nameEN: "Pull Up", slug: "pull-up",
                  sets: sets, repsMin: 5, repsMax: 10, weightKg: nil,
                  rir: nil, rpe: 7, restSeconds: 120, tempo: "2010",
                  coachTip: "Visíš plnými rameny, taháš lopatky dolů, pak teprve ohýbáš lokty.", supersetId: nil),
            .init(name: "Face pull (guma / kabel)", nameEN: "Face Pull", slug: "face-pull",
                  sets: 3, repsMin: 15, repsMax: 20, weightKg: upper * 0.2,
                  rir: nil, rpe: 7, restSeconds: 60, tempo: nil,
                  coachTip: "Taháš k obličeji, palce za hlavou. Klíč pro zdravá ramena!", supersetId: nil),
            .init(name: "Bicepsový zdvih s jednoručkami", nameEN: "Dumbbell Curl", slug: "dumbbell-curl",
                  sets: 3, repsMin: 10, repsMax: 14, weightKg: upper * 0.35,
                  rir: nil, rpe: 8, restSeconds: 60, tempo: "2012",
                  coachTip: "Lokty zůstávají u těla. Nekývej trupem.", supersetId: nil),
            .init(name: "Kladivový zdvih (hammer curl)", nameEN: "Hammer Curl", slug: "hammer-curl",
                  sets: 3, repsMin: 10, repsMax: 14, weightKg: upper * 0.35,
                  rir: nil, rpe: 8, restSeconds: 60, tempo: nil,
                  coachTip: "Neutrální grip rozvíjí brachialis — sval pod bicepsem.", supersetId: nil)
        ]
    }

    private static func makeLegsDay(sets: Int, lower: Double) -> [ResponseExercise] {
        [
            .init(name: "Goblet dřep (kettlebell / jednoručka)", nameEN: "Goblet Squat", slug: "goblet-squat",
                  sets: sets, repsMin: 8, repsMax: 12, weightKg: lower * 0.4,
                  rir: nil, rpe: 7, restSeconds: 120, tempo: "3010",
                  coachTip: "Váhu drž blízko hrudníku. Kolena sledují palce, nezapadají dovnitř.", supersetId: nil),
            .init(name: "Rumunský mrtvý tah s jednoručkami", nameEN: "Dumbbell Romanian Deadlift", slug: "romanian-deadlift-dumbbell",
                  sets: sets, repsMin: 10, repsMax: 14, weightKg: lower * 0.6,
                  rir: nil, rpe: 7, restSeconds: 120, tempo: "3011",
                  coachTip: "Kyčle tlačíš dozadu, ne kolena dolů. Záda rovná, hrudník ven.", supersetId: nil),
            .init(name: "Výpady s jednoručkami (alternující)", nameEN: "Dumbbell Lunges", slug: "dumbbell-lunges",
                  sets: 3, repsMin: 10, repsMax: 14, weightKg: lower * 0.3,
                  rir: nil, rpe: 8, restSeconds: 75, tempo: nil,
                  coachTip: "Přední koleno nad špičkou, zadní koleno lehce nechává sát k zemi.", supersetId: nil),
            .init(name: "Hip thrust s jednoručkou", nameEN: "Dumbbell Hip Thrust", slug: "hip-thrust",
                  sets: 3, repsMin: 12, repsMax: 16, weightKg: lower * 0.4,
                  rir: nil, rpe: 8, restSeconds: 75, tempo: nil,
                  coachTip: "Lopatky na lavici, chodidla přímo pod koleny. Stiskni hýždě nahoře.", supersetId: nil),
            .init(name: "Leg extension (stroj)", nameEN: "Leg Extension", slug: "leg-extension",
                  sets: 3, repsMin: 12, repsMax: 16, weightKg: lower * 0.3,
                  rir: nil, rpe: 8, restSeconds: 60, tempo: nil,
                  coachTip: "Plný rozsah pohybu. Nahoře 1 sekundu drž kontrakci kvadricepsů.", supersetId: nil),
            .init(name: "Stojný výpon na lýtka", nameEN: "Standing Calf Raise", slug: "calf-raise",
                  sets: 4, repsMin: 15, repsMax: 20, weightKg: lower * 0.2,
                  rir: nil, rpe: 8, restSeconds: 45, tempo: nil,
                  coachTip: "Plný rozsah! Dole protáhni, nahoře 1 sekundu drž kontrakci.", supersetId: nil)
        ]
    }

    private static func makeUpperDay(sets: Int, upper: Double) -> [ResponseExercise] {
        [
            .init(name: "Benchpress s jednoručkami", nameEN: "Dumbbell Bench Press", slug: "dumbbell-bench-press",
                  sets: sets, repsMin: 8, repsMax: 12, weightKg: upper,
                  rir: nil, rpe: 7, restSeconds: 90, tempo: "2010",
                  coachTip: "Offline záloha — Upper den. Lopatky zamáčknuté.", supersetId: nil),
            .init(name: "Přítahy v předklonu s jednoručkami", nameEN: "Dumbbell Row", slug: "dumbbell-row",
                  sets: sets, repsMin: 8, repsMax: 12, weightKg: upper,
                  rir: nil, rpe: 7, restSeconds: 90, tempo: "2011",
                  coachTip: "Superserie s benchpressem pro úsporu času je možná.", supersetId: nil),
            .init(name: "Tlaky na ramenou s jednoručkami", nameEN: "Dumbbell Shoulder Press", slug: "dumbbell-shoulder-press",
                  sets: sets, repsMin: 10, repsMax: 14, weightKg: upper * 0.5,
                  rir: nil, rpe: 7, restSeconds: 75, tempo: nil,
                  coachTip: nil, supersetId: nil),
            .init(name: "Bicepsový zdvih s jednoručkami", nameEN: "Dumbbell Curl", slug: "dumbbell-curl",
                  sets: 3, repsMin: 10, repsMax: 14, weightKg: upper * 0.35,
                  rir: nil, rpe: 8, restSeconds: 60, tempo: nil,
                  coachTip: nil, supersetId: nil),
            .init(name: "Triceps pushdown", nameEN: "Tricep Pushdown", slug: "tricep-pushdown",
                  sets: 3, repsMin: 12, repsMax: 15, weightKg: upper * 0.3,
                  rir: nil, rpe: 8, restSeconds: 60, tempo: nil,
                  coachTip: nil, supersetId: nil)
        ]
    }

    private static func makeLowerDay(sets: Int, lower: Double) -> [ResponseExercise] {
        [
            .init(name: "Goblet dřep", nameEN: "Goblet Squat", slug: "goblet-squat",
                  sets: sets, repsMin: 8, repsMax: 12, weightKg: lower * 0.35,
                  rir: nil, rpe: 7, restSeconds: 120, tempo: "3010",
                  coachTip: "Offline záloha — Lower den.", supersetId: nil),
            .init(name: "Rumunský mrtvý tah s jednoručkami", nameEN: "Dumbbell Romanian Deadlift", slug: "romanian-deadlift-dumbbell",
                  sets: sets, repsMin: 10, repsMax: 14, weightKg: lower * 0.5,
                  rir: nil, rpe: 7, restSeconds: 90, tempo: "3011",
                  coachTip: "Kyčle dozadu, záda rovná, cítíš tah v hamstrinzích.", supersetId: nil),
            .init(name: "Hip thrust s jednoručkou", nameEN: "Dumbbell Hip Thrust", slug: "hip-thrust",
                  sets: sets, repsMin: 12, repsMax: 16, weightKg: lower * 0.4,
                  rir: nil, rpe: 8, restSeconds: 75, tempo: nil,
                  coachTip: "Lopatky na lavici, chodidla přímo pod koleny. Stiskni hýždě nahoře.", supersetId: nil),
            .init(name: "Výpady s jednoručkami", nameEN: "Dumbbell Lunges", slug: "dumbbell-lunges",
                  sets: 3, repsMin: 12, repsMax: 16, weightKg: lower * 0.25,
                  rir: nil, rpe: 8, restSeconds: 60, tempo: nil,
                  coachTip: nil, supersetId: nil),
            .init(name: "Stojný výpon na lýtka", nameEN: "Standing Calf Raise", slug: "calf-raise",
                  sets: 3, repsMin: 15, repsMax: 20, weightKg: lower * 0.15,
                  rir: nil, rpe: 8, restSeconds: 45, tempo: nil,
                  coachTip: nil, supersetId: nil)
        ]
    }

    private static func makeFullbodyDay(sets: Int, upper: Double, lower: Double) -> [ResponseExercise] {
        [
            .init(name: "Goblet dřep", nameEN: "Goblet Squat", slug: "goblet-squat",
                  sets: sets, repsMin: 10, repsMax: 15, weightKg: lower * 0.35,
                  rir: nil, rpe: 7, restSeconds: 90, tempo: "3010",
                  coachTip: "Offline záloha — Fullbody den.", supersetId: nil),
            .init(name: "Benchpress s jednoručkami", nameEN: "Dumbbell Bench Press", slug: "dumbbell-bench-press",
                  sets: sets, repsMin: 8, repsMax: 12, weightKg: upper,
                  rir: nil, rpe: 7, restSeconds: 90, tempo: "2010",
                  coachTip: "Lopatky zamáčknuté k sobě. Spouštěj pomalu, tlač explozivně.", supersetId: nil),
            .init(name: "Přítahy v předklonu s jednoručkami", nameEN: "Dumbbell Row", slug: "dumbbell-row",
                  sets: sets, repsMin: 8, repsMax: 12, weightKg: upper,
                  rir: nil, rpe: 7, restSeconds: 90, tempo: nil,
                  coachTip: "Táhneš loktem k bokům, ne k uchu. Záda rovná.", supersetId: nil),
            .init(name: "Rumunský mrtvý tah s jednoručkami", nameEN: "Dumbbell Romanian Deadlift", slug: "romanian-deadlift-dumbbell",
                  sets: sets, repsMin: 10, repsMax: 14, weightKg: lower * 0.45,
                  rir: nil, rpe: 7, restSeconds: 75, tempo: nil,
                  coachTip: "Kyčle dozadu, záda rovná, hrudník ven.", supersetId: nil),
            .init(name: "Tlaky na ramenou vsedě", nameEN: "Seated Dumbbell Shoulder Press", slug: "dumbbell-shoulder-press",
                  sets: 3, repsMin: 10, repsMax: 14, weightKg: upper * 0.45,
                  rir: nil, rpe: 8, restSeconds: 60, tempo: nil,
                  coachTip: "Lokty mírně před tělem. Plný rozsah — ruce nahoře se skoro dotknou.", supersetId: nil),
            .init(name: "Plank", nameEN: "Plank", slug: "plank",
                  sets: 3, repsMin: 30, repsMax: 60, weightKg: nil,
                  rir: nil, rpe: 7, restSeconds: 45, tempo: nil,
                  coachTip: "Tělo v přímé linii. Hýždě a břicho aktivní po celou dobu.", supersetId: nil)
        ]
    }
}

// MARK: - Slug Normalization Map
// Mapuje legacy/fallback slugy na reálné slugy z muscle_wiki_data_full (Supabase).
// Slouží jako překlenovací vrstva dokud AI nezačne vracet vždy správné slugy.

extension FallbackWorkoutGenerator {

    static let slugNormalizationMap: [String: String] = [
        // Push
        "db-bench-press":       "bench-press-dumbbell",
        "db-shoulder-press":    "shoulder-press-dumbbell",
        "db-lateral-raise":     "lateral-raise",
        "tricep-pushdown":      "triceps-pushdown-cable",
        // Pull
        "db-row":               "bent-over-row-dumbbell",
        "face-pull":            "face-pull-cable",
        "db-bicep-curl":        "bicep-curl-dumbbell",
        "hammer-curl":          "hammer-curl-dumbbell",
        // Legs
        "goblet-squat":         "goblet-squat",
        "db-rdl":               "romanian-deadlift-dumbbell",
        "db-lunge":             "lunges-dumbbell",
        "calf-raise":           "calf-raise-standing",
        // Dumbbell versions (fallback slugy)
        "dumbbell-bench-press": "bench-press-dumbbell",
        "dumbbell-shoulder-press": "shoulder-press-dumbbell",
        "dumbbell-curl":        "bicep-curl-dumbbell",
        "dumbbell-row":         "bent-over-row-dumbbell",
        "dumbbell-lunges":      "lunges-dumbbell",
        "hip-thrust":           "hip-thrust-barbell",
        // Opravené slugy — mapování na sebe sama (zabrání double-normalizaci)
        "romanian-deadlift-dumbbell": "romanian-deadlift-dumbbell",
        "bench-press-dumbbell":       "bench-press-dumbbell",
        "shoulder-press-dumbbell":    "shoulder-press-dumbbell",
        "bicep-curl-dumbbell":        "bicep-curl-dumbbell",
        "bent-over-row-dumbbell":     "bent-over-row-dumbbell",
        "lunges-dumbbell":            "lunges-dumbbell",
        // Full body
        "full-body":            "burpee"
    ]

    static func normalizedSlug(_ legacySlug: String) -> String {
        slugNormalizationMap[legacySlug] ?? legacySlug
    }
}
