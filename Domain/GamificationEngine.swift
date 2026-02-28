// GamificationEngine.swift
// Agilní Fitness Trenér — XP systém a levelování svalových partií
//
// Přidej do SwiftData schema v AgileFitnessTrainerApp.swift:
//   MuscleXPRecord.self

import SwiftData
import Foundation

// MARK: - Gamification Logic


// MARK: - Muscle Level

// MuscleLevel move to MuscleXPRecord.swift


// MARK: - Session Result (input pro engine)

struct SessionGamificationInput {
    struct ExerciseResult {
        let exerciseName: String
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
        case .chest:                          return .chest
        case .lats, .traps, .trapsMiddle,
             .rearShoulders, .lowerback:      return .back
        case .quads, .hamstrings,
             .glutes, .calves:               return .legs
        case .frontShoulders:                 return .shoulders
        case .biceps, .triceps,
             .forearms:                       return .arms
        case .abdominals, .obliques:          return .core
        }
    }
}
