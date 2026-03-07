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

    // ✅ Sprint Tracking (deepanal.pdf bod 8-9)
    var sprintNumber: Int
    var sprintStartDate: Date

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
        self.sprintNumber = 1
        self.sprintStartDate = .now
    }
}

@Model
final class PlannedWorkoutDay: Identifiable {
    @Attribute(.unique) var id: UUID
    var dayOfWeek: Int   // 1 = Po … 7 = Ne
    var label: String
    var isRestDay: Bool

    var plan: WorkoutPlan?

    @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.plannedDay)
    var plannedExercises: [PlannedExercise]

    var sessions: [WorkoutSession]

    init(dayOfWeek: Int, label: String, isRestDay: Bool = false) {
        self.id = UUID()
        self.dayOfWeek = dayOfWeek
        self.label = label
        self.isRestDay = isRestDay
        self.plannedExercises = []
        self.sessions = []
    }
}

@Model
final class PlannedExercise: Identifiable {
    @Attribute(.unique) var id: UUID
    var order: Int
    var targetSets: Int
    var targetRepsMin: Int
    var targetRepsMax: Int
    var targetRIR: Int
    var restSeconds: Int

    var exercise: Exercise?
    var fallbackSlug: String?
    var fallbackName: String?
    var supersetId: String?

    var plannedDay: PlannedWorkoutDay?

    init(
        order: Int,
        exercise: Exercise?,
        fallbackSlug: String? = nil,
        fallbackName: String? = nil,
        targetSets: Int = 4,
        targetRepsMin: Int = 8,
        targetRepsMax: Int = 12,
        targetRIR: Int = 2,
        restSeconds: Int = 120,
        supersetId: String? = nil
    ) {
        self.id = UUID()
        self.order = order
        self.exercise = exercise
        self.fallbackSlug = fallbackSlug
        self.fallbackName = fallbackName
        self.targetSets = targetSets
        self.targetRepsMin = targetRepsMin
        self.targetRepsMax = targetRepsMax
        self.targetRIR = targetRIR
        self.restSeconds = restSeconds
        self.supersetId = supersetId
    }
}

// MARK: - PlannedWorkoutDay Extension

extension PlannedWorkoutDay {
    /// Cviky seřazené podle `order` — sdílená utility, eliminuje opakující se `.sorted { $0.order < $1.order }` na 5+ místech.
    var sortedExercises: [PlannedExercise] {
        plannedExercises.sorted { $0.order < $1.order }
    }
}
