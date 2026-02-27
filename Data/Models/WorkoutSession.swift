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

    var session: WorkoutSession?

    @Relationship(deleteRule: .cascade, inverse: \CompletedSet.sessionExercise)
    var completedSets: [CompletedSet]

    var exerciseName: String {
        exercise?.name ?? "Neznámý cvik"
    }

    init(order: Int, exercise: Exercise?, session: WorkoutSession?) {
        self.order = order
        self.wasSubstituted = false
        self.exercise = exercise
        self.session = session
        self.completedSets = []
}

@Model
final class CompletedSet {
    var setNumber: Int
    var weightKg: Double
    var reps: Int
    var rpe: Double?
    var durationSeconds: Int?
    var isWarmupSet: Bool

    var sessionExercise: SessionExercise?

    var isWarmup: Bool { isWarmupSet }

    init(
        setNumber: Int,
        weightKg: Double,
        reps: Int,
        rpe: Double? = nil,
        durationSeconds: Int? = nil,
        isWarmupSet: Bool = false
    ) {
        self.setNumber = setNumber
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
        self.durationSeconds = durationSeconds
        self.isWarmupSet = isWarmupSet
    }
}

enum SessionStatus: String, Codable {
    case inProgress = "inProgress"
    case completed  = "completed"
    case skipped    = "skipped"
}
