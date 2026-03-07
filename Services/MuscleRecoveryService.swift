// MuscleRecoveryService.swift
// Vypočítá "heat" skóre (0–100) pro každou svalovou skupinu
// dle doby od posledního tréninku a intenzity (volume × RPE).

import Foundation
import SwiftData

struct MuscleRecoveryState {
    let group: MuscleGroup
    /// 0 = plně zotaveno (zelená), 100 = právě po tréninku (červená)
    let heatScore: Double
    /// Kolik hodin zbývá do plné regenerace (0 = kompletně zotaveno)
    let hoursUntilRecovered: Double
    /// Čas posledního tréninku dané skupiny
    let lastTrainedAt: Date?
}

extension MuscleRecoveryState {
    private static let palette: [(r: Double, g: Double, b: Double, a: Double)] = [
        (0.20, 0.84, 0.50, 1.0),  // 0–20 % — Sytá zelená (plně fit)
        (0.55, 0.90, 0.25, 1.0),  // 20–40 % — Žlutozelená
        (1.00, 0.85, 0.15, 1.0),  // 40–60 % — Oranžovožlutá
        (1.00, 0.50, 0.10, 1.0),  // 60–80 % — Oranžová
        (0.93, 0.18, 0.18, 1.0),  // 80–100 % — Červená (max únava)
    ]

    var color: (r: Double, g: Double, b: Double, a: Double) {
        let idx = min(Int(heatScore / 20.0), 4)
        return Self.palette[idx]
    }

    var statusLabel: String {
        switch heatScore {
        case 0..<25:  return "Fit"
        case 25..<50: return "Mírně unaveno"
        case 50..<75: return "Unaveno"
        case 75..<90: return "Přetíženo"
        default:      return "Čerstvě natrénováno"
        }
    }
}

// MARK: - Service

enum MuscleRecoveryService {

    /// Průměrná doba regenerace (hodiny) pro každou skupinu.
    private static let baseRecoveryHours: [MuscleGroup: Double] = [
        .chest:          60,
        .frontShoulders: 48,
        .rearShoulders:  48,
        .traps:          48,
        .trapsMiddle:    60,
        .lats:           72,
        .lowerback:      72,
        .biceps:         48,
        .triceps:        48,
        .forearms:       36,
        .obliques:       36,
        .abdominals:     36,
        .quads:          72,
        .hamstrings:     72,
        .glutes:         72,
        .calves:         36,
    ]

    /// Výpočet stavu všech svalových skupin dle dokončených session.
    static func compute(from sessions: [WorkoutSession]) -> [MuscleRecoveryState] {
        // Najdeme poslední trénink + max volume pro každou skupinu
        var lastTrained:    [MuscleGroup: Date]   = [:]
        var maxVolumeKg:    [MuscleGroup: Double]  = [:]

        for session in sessions {
            guard let finished = session.finishedAt else { continue }
            for ex in session.exercises {
                let groups = (ex.exercise?.musclesTarget ?? []) + (ex.exercise?.musclesSecondary ?? [])
                let volume = ex.completedSets.filter { !$0.isWarmup }
                    .reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }

                for group in groups {
                    // Zachováme pouze nejnovější datum
                    if let prev = lastTrained[group] {
                        if finished > prev { lastTrained[group] = finished }
                    } else {
                        lastTrained[group] = finished
                    }
                    maxVolumeKg[group] = (maxVolumeKg[group] ?? 0) + volume
                }
            }
        }

        return MuscleGroup.allCases.map { group in
            guard let last = lastTrained[group] else {
                return MuscleRecoveryState(group: group, heatScore: 0, hoursUntilRecovered: 0, lastTrainedAt: nil)
            }
            let hoursSince = Date().timeIntervalSince(last) / 3600
            let totalRecovery = baseRecoveryHours[group] ?? 60.0

            // Lineární útlum: plná únava = 100 hned po tréninku, klesá k 0 po totalRecovery h
            let rawHeat = max(0, 1.0 - hoursSince / totalRecovery) * 100.0

            // Bonus fatigue za vysoký objem (max +15 %)
            let volumeBonus = min(15.0, (maxVolumeKg[group] ?? 0) / 5000.0 * 15.0)
            let heatScore   = min(100, rawHeat + (rawHeat > 0 ? volumeBonus : 0))

            let hoursLeft = max(0, totalRecovery - hoursSince)

            return MuscleRecoveryState(group: group, heatScore: heatScore, hoursUntilRecovered: hoursLeft, lastTrainedAt: last)
        }
    }
}
