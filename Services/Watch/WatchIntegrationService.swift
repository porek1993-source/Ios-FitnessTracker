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

    // MARK: - Přijímání zpráv z hodinek

    /// Registruj Observer pro příkazy z hodinek (séria potvrzena, pauza přeskočena)
    func registerMessageHandler(
        onSetCompleted: @escaping (Int, Double) -> Void,
        onRestSkipped: @escaping () -> Void
    ) {
        NotificationCenter.default.addObserver(
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
            default:
                break
            }
        }
    }
}
