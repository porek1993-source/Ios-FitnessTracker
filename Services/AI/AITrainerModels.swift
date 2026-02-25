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
    var muscleImpact: SportMuscleImpact  // Nově: jaké svaly tento sport namáhal

    init(type: String, durationMinutes: Int, energyKcal: Double, hoursAgo: Double) {
        self.type = type
        self.durationMinutes = durationMinutes
        self.energyKcal = energyKcal
        self.hoursAgo = hoursAgo
        self.muscleImpact = SportMuscleMapping.impact(for: type)
    }
}

/// Jaké svalové skupiny daný sport primárně/sekundárně zatěžuje
struct SportMuscleImpact: Codable {
    let primaryMuscles: [String]    // ["quads", "hamstrings", "calves"]
    let secondaryMuscles: [String]  // ["glutes", "abs"]
    let recoveryHoursNeeded: Int    // Doporučená regenerace
    let avoidHeavyCompounds: Bool   // Pokud true, AI vynechá těžké dřepy/mrtvý
}

/// Mapování sportů → svalový dopad
enum SportMuscleMapping {
    static func impact(for activityType: String) -> SportMuscleImpact {
        let s = activityType.lowercased()

        // Fotbal, florbal, futsal — nohy primárně
        if s.contains("soccer") || s.contains("football") || s.contains("floorball") || s.contains("futsal") {
            return SportMuscleImpact(
                primaryMuscles: ["quads", "hamstrings", "calves", "glutes"],
                secondaryMuscles: ["abs", "hip_flexors"],
                recoveryHoursNeeded: 36,
                avoidHeavyCompounds: true
            )
        }
        // Tenis, squash, badminton — rotační + nohy + ramena
        if s.contains("tennis") || s.contains("squash") || s.contains("badminton") {
            return SportMuscleImpact(
                primaryMuscles: ["forearms", "delts", "obliques"],
                secondaryMuscles: ["quads", "calves", "lats"],
                recoveryHoursNeeded: 24,
                avoidHeavyCompounds: false
            )
        }
        // Krav maga, bojové sporty — celé tělo
        if s.contains("krav") || s.contains("martial") || s.contains("boxing") || s.contains("mma") || s.contains("judo") {
            return SportMuscleImpact(
                primaryMuscles: ["pecs", "delts", "quads", "hamstrings"],
                secondaryMuscles: ["abs", "obliques", "biceps", "triceps"],
                recoveryHoursNeeded: 48,
                avoidHeavyCompounds: true
            )
        }
        // Jóga, pilates — flexibilita, core
        if s.contains("yoga") || s.contains("joga") || s.contains("pilates") || s.contains("stretch") {
            return SportMuscleImpact(
                primaryMuscles: ["abs", "spinalErectors"],
                secondaryMuscles: ["hamstrings", "glutes"],
                recoveryHoursNeeded: 12,
                avoidHeavyCompounds: false
            )
        }
        // Cyklistika, rotoped — nohy, kardio
        if s.contains("cycling") || s.contains("bike") || s.contains("cycle") {
            return SportMuscleImpact(
                primaryMuscles: ["quads", "calves", "glutes"],
                secondaryMuscles: ["hamstrings"],
                recoveryHoursNeeded: 20,
                avoidHeavyCompounds: false
            )
        }
        // Běh — nohy, kardio
        if s.contains("run") || s.contains("running") || s.contains("jogging") {
            return SportMuscleImpact(
                primaryMuscles: ["quads", "calves", "hamstrings"],
                secondaryMuscles: ["glutes", "abs"],
                recoveryHoursNeeded: 24,
                avoidHeavyCompounds: false
            )
        }
        // Plavání — horní tělo + core
        if s.contains("swim") || s.contains("swimming") {
            return SportMuscleImpact(
                primaryMuscles: ["lats", "delts", "pecs"],
                secondaryMuscles: ["abs", "triceps"],
                recoveryHoursNeeded: 24,
                avoidHeavyCompounds: false
            )
        }
        // Basketbal, volejbal, házená — nohy + horní
        if s.contains("basket") || s.contains("volleyball") || s.contains("handball") {
            return SportMuscleImpact(
                primaryMuscles: ["quads", "calves", "delts"],
                secondaryMuscles: ["abs", "glutes"],
                recoveryHoursNeeded: 36,
                avoidHeavyCompounds: false
            )
        }

        // Výchozí — neznámý sport, obecná únava
        return SportMuscleImpact(
            primaryMuscles: [],
            secondaryMuscles: [],
            recoveryHoursNeeded: 24,
            avoidHeavyCompounds: false
        )
    }
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

    static var jsonSchema: [String: Any] {
        return [
            "type": "object",
            "properties": [
                "motivationalMessage": ["type": "string"],
                "warmupUrl": ["type": "string"],
                "exercises": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string"],
                            "slug": ["type": "string"],
                            "coachTip": ["type": "string"],
                            "sets": ["type": "integer"],
                            "repsMin": ["type": "integer"],
                            "repsMax": ["type": "integer"],
                            "weightKg": ["type": "number"],
                            "rpe": ["type": "integer"],
                            "tempo": ["type": "string"],
                            "restSeconds": ["type": "integer"]
                        ]
                    ]
                ]
            ],
            "required": ["motivationalMessage", "exercises"]
        ]
    }
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
