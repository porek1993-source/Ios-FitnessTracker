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
        profile: UserProfile,
        equipmentOverride: Set<Equipment>? = nil,
        timeLimitMinutes: Int? = nil
    ) async throws -> TrainerRequestContext {
        async let hkSummary  = healthKitService.fetchDailySummary(for: date)
        async let activities = healthKitService.fetchExternalActivities(
            since: date.addingTimeInterval(-36 * 3600)
        )

        let health = try await hkSummary
        let acts   = try await activities
        let snap   = try resolveHealthSnapshot(date: date)

        guard
            let activePlan = profile.workoutPlans.first(where: \.isActive),
            let plannedDay = activePlan.scheduledDays.first(where: { $0.dayOfWeek == date.weekday })
        else { throw AppError.noPlanForToday }

        return TrainerRequestContext(
            userProfile:         buildUserProfile(profile: profile),
            todayPlan:           buildPlannedDay(day: plannedDay, plan: activePlan),
            healthMetrics:       buildHealthContext(hk: health, snapshot: snap, activities: acts),
            fatigue:             buildFatigueContext(),
            equipment:           buildEquipmentContext(profile: profile, override: equipmentOverride),
            progressiveOverload: buildOverloadEntries(day: plannedDay),
            sessionTimeOverride: timeLimitMinutes
        )
    }

    // MARK: - Subsections

    private func buildUserProfile(profile: UserProfile) -> UserContextProfile {
        UserContextProfile(
            name: profile.name,
            fitnessLevel: profile.fitnessLevel.rawValue,
            primaryGoal: profile.primaryGoal.rawValue,
            sessionDurationMinutes: profile.sessionDurationMinutes
        )
    }

    private func buildPlannedDay(day: PlannedWorkoutDay, plan: WorkoutPlan) -> PlannedDayContext {
        PlannedDayContext(
            label: day.label,
            splitType: plan.splitType.rawValue,
            plannedExercises: day.plannedExercises
                .sorted { $0.order < $1.order }
                .map {
                    PlannedExerciseContext(
                        slug: $0.exercise?.slug ?? "",
                        name: $0.exercise?.name ?? "",
                        targetSets: $0.targetSets,
                        targetRepsMin: $0.targetRepsMin,
                        targetRepsMax: $0.targetRepsMax,
                        targetRIR: $0.targetRIR,
                        restSeconds: $0.restSeconds
                    )
                }
        )
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
