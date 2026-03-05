// TrainerContextBuilder.swift

import Foundation
import SwiftData

@MainActor
final class TrainerContextBuilder {

    private let modelContext: ModelContext
    private let healthKitService: HealthKitService

    init(modelContext: ModelContext, healthKitService: HealthKitService) {
        self.modelContext = modelContext
        self.healthKitService = healthKitService
    }

    func buildContext(
        for date: Date,
        profileID: PersistentIdentifier,
        plannedDayID: PersistentIdentifier? = nil,
        equipmentOverride: Set<Equipment>? = nil,
        timeLimitMinutes: Int? = nil
    ) async throws -> TrainerRequestContext {
        // Načteme profil v tomto (potentially isolation-hopped) kontextu
        guard let profile = modelContext.model(for: profileID) as? UserProfile else {
            throw AppError.internalError("Profil nebyl nalezen ve SwiftData")
        }

        // Pokud máme konkrétní ID dne, použijeme ho přímo (zabrání záměně dne při timezone edge case)
        let plannedDay: PlannedWorkoutDay?
        if let pid = plannedDayID {
            plannedDay = modelContext.model(for: pid) as? PlannedWorkoutDay
        } else {
            plannedDay = nil
        }

        return try await buildContext(
            for: date,
            profile: profile,
            plannedDayOverride: plannedDay,
            equipmentOverride: equipmentOverride,
            timeLimitMinutes: timeLimitMinutes
        )
    }

    func buildContext(
        for date: Date,
        profile: UserProfile,
        plannedDayOverride: PlannedWorkoutDay? = nil,
        equipmentOverride: Set<Equipment>? = nil,
        timeLimitMinutes: Int? = nil
    ) async throws -> TrainerRequestContext {
        async let hkSummary  = healthKitService.fetchDailySummary(for: date)
        async let activities = healthKitService.fetchExternalActivities(
            since: date.addingTimeInterval(-36 * 3600)
        )

        let health: HKDailySummary
        do {
            health = try await hkSummary
        } catch {
            AppLogger.warning("⚠️ [TrainerContextBuilder] HealthKit fetchDailySummary selhalo (není autorizace?): \(error) — používám prázdný souhrn.")
            health = HKDailySummary()
        }

        let acts: [HKWorkoutSummary]
        do {
            acts = try await activities
        } catch {
            AppLogger.warning("⚠️ [TrainerContextBuilder] HealthKit fetchExternalActivities selhalo: \(error) — prázdný seznam.")
            acts = []
        }
        let snap   = try resolveHealthSnapshot(date: date)

        guard let activePlan = profile.workoutPlans.first(where: \.isActive) else {
            throw AppError.noPlanForToday
        }

        // Priorita: explicitně předaný den > lookup podle weekday
        // Tím se opravuje bug kdy buildContext ignoroval plannedDay z calleru
        // a mohl načíst jiný den při timezone edge case nebo manuálním startu
        let plannedDay: PlannedWorkoutDay
        if let override = plannedDayOverride {
            plannedDay = override
        } else if let found = activePlan.scheduledDays.first(where: { $0.dayOfWeek == date.weekday }) {
            plannedDay = found
        } else {
            throw AppError.noPlanForToday
        }

        // --- MISSING DAYS CALCULATION ---
        // ✅ FIX: Používáme date.weekday extension (1=Po...7=Ne) pro konzistenci s celou app
        let adjustedWeekday = date.weekday  // 1=Po ... 7=Ne
        let daysRemainingInWeek = 7 - adjustedWeekday
        
        let daysInWeekComplete = activePlan.sessions.filter { history in
            // ✅ FIX: Calendar.mondayStart pro konzistentní pondělní začátek týdne
            Calendar.mondayStart.isDate(history.startedAt, equalTo: date, toGranularity: .weekOfYear)
        }.count
        let plannedDaysPerWeek = activePlan.scheduledDays.count
        let workoutsRemaining = plannedDaysPerWeek - daysInWeekComplete

        return TrainerRequestContext(
            userProfile:         buildUserProfile(profile: profile),
            todayPlan:           buildPlannedDay(day: plannedDay, plan: activePlan),
            healthMetrics:       buildHealthContext(hk: health, snapshot: snap, activities: acts),
            fatigue:             buildFatigueContext(),
            equipment:           buildEquipmentContext(profile: profile, override: equipmentOverride),
            progressiveOverload: buildOverloadEntries(day: plannedDay),
            sessionTimeOverride: timeLimitMinutes,
            workoutsRemainingInWeek: workoutsRemaining,
            daysRemainingInWeek: daysRemainingInWeek,
            isDeloadRecommended: profile.isDeloadRecommended,
            recentWorkouts:      buildRecentWorkouts(plan: activePlan, relativeTo: date),
            upcomingDays:        buildUpcomingDays(plan: activePlan, relativeTo: date)
        )
    }

    // MARK: - Subsections

    private func buildUserProfile(profile: UserProfile) -> UserContextProfile {
        UserContextProfile(
            fitnessLevel: profile.fitnessLevel.rawValue,
            primaryGoal: profile.primaryGoal.rawValue,
            name: profile.name,
            sessionDurationMinutes: profile.sessionDurationMinutes
        )
    }

    private func buildPlannedDay(day: PlannedWorkoutDay, plan: WorkoutPlan) -> PlannedDayContext {
        // Pokud jsou exercise relationships nil (SwiftData lazy loading race condition),
        // pokusíme se je opravit z DB před sestavením kontextu
        let exercises = day.sortedExercises
        let hasNilExercises = exercises.contains { $0.exercise == nil }
        if hasNilExercises {
            repairNilExercises(for: day)
        }

        return PlannedDayContext(
            label: day.label,
            splitType: plan.splitType.rawValue,
            plannedExercises: day.sortedExercises
                .compactMap { planned -> PlannedExerciseContext? in
                    guard let exercise = planned.exercise, !exercise.slug.isEmpty else {
                        return nil  // Vynech cviky bez exercise reference (AI dostane čistý seznam)
                    }
                    return PlannedExerciseContext(
                        slug: exercise.slug,
                        name: exercise.name,
                        targetSets: planned.targetSets,
                        targetRepsMin: planned.targetRepsMin,
                        targetRepsMax: planned.targetRepsMax,
                        targetRIR: planned.targetRIR,
                        restSeconds: planned.restSeconds
                    )
                }
        )
    }

    /// Opravuje nil exercise relace v PlannedExercise (SwiftData race condition při seeding)
    private func repairNilExercises(for day: PlannedWorkoutDay) {
        let slugTemplates: [String: [String]] = [
            "Push": ["barbell-bench-press", "overhead-press", "incline-dumbbell-press", "lateral-raise", "tricep-pushdown", "cable-fly-low"],
            "Pull": ["pull-up", "barbell-row", "lat-pulldown", "face-pull", "barbell-curl", "hammer-curl"],
            "Legs": ["barbell-squat", "romanian-deadlift", "leg-press", "lying-leg-curl", "leg-extension", "calf-raise"],
            "Upper A": ["barbell-bench-press", "barbell-row", "dumbbell-shoulder-press", "cable-row", "tricep-pushdown", "barbell-curl"],
            "Upper B": ["overhead-press", "pull-up", "incline-dumbbell-press", "lat-pulldown", "lateral-raise", "dumbbell-curl"],
            "Upper C": ["dumbbell-bench-press", "chest-supported-row", "arnold-press", "cable-chest-fly", "skull-crusher", "incline-dumbbell-curl"],
            "Lower A": ["barbell-squat", "romanian-deadlift", "leg-press", "lying-leg-curl", "leg-extension", "calf-raise"],
            "Lower B": ["conventional-deadlift", "bulgarian-split-squat", "hip-thrust", "lying-leg-curl", "goblet-squat", "seated-calf-raise"],
            "Fullbody A": ["barbell-squat", "barbell-bench-press", "barbell-row", "dumbbell-shoulder-press", "plank"],
            "Fullbody B": ["romanian-deadlift", "dumbbell-bench-press", "pull-up", "lateral-raise", "ab-crunch"],
            "Fullbody C": ["goblet-squat", "incline-dumbbell-press", "cable-row", "overhead-press", "russian-twist"],
            "Fullbody": ["barbell-squat", "barbell-bench-press", "barbell-row", "dumbbell-shoulder-press", "plank"]
        ]

        let label = day.label
        let normalized: String
        if slugTemplates[label] != nil {
            normalized = label
        } else {
            normalized = label.components(separatedBy: " ").first ?? label
        }

        guard let slugs = slugTemplates[normalized] else { return }
        let allExercises = (try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? []

        for (i, ex) in day.plannedExercises.sorted(by: { $0.order < $1.order }).enumerated() {
            guard ex.exercise == nil, i < slugs.count else { continue }
            if let found = allExercises.first(where: { $0.slug == slugs[i] }) {
                ex.exercise = found
            }
        }
        try? modelContext.save()  // Non-critical: linkování Exercise referencí — data jsou v slugs
    }

    private func buildHealthContext(
        hk: HKDailySummary,
        snapshot: HealthMetricsSnapshot?,
        activities: [HKWorkoutSummary]
    ) -> HealthContext {
        let readiness = snapshot.flatMap { ReadinessCalculator.compute(snapshot: $0) }

        return HealthContext(
            sleepDurationHours:   hk.sleepDurationHours,
            sleepEfficiencyPct:   hk.sleepEfficiencyPct,
            sleepDeepHours:       hk.sleepDeepHours,
            hrv:                  hk.hrv,
            hrvBaselineAvg:       snapshot?.hrvBaselineAvg,
            restingHeartRate:     hk.restingHeartRate,
            restingHRBaselineAvg: snapshot?.restingHRBaseline,
            respiratoryRate:      hk.respiratoryRate,
            readinessScore:       readiness?.score,
            readinessLevel:       readiness?.level.rawValue,
            externalActivities:   activities.map {
                ExternalActivityContext(
                    type: $0.activityTypeName,
                    durationMinutes: $0.durationMinutes,
                    energyKcal: $0.totalEnergyKcal,
                    hoursAgo: Date().timeIntervalSince($0.startDate) / 3600
                )
            }
        )
    }

    // MARK: - History & Calendar Context

    /// Posědních 7 dní tréninků ve formuláři čitelelném pro AI.
    private func buildRecentWorkouts(plan: WorkoutPlan, relativeTo date: Date) -> [RecentSessionContext] {
        let cutoff = date.addingTimeInterval(-7 * 24 * 3600)
        let recent = plan.sessions
            .filter { $0.startedAt >= cutoff && Calendar.current.startOfDay(for: $0.startedAt) < Calendar.current.startOfDay(for: date) }
            .sorted { $0.startedAt > $1.startedAt }
            .prefix(7)

        let calendar = Calendar.current
        return recent.compactMap { session in
            let daysAgo = calendar.dateComponents([.day], from: session.startedAt, to: date).day ?? 0
            guard daysAgo > 0 else { return nil }

            // Sbere slugy cviků provedených v této session
            let exerciseSlugs: [String] = session.exercises.compactMap { ex in
                let slug = ex.exercise?.slug ?? ex.fallbackSlug ?? ""
                return slug.isEmpty ? nil : slug
            }

            // Odvodime namáhané svaly z plan label (heuristika)
            let musclesTrained = muscleGroupsForLabel(session.plannedDayName)

            // Odhad celkového tréninkového objemu z dokončených sérií
            let volume: Double = session.exercises.flatMap(\.completedSets).reduce(0) { acc, s in
                acc + (Double(s.reps) * s.weightKg)
            }

            return RecentSessionContext(
                label:          session.plannedDayName,
                daysAgo:        daysAgo,
                musclesTrained: musclesTrained,
                exerciseSlugs:  exerciseSlugs,
                totalVolume:    volume,
                wasDeload:      false
            )
        }
    }

    /// Plánované dny v kalenáři za příští 3 dny (AI nezátěží nohami den před Legs dnem)
    private func buildUpcomingDays(plan: WorkoutPlan, relativeTo date: Date) -> [UpcomingDayContext] {
        var result: [UpcomingDayContext] = []
        let calendar = Calendar.current
        for offset in 1...3 {
            guard let future = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            let weekday = future.weekday
            if let day = plan.scheduledDays.first(where: { $0.dayOfWeek == weekday }) {
                result.append(UpcomingDayContext(
                    label:         day.label,
                    daysFromNow:   offset,
                    primaryMuscles: muscleGroupsForLabel(day.label)
                ))
            }
        }
        return result
    }

    /// Heuristické mapování den label → primární svalové skupiny
    private func muscleGroupsForLabel(_ label: String) -> [String] {
        let l = label.lowercased()
        if l.contains("push") {
            return ["chest", "front-shoulders", "triceps"]
        } else if l.contains("pull") {
            return ["lats", "traps-middle", "rear-shoulders", "biceps"]
        } else if l.contains("leg") || l.contains("lower") || l.contains("nohy") {
            return ["quads", "hamstrings", "glutes", "calves"]
        } else if l.contains("upper") {
            return ["chest", "lats", "front-shoulders", "biceps", "triceps"]
        } else if l.contains("full") {
            return ["chest", "lats", "quads", "hamstrings", "glutes", "front-shoulders"]
        }
        return []
    }

    private func buildFatigueContext() -> FatigueContext {
        FatigueContext(areas: FatigueStore.loadTodayFatigue())
    }

    private func buildEquipmentContext(profile: UserProfile, override: Set<Equipment>?) -> EquipmentContext {
        EquipmentContext(
            location: profile.currentLocation ?? "gym",
            availableEquipment: profile.availableEquipment.map(\.rawValue),
            filterOverride: override?.map(\.rawValue)
        )
    }

    private func buildOverloadEntries(day: PlannedWorkoutDay) -> [OverloadEntry] {
        day.plannedExercises.compactMap { planned -> OverloadEntry? in
            guard let exercise = planned.exercise else { return nil }
            let history = Array(
                exercise.weightHistory
                    .sorted { $0.loggedAt > $1.loggedAt }
                    .prefix(9)
            )
            guard let s = ProgressiveOverloadUseCase.suggest(history: history) else { return nil }
            return OverloadEntry(
                exerciseSlug:      exercise.slug,
                lastWeightKg:      s.lastWeightKg,
                suggestedWeightKg: s.suggestedWeightKg,
                suggestion:        s.action.rawValue,
                reason:            s.reason
            )
        }
    }

    private func resolveHealthSnapshot(date: Date) throws -> HealthMetricsSnapshot? {
        let start = date.startOfDay
        let end   = date.endOfDay
        let descriptor = FetchDescriptor<HealthMetricsSnapshot>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        )
        return try modelContext.fetch(descriptor).first
    }
}
