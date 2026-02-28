// WorkoutPlanGenerator.swift
// Agilní Fitness Trenér — Generátor tréninkového plánu po onboardingu
//
// OPRAVY v3.0:
//  ✅ KRITICKÁ OPRAVA: sets/reps/rest adaptovány na fitnessLevel a primaryGoal
//  ✅ KRITICKÁ OPRAVA: Cviky vybírány s respektováním equipment profilu uživatele
//  ✅ FIX: Compound cviky mají jiné parametry než izolace (vědecky správně)
//  ✅ FIX: Princip velká+malá partie (prsa+triceps, záda+biceps) správně zachován
//  ✅ FIX: 2× týdně frekvence pro každou svalovou partii (meta-analýzy Schoenfeld 2016)
//  ✅ FIX: PPL 4-denní varianta = Push/Pull/Legs/Upper B (logické) místo /Upper (nelogické)
//  ✅ NOVÉ: Fullbody A/B/C s různými compound cviky — různé stimulus v každém tréninku
//  ✅ NOVÉ: Upper A/B/C — A=press-dominant, B=pull-dominant, pro optimální frekvenci
//  ✅ OPRAVENO: chybějící schedule builder ("// ... rest of the builder code stays same ...")

import SwiftData
import Foundation

enum WorkoutPlanGenerator {

    // MARK: - Public API

    @discardableResult
    static func generate(for profile: UserProfile, in context: ModelContext) -> WorkoutPlan {
        if let existing = profile.workoutPlans.first(where: { $0.isActive }) {
            return existing
        }

        let split = profile.preferredSplitType
        let days  = profile.availableDaysPerWeek

        let plan = WorkoutPlan(
            title: planTitle(split: split),
            splitType: split,
            durationWeeks: 8
        )
        plan.owner = profile
        context.insert(plan)

        let schedule = buildSchedule(split: split, daysPerWeek: min(days, 6))
        let allExercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []

        for entry in schedule {
            let day = PlannedWorkoutDay(
                dayOfWeek: entry.dayOfWeek,
                label: entry.label,
                isRestDay: false
            )
            day.plan = plan
            context.insert(day)

            let configs = getExerciseConfigs(
                for: entry.label,
                allExercises: allExercises,
                profile: profile
            )
            for (idx, config) in configs.enumerated() {
                let plannedEx = PlannedExercise(
                    order: idx,
                    exercise: config.exercise,
                    fallbackSlug: config.fallbackSlug,
                    fallbackName: config.fallbackName,
                    targetSets: config.sets,
                    targetRepsMin: config.repsMin,
                    targetRepsMax: config.repsMax,
                    targetRIR: config.rir,
                    restSeconds: config.restSeconds
                )
                plannedEx.plannedDay = day
                context.insert(plannedEx)
            }
        }

        profile.workoutPlans.append(plan)
        do {
            try context.save()
        } catch {
            Task { @MainActor in
                AppLogger.error("WorkoutPlanGenerator: Chyba při ukládání plánu: \(error)")
            }
        }
        return plan
    }

    // MARK: - Exercise Config

    private struct ExerciseConfig {
        let exercise: Exercise?
        let fallbackSlug: String?
        let fallbackName: String?
        let sets: Int
        let repsMin: Int
        let repsMax: Int
        let rir: Int
        let restSeconds: Int
    }

    // MARK: - Slug Templates
    //
    // Pořadí v každé šabloně respektuje princip profesionálního trenéra:
    //  1. Nejtěžší compound cvik (nejvyšší CNS nároky → provádět v čerstvém stavu)
    //  2. Druhý compound cvik nebo asistovaný compound
    //  3. Izolace primárního svalu
    //  4. Izolace sekundárního svalu (malá partie)
    //  5. Prevence zranění / stabilizátory (face-pull, plank...)
    //
    // Princip kombinace partií:
    //  • Push = Prsa + Ramena + Triceps (vše co TLAČÍŠ od sebe)
    //  • Pull = Záda + Biceps + Zadní delty (vše co PŘITAHUJEŠ k sobě)
    //  • Triceps se unaví při každém tlaku → kombinovat s prsy (ne se zády!)
    //  • Biceps se unaví při každém přítahu → kombinovat se zády (ne s prsy!)

    private static let slugTemplates: [String: [String]] = [

        // ── PUSH (Prsa + Ramena + Triceps) ───────────────────────────────────
        "Push": [
            "barbell-bench-press",      // Compound #1: hlavní hrudní cvik
            "overhead-press",           // Compound #2: deltoid hlavní cvik
            "incline-dumbbell-press",   // Asistovaný compound: horní prsa
            "lateral-raise",            // Izolace: střední delty (slabé místo většiny)
            "tricep-pushdown",          // Izolace tricepsu (kabel = konstantní napětí)
            "cable-fly-low"             // Izolace dolní prsa, finisher
        ],

        // ── PULL (Záda + Biceps + Zadní delty) ───────────────────────────────
        "Pull": [
            "pull-up",                  // Compound #1: celá záda + lats (nejtěžší cvik)
            "barbell-row",              // Compound #2: střední záda + trapézy
            "lat-pulldown",             // Asistovaný: lats šíře (varianta vertikálního tahu)
            "face-pull",                // POVINNÉ: zadní delty + rotátory (prevence zranění ramen!)
            "barbell-curl",             // Izolace bicepsu
            "hammer-curl"               // Izolace brachialis (zanedbávané, ale důležité)
        ],

        // ── LEGS (Quady + Hamstringy + Hýždě + Lýtka) ───────────────────────
        "Legs": [
            "barbell-squat",            // Compound #1: quady dominantní
            "romanian-deadlift",        // Compound #2: hamstringy dominantní (JINÝ pohybový vzor!)
            "leg-press",                // Asistovaný compound: bezpečnější alternativa dřepu
            "lying-leg-curl",           // Izolace hamstringů (stroj)
            "leg-extension",            // Izolace quadů (stroj)
            "calf-raise"                // Izolace lýtek (svalovina s pomalými vlákny → vysoké reps)
        ],

        // ── UPPER A (Horní — press-dominantní varianta) ───────────────────────
        // Záda jsou přítomna i v Upper dni → 2× týdně frekvence!
        "Upper A": [
            "barbell-bench-press",
            "barbell-row",
            "dumbbell-shoulder-press",
            "cable-row",
            "tricep-pushdown",
            "barbell-curl"
        ],

        // ── UPPER B (Horní — pull-dominantní varianta) ────────────────────────
        "Upper B": [
            "overhead-press",
            "pull-up",
            "incline-dumbbell-press",
            "lat-pulldown",
            "lateral-raise",
            "dumbbell-curl"
        ],

        // ── UPPER C (Horní — vyvažovací den, 5-denní split) ──────────────────
        "Upper C": [
            "dumbbell-bench-press",
            "chest-supported-row",
            "arnold-press",
            "cable-chest-fly",
            "skull-crusher",
            "incline-dumbbell-curl"
        ],

        // ── LOWER A (Dolní — squat/quad dominantní) ──────────────────────────
        "Lower A": [
            "barbell-squat",
            "romanian-deadlift",
            "leg-press",
            "lying-leg-curl",
            "leg-extension",
            "calf-raise"
        ],

        // ── LOWER B (Dolní — hip hinge/glute dominantní, varianta) ───────────
        "Lower B": [
            "conventional-deadlift",    // Deadlift místo dřepu = různý stimulus
            "bulgarian-split-squat",    // Unilateral → opravuje svalové asymetrie
            "hip-thrust",               // Hýždě izolovaně (nejvyšší aktivace gluteus!)
            "lying-leg-curl",
            "goblet-squat",             // Lehčí squat na závěr (quady dočerpat)
            "seated-calf-raise"         // Varianta lýtek — sedící = gastrocnemius vs soleus
        ],

        // ── FULLBODY A ───────────────────────────────────────────────────────
        // V každém Fullbody: 1 nohy + 1 prsa + 1 záda + 1 ramena + core
        "Fullbody A": [
            "barbell-squat",
            "barbell-bench-press",
            "barbell-row",
            "dumbbell-shoulder-press",
            "plank"
        ],

        // ── FULLBODY B ───────────────────────────────────────────────────────
        // Varianta B: různé cviky, stejné partie → min. 48h po Fullbody A
        "Fullbody B": [
            "romanian-deadlift",        // Hinge místo squat = jiný stimulus na nohy
            "dumbbell-bench-press",
            "pull-up",                  // Vertikální tah místo horizontálního
            "lateral-raise",
            "ab-crunch"
        ],

        // ── FULLBODY C ───────────────────────────────────────────────────────
        // Varianta C: pro 3-denní Fullbody, třetí stimulus v týdnu
        "Fullbody C": [
            "goblet-squat",
            "incline-dumbbell-press",
            "cable-row",
            "overhead-press",
            "russian-twist"
        ],

        // ── FULLBODY (1-denní) ────────────────────────────────────────────────
        "Fullbody": [
            "barbell-squat",
            "barbell-bench-press",
            "barbell-row",
            "dumbbell-shoulder-press",
            "plank"
        ]
    ]

    // MARK: - Exercise Config Builder

    private static func getExerciseConfigs(
        for label: String,
        allExercises: [Exercise],
        profile: UserProfile
    ) -> [ExerciseConfig] {

        let (baseSets, repsMin, repsMax, rir, compoundRest, isolationRest) =
            trainingParameters(for: profile)
        let availableEquipment = Set(profile.availableEquipment)
        let normalizedLabel = normalizeLabel(label)

        guard let slugs = slugTemplates[normalizedLabel] else {
            AppLogger.warning("⚠️ [WorkoutPlanGenerator] Neznámý label: '\(label)' → '\(normalizedLabel)'")
            return []
        }

        return slugs.compactMap { slug -> ExerciseConfig? in
            let exercise = allExercises.first(where: { $0.slug == slug })
            
            if exercise == nil {
                AppLogger.warning("⚠️ [WorkoutPlanGenerator] Slug '\(slug)' nenalezen v DB — přidej cvik do ExerciseDatabase.json")
            } else if !exercise!.equipment.isEmpty {
                let hasEquipment = exercise!.equipment.contains { availableEquipment.contains($0) }
                if !hasEquipment {
                    AppLogger.info("ℹ️ [WorkoutPlanGenerator] Přeskakuji '\(exercise!.name)' — chybí: \(exercise!.equipment.map(\.rawValue))")
                    return nil
                }
            }

            let isCompound = exercise.map { [MovementPattern.push, .pull, .hinge, .squat].contains($0.movementPattern) } ?? false

            return ExerciseConfig(
                exercise: exercise,
                fallbackSlug: slug,
                fallbackName: nil,
                sets: isCompound ? baseSets : max(baseSets - 1, 2),
                repsMin: isCompound ? repsMin : repsMin + 2,
                repsMax: isCompound ? repsMax : repsMax + 4,
                rir: rir,
                restSeconds: isCompound ? compoundRest : isolationRest
            )
        }
    }

    // MARK: - Training Parameters
    //
    // Vědecké reference:
    //  • Síla: rep range 1-5, RIR 1, rest 3-5min (Zatsiorsky 2006)
    //  • Hypertrofie: rep range 6-12, RIR 2, rest 60-120s (Schoenfeld 2010, 2017)
    //  • Hubnutí: vyšší reps + kratší pauzy = metabolický efekt
    //  • Vytrvalost: >15 opakování, krátký rest 30-60s

    private static func trainingParameters(for profile: UserProfile)
        -> (sets: Int, repsMin: Int, repsMax: Int, rir: Int, compoundRest: Int, isolationRest: Int)
    {
        switch profile.primaryGoal {
        case .strength:
            let sets = profile.fitnessLevel == .beginner ? 3 : (profile.fitnessLevel == .intermediate ? 4 : 5)
            return (sets, 3, 5, 1, 180, 120)
        case .hypertrophy:
            let sets = profile.fitnessLevel == .beginner ? 3 : 4
            return (sets, 6, 12, 2, 120, 75)
        case .weightLoss:
            return (3, 12, 15, 1, 75, 45)
        case .endurance:
            return (3, 15, 20, 0, 60, 30)
        case .maintenance, .sportsPerf:
            return (3, 8, 15, 2, 90, 60)
        }
    }

    // MARK: - Label Normalization

    private static func normalizeLabel(_ label: String) -> String {
        let known = [
            "Push", "Pull", "Legs",
            "Upper A", "Upper B", "Upper C",
            "Lower A", "Lower B",
            "Fullbody A", "Fullbody B", "Fullbody C", "Fullbody",
            "Upper", "Lower"
        ]
        if known.contains(label) { return label }
        for key in known where label.hasPrefix(key) { return key }
        return label.components(separatedBy: " ").first ?? label
    }

    // MARK: - Schedule Builder

    private struct DayEntry {
        let dayOfWeek: Int  // 1=Po, 2=Út, 3=St, 4=Čt, 5=Pá, 6=So, 7=Ne
        let label: String
    }

    private static func buildSchedule(split: SplitType, daysPerWeek: Int) -> [DayEntry] {
        switch split {
        case .fullBody:   return fullBodySchedule(days: daysPerWeek)
        case .upperLower: return upperLowerSchedule(days: daysPerWeek)
        case .ppl:        return pplSchedule(days: daysPerWeek)
        }
    }

    // MARK: Fullbody — 2–3× týdně, NIKDY dva dny za sebou (48h regenerace)
    private static func fullBodySchedule(days: Int) -> [DayEntry] {
        let templates: [[DayEntry]] = [
            [],
            [.init(dayOfWeek: 1, label: "Fullbody A")],
            [.init(dayOfWeek: 1, label: "Fullbody A"),
             .init(dayOfWeek: 4, label: "Fullbody B")],
            [.init(dayOfWeek: 1, label: "Fullbody A"),
             .init(dayOfWeek: 3, label: "Fullbody B"),
             .init(dayOfWeek: 5, label: "Fullbody C")],
            [.init(dayOfWeek: 1, label: "Fullbody A"),
             .init(dayOfWeek: 3, label: "Fullbody B"),
             .init(dayOfWeek: 5, label: "Fullbody C"),
             .init(dayOfWeek: 6, label: "Fullbody A")]
        ]
        return templates[min(days, templates.count - 1)]
    }

    // MARK: Upper / Lower — 4× týdně ideál
    // Upper A = press-dominant, Upper B = pull-dominant → variace stimulu pro 2× frekvenci
    private static func upperLowerSchedule(days: Int) -> [DayEntry] {
        let templates: [[DayEntry]] = [
            [],
            [.init(dayOfWeek: 1, label: "Upper A")],
            [.init(dayOfWeek: 1, label: "Upper A"),
             .init(dayOfWeek: 4, label: "Lower A")],
            [.init(dayOfWeek: 1, label: "Upper A"),
             .init(dayOfWeek: 3, label: "Lower A"),
             .init(dayOfWeek: 5, label: "Upper B")],
            // Klasický 4-denní U/L: Po-Út-Čt-Pá
            [.init(dayOfWeek: 1, label: "Upper A"),
             .init(dayOfWeek: 2, label: "Lower A"),
             .init(dayOfWeek: 4, label: "Upper B"),
             .init(dayOfWeek: 5, label: "Lower B")],
            [.init(dayOfWeek: 1, label: "Upper A"),
             .init(dayOfWeek: 2, label: "Lower A"),
             .init(dayOfWeek: 3, label: "Upper B"),
             .init(dayOfWeek: 5, label: "Lower B"),
             .init(dayOfWeek: 6, label: "Upper C")]
        ]
        return templates[min(days, templates.count - 1)]
    }

    // MARK: Push / Pull / Legs — 3–6× týdně
    // 4 dny: PPL + Upper B (mix den) — nelogické by bylo PPL + Push (4× Push za 7 dní!)
    private static func pplSchedule(days: Int) -> [DayEntry] {
        let templates: [[DayEntry]] = [
            [],
            [.init(dayOfWeek: 1, label: "Push")],
            [.init(dayOfWeek: 1, label: "Push"),
             .init(dayOfWeek: 4, label: "Pull")],
            [.init(dayOfWeek: 1, label: "Push"),
             .init(dayOfWeek: 3, label: "Pull"),
             .init(dayOfWeek: 5, label: "Legs")],
            // 4 dny: PPL + Upper B jako mix den
            [.init(dayOfWeek: 1, label: "Push"),
             .init(dayOfWeek: 2, label: "Pull"),
             .init(dayOfWeek: 4, label: "Legs"),
             .init(dayOfWeek: 5, label: "Upper B")],
            [.init(dayOfWeek: 1, label: "Push"),
             .init(dayOfWeek: 2, label: "Pull"),
             .init(dayOfWeek: 3, label: "Legs"),
             .init(dayOfWeek: 5, label: "Push"),
             .init(dayOfWeek: 6, label: "Pull")],
            // 6 dní: PPL 2× — každá partie přesně 2×/týden (optimum pro pokročilé)
            [.init(dayOfWeek: 1, label: "Push"),
             .init(dayOfWeek: 2, label: "Pull"),
             .init(dayOfWeek: 3, label: "Legs"),
             .init(dayOfWeek: 4, label: "Push"),
             .init(dayOfWeek: 5, label: "Pull"),
             .init(dayOfWeek: 6, label: "Legs")]
        ]
        return templates[min(days, templates.count - 1)]
    }

    private static func planTitle(split: SplitType) -> String {
        switch split {
        case .fullBody:   return "Fullbody Program"
        case .upperLower: return "Upper / Lower Split"
        case .ppl:        return "Push / Pull / Legs"
        }
    }
}
