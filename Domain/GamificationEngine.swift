// GamificationEngine.swift
// Agilní Fitness Trenér — XP systém a levelování svalových partií
//
// Přidej do SwiftData schema v AgileFitnessTrainerApp.swift:
//   MuscleXPRecord.self

import SwiftData
import Foundation

// MARK: - SwiftData Model

/// Perzistentní XP záznam pro jednu svalovou partii.
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

// MARK: - Session Result (input pro engine)

struct SessionGamificationInput {
    struct ExerciseResult {
        let musclesTarget: [MuscleGroup]
        let musclesSecondary: [MuscleGroup]
        let completedSets: [SetResult]
    }
    struct SetResult {
        let weightKg: Double
        let reps: Int
        let isWarmup: Bool
    }
    let exercises: [ExerciseResult]
    let personalRecords: [PREvent]  // zjistí ProgressiveOverloadUseCase
}

struct PREvent: Identifiable {
    let id = UUID()
    let exerciseName: String
    let muscleGroup: MuscleGroup
    let oldValue: Double
    let newValue: Double  // 1RM nebo váha
    let type: PRType

    enum PRType { case weight, oneRM }
}

// MARK: - XP Gain

struct XPGain: Identifiable {
    let id = UUID()
    let muscleGroup: MuscleGroup
    let xpEarned: Double
    let volumeKg: Double
    let previousLevel: MuscleLevel
    let newLevel: MuscleLevel
    var didLevelUp: Bool { newLevel > previousLevel }
}

// MARK: - Engine

@MainActor
final class GamificationEngine: ObservableObject {

    @Published private(set) var xpGains: [XPGain] = []
    @Published private(set) var muscleRecords: [MuscleGroup: MuscleXPRecord] = [:]

    // XP koeficienty
    private enum XPCoeff {
        static let primaryMuscle   = 1.0    // 1 XP per kg volume na primárním svalu
        static let secondaryMuscle = 0.3    // 30 % bonusu pro sekundární
        static let prBonus         = 500.0  // flat XP bonus za PR
        static let warmupFactor    = 0.0    // warmup sety se nezapočítávají
    }

    // MARK: - Load from SwiftData

    func loadRecords(from context: ModelContext) {
        let records = (try? context.fetch(FetchDescriptor<MuscleXPRecord>())) ?? []
        for record in records {
            if let group = MuscleGroup(rawValue: record.muscleGroup) {
                muscleRecords[group] = record
            }
        }
    }

    // MARK: - Process Session

    /// Přepočítá XP po tréninku a vrátí seznam změn.
    @discardableResult
    func process(input: SessionGamificationInput, context: ModelContext) -> [XPGain] {

        // 1. Spočítej volume a XP per sval
        var xpPerMuscle: [MuscleGroup: Double] = [:]
        var volumePerMuscle: [MuscleGroup: Double] = [:]

        for exercise in input.exercises {
            let workingSets = exercise.completedSets.filter { !$0.isWarmup }
            let volume = workingSets.reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }

            // Primární svaly
            for muscle in exercise.musclesTarget {
                xpPerMuscle[muscle, default: 0] += volume * XPCoeff.primaryMuscle
                volumePerMuscle[muscle, default: 0] += volume
            }

            // Sekundární svaly (menší bonus)
            for muscle in exercise.musclesSecondary {
                xpPerMuscle[muscle, default: 0] += volume * XPCoeff.secondaryMuscle
                volumePerMuscle[muscle, default: 0] += volume * XPCoeff.secondaryMuscle
            }
        }

        // 2. PR bonus
        for pr in input.personalRecords {
            xpPerMuscle[pr.muscleGroup, default: 0] += XPCoeff.prBonus
        }

        // 3. Zapiš do SwiftData a vlož do XPGain array
        var gains: [XPGain] = []

        for (muscle, xpEarned) in xpPerMuscle where xpEarned > 0 {
            let record = getOrCreate(muscle: muscle, context: context)
            let prevLevel = record.level

            record.totalXP         += xpEarned
            record.totalVolumeKg   += volumePerMuscle[muscle] ?? 0
            record.lastUpdated      = .now

            muscleRecords[muscle] = record

            gains.append(XPGain(
                muscleGroup:    muscle,
                xpEarned:       xpEarned,
                volumeKg:       volumePerMuscle[muscle] ?? 0,
                previousLevel:  prevLevel,
                newLevel:       record.level
            ))
        }

        // Seřaď podle získaného XP
        gains.sort { $0.xpEarned > $1.xpEarned }
        self.xpGains = gains

        return gains
    }

    // MARK: - Queries

    func record(for muscle: MuscleGroup) -> MuscleXPRecord? {
        muscleRecords[muscle]
    }

    func level(for muscle: MuscleGroup) -> MuscleLevel {
        muscleRecords[muscle]?.level ?? .untrained
    }

    /// Progres v aktuálním levelu (0.0 – 1.0)
    func levelProgress(for muscle: MuscleGroup) -> Double {
        guard let record = muscleRecords[muscle] else { return 0 }
        let level = record.level
        let nextLevel = MuscleLevel(rawValue: level.rawValue + 1) ?? level
        let xpInCurrentLevel = record.totalXP - level.xpThreshold
        let xpNeeded = nextLevel.xpThreshold - level.xpThreshold
        guard xpNeeded > 0 else { return 1.0 }
        return min(xpInCurrentLevel / xpNeeded, 1.0)
    }

    // MARK: - Private

    private func getOrCreate(muscle: MuscleGroup, context: ModelContext) -> MuscleXPRecord {
        if let existing = muscleRecords[muscle] { return existing }

        let new = MuscleXPRecord(muscleGroup: muscle)
        context.insert(new)
        muscleRecords[muscle] = new
        return new
    }
}

// MARK: - MuscleGroup.primaryCategory (helper pro mapování na ExerciseCategory)

extension MuscleGroup {
    var primaryCategory: ExerciseCategory {
        switch self {
        case .pecs:                       return .chest
        case .lats, .traps:               return .back
        case .quads, .hamstrings,
             .glutes, .calves:            return .legs
        case .delts:                      return .shoulders
        case .biceps, .triceps,
             .forearms:                   return .arms
        case .abs, .obliques,
             .spinalErectors:             return .core
        }
    }
}
