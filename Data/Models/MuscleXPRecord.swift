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

// MARK: - Muscle Level

enum MuscleLevel: Int, CaseIterable, Comparable {
    static func < (lhs: MuscleLevel, rhs: MuscleLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    case untrained   = 0   // šedá
    case beginner    = 1   // modrá
    case developing  = 2   // zelená
    case trained     = 3   // zlatá
    case advanced    = 4   // oranžová
    case elite       = 5   // červeno-zlatá gradient

    static func from(xp: Double) -> MuscleLevel {
        switch xp {
        case ..<500:         return .untrained
        case 500..<2_000:    return .beginner
        case 2_000..<6_000:  return .developing
        case 6_000..<15_000: return .trained
        case 15_000..<40_000:return .advanced
        default:             return .elite
        }
    }

    var displayName: String {
        switch self {
        case .untrained:  return "Netrénovaný"
        case .beginner:   return "Začátečník"
        case .developing: return "Rozvíjející se"
        case .trained:    return "Trénovaný"
        case .advanced:   return "Pokročilý"
        case .elite:      return "Elita"
        }
    }

    /// Barva pro vizualizaci panáčka
    var color: (r: Double, g: Double, b: Double) {
        switch self {
        case .untrained:  return (0.25, 0.25, 0.30)
        case .beginner:   return (0.20, 0.50, 0.90)
        case .developing: return (0.15, 0.80, 0.45)
        case .trained:    return (0.95, 0.78, 0.10)
        case .advanced:   return (1.00, 0.50, 0.10)
        case .elite:      return (0.95, 0.20, 0.20)
        }
    }

    /// XP potřebné pro dosažení tohoto levelu
    var xpThreshold: Double {
        switch self {
        case .untrained:  return 0
        case .beginner:   return 500
        case .developing: return 2_000
        case .trained:    return 6_000
        case .advanced:   return 15_000
        case .elite:      return 40_000
        }
    }

    /// XP do dalšího levelu
    var xpToNext: Double {
        let next = MuscleLevel(rawValue: self.rawValue + 1)
        return (next?.xpThreshold ?? xpThreshold) - xpThreshold
    }
}

