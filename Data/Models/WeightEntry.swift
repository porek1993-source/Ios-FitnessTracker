// WeightEntry.swift
// Každý dokončený set → 1 WeightEntry.
// Patří k Exercise (ne k Session) → lookup vah je O(log n).

import SwiftData
import Foundation

@Model
final class WeightEntry {
    @Attribute(.unique) var id: UUID
    var weightKg: Double
    var reps: Int
    var rpe: Double?
    var rir: Int?
    var wasSuccessful: Bool
    var loggedAt: Date
    var sessionId: UUID
    var setNumber: Int

    @Relationship(inverse: \Exercise.weightHistory)
    var exercise: Exercise?

    init(
        weightKg: Double,
        reps: Int,
        rpe: Double? = nil,
        rir: Int? = nil,
        wasSuccessful: Bool,
        sessionId: UUID,
        setNumber: Int,
        exercise: Exercise?
    ) {
        self.id = UUID()
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
        self.rir = rir
        self.wasSuccessful = wasSuccessful
        self.loggedAt = .now
        self.sessionId = sessionId
        self.setNumber = setNumber
        self.exercise = exercise
    }
}

// MARK: - Convenience init for WorkoutViewModel

extension WeightEntry {
    convenience init(
        exercise: Exercise?,
        sessionId: UUID,
        weightKg: Double,
        reps: Int,
        rpe: Int?,
        wasSuccessful: Bool,
        setNumber: Int = 0
    ) {
        self.init(
            weightKg: weightKg,
            reps: reps,
            rpe: rpe.map { Double($0) },
            rir: nil,
            wasSuccessful: wasSuccessful,
            sessionId: sessionId,
            setNumber: setNumber,
            exercise: exercise
        )
    }
}
