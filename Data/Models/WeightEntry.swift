// WeightEntry.swift
// Každý dokončený set → 1 WeightEntry.
// Patří k Exercise (ne k Session) → lookup vah je O(log n).

import SwiftData
import Foundation

@Model
final class WeightEntry: Identifiable {
    @Attribute(.unique) var id: UUID
    var weightKg: Double
    var reps: Int
    var rpe: Double?
    var rir: Int?
    var wasSuccessful: Bool
    var loggedAt: Date
    var sessionId: UUID
    var setNumber: Int
    
    // Nový atribut pro uložení typu série (zpětně kompatibilní)
    var setTypeStr: String

    var setType: SetType {
        get { SetType(rawValue: setTypeStr) ?? .normal }
        set { setTypeStr = newValue.rawValue }
    }

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
        exercise: Exercise?,
        type: SetType = .normal
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
        self.setTypeStr = type.rawValue
    }
}

// MARK: - Factory method for WorkoutViewModel
// Poznámka: @Model třídy nepodporují convenience init (SwiftData generuje vlastní inits).
// Místo toho použijeme static factory metodu.

extension WeightEntry {
    static func create(
        exercise: Exercise?,
        sessionId: UUID,
        weightKg: Double,
        reps: Int,
        rpe: Int?,
        wasSuccessful: Bool,
        setNumber: Int = 0,
        type: SetType = .normal
    ) -> WeightEntry {
        WeightEntry(
            weightKg: weightKg,
            reps: reps,
            rpe: rpe.map { Double($0) },
            rir: nil,
            wasSuccessful: wasSuccessful,
            sessionId: sessionId,
            setNumber: setNumber,
            exercise: exercise,
            type: type
        )
    }
}
