// AITrainerModels.swift

import Foundation

// MARK: - REQUEST CONTEXT

struct TrainerRequestContext: Codable {
    let userProfile: UserContextProfile
    let todayPlan: PlannedDayContext
    let healthMetrics: HealthContext
    let fatigue: FatigueContext
    let equipment: EquipmentContext
    let progressiveOverload: [OverloadEntry]
}

struct UserContextProfile: Codable {
    let name: String
    let fitnessLevel: String
    let primaryGoal: String
    let sessionDurationMinutes: Int
}

struct PlannedDayContext: Codable {
    let label: String
    let splitType: String
    let plannedExercises: [PlannedExerciseContext]
}

struct PlannedExerciseContext: Codable {
    let slug: String
    let name: String
    let targetSets: Int
    let targetRepsMin: Int
    let targetRepsMax: Int
    let targetRIR: Int
    let restSeconds: Int
}

struct HealthContext: Codable {
    let sleepDurationHours: Double?
    let sleepEfficiencyPct: Double?
    let sleepDeepHours: Double?
    let hrv: Double?
    let hrvBaselineAvg: Double?
    let restingHeartRate: Double?
    let restingHRBaselineAvg: Double?
    let respiratoryRate: Double?
    let readinessScore: Double?
    let readinessLevel: String?
    let externalActivities: [ExternalActivityContext]
}

struct ExternalActivityContext: Codable {
    let type: String
    let durationMinutes: Int
    let energyKcal: Double
    let hoursAgo: Double  // Relativní čas — AI chápe lépe než ISO datum
}

struct FatigueContext: Codable {
    let areas: [FatigueArea]
}

struct FatigueArea: Codable {
    let bodyPart: String
    let severity: Int        // 1–5
    let isJointPain: Bool
    let note: String?
}

struct EquipmentContext: Codable {
    let location: String
    let availableEquipment: [String]
}

struct OverloadEntry: Codable {
    let exerciseSlug: String
    let lastWeightKg: Double
    let suggestedWeightKg: Double
    let suggestion: String
    let reason: String
}

// MARK: - RESPONSE

struct ResponsePlan: Codable {
    let motivationalMessage: String
    let warmupUrl: String?
    let exercises: [ResponseExercise]
}

struct TrainerResponse: Codable {
    let coachMessage: String
    let sessionLabel: String
    let readinessLevel: String
    let adaptationReason: String?
    let estimatedDurationMinutes: Int
    let warmUp: [WarmUpExercise]
    let mainBlocks: [MainBlock]
    let coolDown: [CoolDownExercise]
}

struct WarmUpExercise: Codable {
    let name: String
    let sets: Int
    let reps: String
    let notes: String?
}

struct MainBlock: Codable {
    let blockLabel: String
    let exercises: [ResponseExercise]
}

struct ResponseExercise: Codable {
    let name: String
    let slug: String
    let sets: Int
    let repsMin: Int
    let repsMax: Int
    let weightKg: Double?
    let rir: Int?
    let rpe: Int?
    let restSeconds: Int
    let tempo: String?
    let coachTip: String?
}

struct CoolDownExercise: Codable {
    let name: String
    let durationSeconds: Int
    let notes: String?
}

// MARK: - Convenience

extension UserContextProfile {
    /// Zkrácený init pro fallback logiku (kde nemáme celý profil).
    init(fitnessLevel: String) {
        self.init(
            name: "Athlete",
            fitnessLevel: fitnessLevel,
            primaryGoal: "hypertrophy",
            sessionDurationMinutes: 60
        )
    }
}

extension TrainerResponse {
    /// Převede offline `ResponsePlan` na plnohodnotný `TrainerResponse`.
    static func fromFallback(_ plan: ResponsePlan) -> TrainerResponse {
        TrainerResponse(
            coachMessage: plan.motivationalMessage,
            sessionLabel: "Offline Fallback",
            readinessLevel: "orange",
            adaptationReason: "Offline režim — generováno lokálně.",
            estimatedDurationMinutes: plan.exercises.count * 10,
            warmUp: [],
            mainBlocks: [
                MainBlock(
                    blockLabel: "Hlavní blok (Offline)",
                    exercises: plan.exercises
                )
            ],
            coolDown: []
        )
    }
}
