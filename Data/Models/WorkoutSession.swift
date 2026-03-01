// WorkoutSession.swift

import SwiftData
import Foundation

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var finishedAt: Date?
    var durationMinutes: Int
    var status: SessionStatus

    var readinessScore: Double?
    var aiAdaptationNote: String?

    var userFeedbackEnergy: Int?
    var userFeedbackDifficulty: Int?
    var userNotes: String?

    var plan: WorkoutPlan?

    var plannedDay: PlannedWorkoutDay?

    var isSynced: Bool = false

    var plannedDayName: String {
        plannedDay?.label ?? "Trénink"
    }

    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
    var exercises: [SessionExercise]

    @Relationship(deleteRule: .nullify)
    var healthSnapshot: HealthMetricsSnapshot?

    init(plan: WorkoutPlan?, plannedDay: PlannedWorkoutDay?) {
        self.id = UUID()
        self.startedAt = .now
        self.durationMinutes = 0
        self.status = .inProgress
        self.plan = plan
        self.plannedDay = plannedDay
        self.exercises = []
    }
}

@Model
final class SessionExercise {
    var order: Int
    var wasSubstituted: Bool
    var substitutionReason: String?

    var exercise: Exercise?
    var fallbackSlug: String?
    var fallbackName: String?

    var session: WorkoutSession?

    @Relationship(deleteRule: .cascade, inverse: \CompletedSet.sessionExercise)
    var completedSets: [CompletedSet]

    var exerciseName: String {
        if let ex = exercise { return ex.name }
        if let fn = fallbackName { return fn }
        if let fs = fallbackSlug { return "🔍 Načítám... (\(fs))" }
        return "Neznámý cvik"
    }

    init(order: Int, exercise: Exercise?, fallbackSlug: String? = nil, fallbackName: String? = nil, session: WorkoutSession?) {
        self.order = order
        self.wasSubstituted = false
        self.exercise = exercise
        self.fallbackSlug = fallbackSlug
        self.fallbackName = fallbackName
        self.session = session
        self.completedSets = []
    }
}

@Model
final class CompletedSet {
    var setNumber: Int
    var weightKg: Double
    var reps: Int
    var rpe: Double?
    var durationSeconds: Int?
    var isWarmupSet: Bool // Lze smazat výhledově
    var setTypeStr: String
    
    var setType: SetType {
        get { SetType(rawValue: setTypeStr) ?? (isWarmupSet ? .warmup : .normal) }
        set { setTypeStr = newValue.rawValue }
    }

    var sessionExercise: SessionExercise?

    var isWarmup: Bool { setType == .warmup || isWarmupSet }

    init(
        setNumber: Int,
        weightKg: Double,
        reps: Int,
        rpe: Double? = nil,
        durationSeconds: Int? = nil,
        isWarmupSet: Bool = false,
        type: SetType = .normal
    ) {
        self.setNumber = setNumber
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
        self.durationSeconds = durationSeconds
        self.isWarmupSet = isWarmupSet
        self.setTypeStr = type.rawValue
    }
}

enum SessionStatus: String, Codable {
    case inProgress = "inProgress"
    case completed  = "completed"
    case skipped    = "skipped"
}
