// WatchIntegrationService.swift
// iOS strana — posílá stav tréninku na Apple Watch
// Voláno z WorkoutViewModel / ActiveSessionViewModel při každé změně série.

import Foundation
import WatchConnectivity

/// Fasáda nad WatchConnectivityManager pro tréninkový kontext — iOS only
@MainActor
final class WatchIntegrationService {

    static let shared = WatchIntegrationService()
    private let wc = WatchConnectivityManager.shared

    private init() {}

    // MARK: - Veřejné API

    /// Voláno při startu tréninku
    func notifyWorkoutStarted(title: String) {
        wc.sendWorkoutStarted(title: title)
    }

    /// Voláno při přechodu na novou sérii
    func notifySetStarted(
        exerciseName: String,
        setNumber: Int,
        totalSets: Int,
        repsMin: Int,
        repsMax: Int,
        weightKg: Double?,
        restSeconds: Int,
        setType: String
    ) {
        wc.sendWorkoutState(
            exerciseName: exerciseName,
            setNumber:    setNumber,
            totalSets:    totalSets,
            repsMin:      repsMin,
            repsMax:      repsMax,
            weightKg:     weightKg,
            restSeconds:  restSeconds,
            setType:      setType
        )
    }

    /// Voláno při ukončení tréninku
    func notifyWorkoutEnded() {
        wc.sendWorkoutEnded()
    }

    private var observerToken: NSObjectProtocol?

    /// Registruj Observer pro příkazy z hodinek. 
    /// ✅ FIX: Ukládá token pro zamezení memory leaks a duplicitních observerů.
    func registerMessageHandler(
        onSetCompleted: @escaping @Sendable (Int, Double) -> Void,
        onRestSkipped: @escaping @Sendable () -> Void,
        onHRRecoveryRPE: @escaping @Sendable (Int, Double) -> Void
    ) {
        if let old = observerToken {
            NotificationCenter.default.removeObserver(old)
        }

        observerToken = NotificationCenter.default.addObserver(
            forName: .watchMessageReceived,
            object: nil,
            queue: .main
        ) { note in
            guard let msg = note.userInfo as? [String: Any],
                  let type = msg["type"] as? String else { return }
            switch type {
            case "setCompleted":
                let reps   = msg["reps"]     as? Int    ?? 0
                let weight = msg["weightKg"] as? Double ?? 0.0
                onSetCompleted(reps, weight)
            case "restSkipped":
                onRestSkipped()
            case "hrRecoveryRPE":
                let setNum = msg["setNumber"] as? Int ?? 0
                let rpe = msg["estimatedRPE"] as? Double ?? 0.0
                onHRRecoveryRPE(setNum, rpe)
            default:
                break
            }
        }
    }
}
