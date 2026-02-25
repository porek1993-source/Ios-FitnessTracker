// WorkoutPlanGenerator.swift
// Agilní Fitness Trenér — Generátor tréninkového plánu po onboardingu
// Vytvoří WorkoutPlan s PlannedWorkoutDay záznamy ihned po dokončení onboardingu.

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
        
        // Načteme všechny dostupné cviky pro přiřazení do šablon
        let allExercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []

        for entry in schedule {
            let day = PlannedWorkoutDay(
                dayOfWeek: entry.dayOfWeek,
                label: entry.label,
                isRestDay: false
            )
            day.plan = plan
            context.insert(day)
            
            // Přiřadíme cviky podle labelu (naše šablony)
            let templates = getTemplateExercises(for: entry.label, allExercises: allExercises)
            for (idx, ex) in templates.enumerated() {
                let plannedEx = PlannedExercise(
                    order: idx,
                    exercise: ex,
                    targetSets: 3,
                    targetRepsMin: 8,
                    targetRepsMax: 12
                )
                plannedEx.plannedDay = day
                context.insert(plannedEx)
                day.plannedExercises.append(plannedEx)
            }
            
            plan.scheduledDays.append(day)
        }

        profile.workoutPlans.append(plan)
        try? context.save()
        return plan
    }

    // MARK: - Template Exercises

    private static func getTemplateExercises(for label: String, allExercises: [Exercise]) -> [Exercise] {
        let slugMap: [String: [String]] = [
            "Push": ["barbell-bench-press", "overhead-press", "lateral-raise", "tricep-pushdown"],
            "Pull": ["pull-up", "barbell-row", "face-pull", "barbell-curl"],
            "Legs": ["barbell-squat", "romanian-deadlift", "leg-extension", "calf-raise"],
            "Upper": ["dumbbell-bench-press", "cable-row", "dumbbell-shoulder-press", "tricep-dip"],
            "Lower": ["leg-press", "lying-leg-curl", "goblet-squat", "hip-thrust"],
            "Fullbody": ["barbell-squat", "barbell-bench-press", "barbell-row", "plank"]
        ]
        
        let normalizedLabel = label.components(separatedBy: " ").first ?? label
        guard let slugs = slugMap[normalizedLabel] else { return [] }
        
        return slugs.compactMap { slug in
            allExercises.first(where: { $0.slug == slug })
        }
    }

    // MARK: - Schedule Builder
    // ... rest of the builder code stays same ...

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

    // MARK: Fullbody — 2-3× týdně, odpočinek mezi
    private static func fullBodySchedule(days: Int) -> [DayEntry] {
        let templates: [[DayEntry]] = [
            [],                                                                         // 0
            [.init(dayOfWeek: 1, label: "Fullbody")],                                   // 1
            [.init(dayOfWeek: 1, label: "Fullbody A"), .init(dayOfWeek: 4, label: "Fullbody B")],    // 2
            [.init(dayOfWeek: 1, label: "Fullbody A"), .init(dayOfWeek: 3, label: "Fullbody B"),     // 3
             .init(dayOfWeek: 5, label: "Fullbody C")],
            [.init(dayOfWeek: 1, label: "Fullbody A"), .init(dayOfWeek: 2, label: "Fullbody B"),     // 4
             .init(dayOfWeek: 4, label: "Fullbody C"), .init(dayOfWeek: 5, label: "Fullbody D")],
        ]
        return templates[min(days, templates.count - 1)]
    }

    // MARK: Upper / Lower
    private static func upperLowerSchedule(days: Int) -> [DayEntry] {
        let templates: [[DayEntry]] = [
            [],
            [.init(dayOfWeek: 1, label: "Upper")],
            [.init(dayOfWeek: 1, label: "Upper"), .init(dayOfWeek: 4, label: "Lower")],
            [.init(dayOfWeek: 1, label: "Upper"), .init(dayOfWeek: 3, label: "Lower"),
             .init(dayOfWeek: 5, label: "Upper B")],
            [.init(dayOfWeek: 1, label: "Upper A"), .init(dayOfWeek: 2, label: "Lower A"),
             .init(dayOfWeek: 4, label: "Upper B"), .init(dayOfWeek: 5, label: "Lower B")],
            [.init(dayOfWeek: 1, label: "Upper A"), .init(dayOfWeek: 2, label: "Lower A"),
             .init(dayOfWeek: 3, label: "Upper B"), .init(dayOfWeek: 5, label: "Lower B"),
             .init(dayOfWeek: 6, label: "Upper C")],
        ]
        return templates[min(days, templates.count - 1)]
    }

    // MARK: Push / Pull / Legs
    private static func pplSchedule(days: Int) -> [DayEntry] {
        let templates: [[DayEntry]] = [
            [],
            [.init(dayOfWeek: 1, label: "Push")],
            [.init(dayOfWeek: 1, label: "Push"), .init(dayOfWeek: 4, label: "Pull")],
            [.init(dayOfWeek: 1, label: "Push"), .init(dayOfWeek: 3, label: "Pull"),
             .init(dayOfWeek: 5, label: "Legs")],
            [.init(dayOfWeek: 1, label: "Push"), .init(dayOfWeek: 2, label: "Pull"),
             .init(dayOfWeek: 4, label: "Legs"), .init(dayOfWeek: 5, label: "Upper")],
            [.init(dayOfWeek: 1, label: "Push"), .init(dayOfWeek: 2, label: "Pull"),
             .init(dayOfWeek: 3, label: "Legs"), .init(dayOfWeek: 5, label: "Push"),
             .init(dayOfWeek: 6, label: "Pull")],
            [.init(dayOfWeek: 1, label: "Push"), .init(dayOfWeek: 2, label: "Pull"),
             .init(dayOfWeek: 3, label: "Legs"), .init(dayOfWeek: 4, label: "Push"),
             .init(dayOfWeek: 5, label: "Pull"), .init(dayOfWeek: 6, label: "Legs")],
        ]
        return templates[min(days, templates.count - 1)]
    }

    private static func planTitle(split: SplitType) -> String {
        switch split {
        case .fullBody:   return "Fullbody Program"
        case .upperLower: return "Upper / Lower Split"
        case .ppl:        return "Push Pull Legs"
        }
    }
}
