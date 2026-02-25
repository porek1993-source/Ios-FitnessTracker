// MuscleXPRecord.swift
// Perzistentní XP záznam pro jednu svalovou partii.

import SwiftData
import Foundation

@Model
final class MuscleXPRecord {
    @Attribute(.unique) var muscleGroup: String   // MuscleGroup.rawValue
    var totalXP: Double
    var totalVolumeKg: Double    // lifetime volume (kg × reps)
    var lastUpdated: Date

    init(muscleGroup: MuscleGroup) {
        self.muscleGroup    = muscleGroup.rawValue
        self.totalXP        = 0
        self.totalVolumeKg  = 0
        self.lastUpdated    = .now
    }

    var level: MuscleLevel { MuscleLevel.from(xp: totalXP) }
}
