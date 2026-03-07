// RestTimerAttributes.swift
// Sdílený soubor — přidat do OBOU targetů: hlavní app i Widget Extension

import ActivityKit
import Foundation

struct RestTimerAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        var restEndsAt: Date
        var totalRestSeconds: Int
        var currentExerciseName: String
        var nextSetInfo: String
        var suggestedWeightKg: Double?
        var sessionProgress: SessionProgress
    }

    let workoutSessionId: UUID
    let exerciseSlug: String
    let planLabel: String
    let totalExercises: Int
    let currentExerciseIndex: Int
}

struct SessionProgress: Codable, Hashable {
    var completedSets: Int
    var totalSets: Int
    var completedExercises: Int
}

struct SessionExerciseState: Identifiable {
    let id: UUID
    var name: String
    var nameEN: String
    var slug: String
    var coachTip: String?
    var tempo: String?
    var restSeconds: Int
    var sets: [SetState]
    var isWarmupOnly: Bool
    var exercise: Exercise?
    var videoUrl: String?
    var supersetId: String? // Pro vizuální spojení supersérií

    init(id: UUID = UUID(), name: String, nameEN: String = "", slug: String, coachTip: String? = nil, tempo: String? = nil, restSeconds: Int = 60, sets: [SetState] = [], isWarmupOnly: Bool = false, exercise: Exercise? = nil, videoUrl: String? = nil, supersetId: String? = nil) {
        self.id = id
        self.name = name
        self.nameEN = nameEN.isEmpty ? (exercise?.nameEN ?? name) : nameEN
        self.slug = slug
        self.coachTip = coachTip
        self.tempo = tempo
        self.restSeconds = restSeconds
        self.sets = sets
        self.isWarmupOnly = isWarmupOnly
        self.exercise = exercise
        self.videoUrl = videoUrl ?? exercise?.videoURL
        self.supersetId = supersetId
    }

    var nextIncompleteSetIndex: Int? {
        sets.indices.first { !sets[$0].isCompleted }
    }
}

struct SetState: Identifiable {
    let id: UUID
    var type: SetType
    var targetRepsMin: Int
    var targetRepsMax: Int
    var weightKg: Double
    var reps: Int?
    var rpe: Int?
    var isCompleted: Bool
    var previousWeightKg: Double?
    var historicalWeightKg: Double?
    var historicalReps: Int?
    var rpeSuggestionApplied: Bool = false
    
    // Pro zpětnou kompatibilitu
    var targetReps: Int { targetRepsMin }
    var isWarmup: Bool { type == .warmup }
    
    init(id: UUID = UUID(), type: SetType = .normal, targetRepsMin: Int, targetRepsMax: Int? = nil, weightKg: Double, reps: Int? = nil, rpe: Int? = nil, previousWeightKg: Double? = nil, historicalWeightKg: Double? = nil, historicalReps: Int? = nil, isCompleted: Bool = false) {
        self.id = id
        self.type = type
        self.targetRepsMin = targetRepsMin
        self.targetRepsMax = targetRepsMax ?? targetRepsMin
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
        self.previousWeightKg = previousWeightKg
        self.historicalWeightKg = historicalWeightKg
        self.historicalReps = historicalReps
        self.isCompleted = isCompleted
    }
    
    // Legacy init
    init(type: SetType, targetReps: Int, weightKg: Double) {
        self.init(type: type, targetRepsMin: targetReps, targetRepsMax: targetReps, weightKg: weightKg)
    }
}
