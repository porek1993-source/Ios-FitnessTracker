// WorkoutPlan.swift

import SwiftData
import Foundation

@Model
final class WorkoutPlan {
    @Attribute(.unique) var id: UUID
    var title: String
    var splitType: SplitType
    var durationWeeks: Int
    var isActive: Bool

    var geminiSessionContext: String?
    var generatedAt: Date
    var lastAdaptedAt: Date?

    @Relationship(inverse: \UserProfile.workoutPlans)
    var owner: UserProfile?

    @Relationship(deleteRule: .cascade, inverse: \PlannedWorkoutDay.plan)
    var scheduledDays: [PlannedWorkoutDay]

    @Relationship(deleteRule: .cascade)
    var sessions: [WorkoutSession]

    init(title: String, splitType: SplitType, durationWeeks: Int = 4) {
        self.id = UUID()
        self.title = title
        self.splitType = splitType
        self.durationWeeks = durationWeeks
        self.isActive = true
        self.generatedAt = .now
        self.scheduledDays = []
        self.sessions = []
    }
}

@Model
final class PlannedWorkoutDay {
    var dayOfWeek: Int   // 1 = Po … 7 = Ne
    var label: String
    var isRestDay: Bool

    var plan: WorkoutPlan?

    @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.plannedDay)
    var plannedExercises: [PlannedExercise]

    var sessions: [WorkoutSession]

    init(dayOfWeek: Int, label: String, isRestDay: Bool = false) {
        self.dayOfWeek = dayOfWeek
        self.label = label
        self.isRestDay = isRestDay
        self.plannedExercises = []
        self.sessions = []
    }
}

@Model
final class PlannedExercise {
    var order: Int
    var targetSets: Int
    var targetRepsMin: Int
    var targetRepsMax: Int
    var targetRIR: Int
    var restSeconds: Int

    var exercise: Exercise?
    var fallbackSlug: String?
    var fallbackName: String?

    var plannedDay: PlannedWorkoutDay?

    init(
        order: Int,
        exercise: Exercise?,
        fallbackSlug: String? = nil,
        fallbackName: String? = nil,
        targetSets: Int = 3,
        targetRepsMin: Int = 8,
        targetRepsMax: Int = 12,
        targetRIR: Int = 2,
        restSeconds: Int = 120
    ) {
        self.order = order
        self.exercise = exercise
        self.fallbackSlug = fallbackSlug
        self.fallbackName = fallbackName
        self.targetSets = targetSets
        self.targetRepsMin = targetRepsMin
        self.targetRepsMax = targetRepsMax
        self.targetRIR = targetRIR
        self.restSeconds = restSeconds
    }
}
