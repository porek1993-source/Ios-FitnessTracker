// Exercise.swift

import SwiftData
import Foundation

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var slug: String
    var name: String
    var nameEN: String
    var category: ExerciseCategory
    var movementPattern: MovementPattern
    var equipment: [Equipment] = []
    var musclesTarget: [MuscleGroup] = []
    var musclesSecondary: [MuscleGroup] = []
    var isUnilateral: Bool = false
    var instructions: String = ""
    var videoURL: String?

    @Relationship(deleteRule: .cascade)
    var weightHistory: [WeightEntry] = []

    // MARK: - Progressive Overload Memory

    var lastUsedWeight: Double? {
        weightHistory
            .sorted { $0.loggedAt > $1.loggedAt }
            .first?.weightKg
    }

    /// Epley formula: w * (1 + reps/30)
    var personalRecord1RM: Double? {
        weightHistory.compactMap { entry -> Double? in
            guard entry.reps > 0 else { return nil }
            return entry.weightKg * (1 + Double(entry.reps) / 30.0)
        }.max()
    }

    init(
        slug: String,
        name: String,
        nameEN: String,
        category: ExerciseCategory,
        movementPattern: MovementPattern,
        equipment: [Equipment] = [],
        musclesTarget: [MuscleGroup] = [],
        musclesSecondary: [MuscleGroup] = [],
        isUnilateral: Bool = false,
        instructions: String = ""
    ) {
        self.id = UUID()
        self.slug = slug
        self.name = name
        self.nameEN = nameEN
        self.category = category
        self.movementPattern = movementPattern
        self.equipment = equipment
        self.musclesTarget = musclesTarget
        self.musclesSecondary = musclesSecondary
        self.isUnilateral = isUnilateral
        self.instructions = instructions
        self.weightHistory = []
    }
}

enum Equipment: String, Codable, CaseIterable {
    case barbell        = "barbell"
    case dumbbell       = "dumbbell"
    case cable          = "cable"
    case machine        = "machine"
    case bodyweight     = "bodyweight"
    case resistanceBand = "resistanceBand"
    case kettlebell     = "kettlebell"
    case pullupBar      = "pullupBar"
    case band           = "band"
    case trx            = "trx"
}

enum ExerciseCategory: String, Codable, CaseIterable {
    case chest      = "chest"
    case back       = "back"
    case legs       = "legs"
    case shoulders  = "shoulders"
    case arms       = "arms"
    case core       = "core"
    case cardio     = "cardio"
    case olympic    = "olympic"
}

enum MovementPattern: String, Codable, CaseIterable {
    case push       = "push"
    case pull       = "pull"
    case hinge      = "hinge"
    case squat      = "squat"
    case carry      = "carry"
    case rotation   = "rotation"
    case isolation  = "isolation"
}

enum MuscleGroup: String, Codable, CaseIterable {
    case pecs           = "pecs"
    case lats           = "lats"
    case traps          = "traps"
    case delts          = "delts"
    case biceps         = "biceps"
    case triceps        = "triceps"
    case quads          = "quads"
    case hamstrings     = "hamstrings"
    case glutes         = "glutes"
    case calves         = "calves"
    case abs            = "abs"
    case obliques       = "obliques"
    case spinalErectors = "spinalErectors"
    case forearms       = "forearms"
}
