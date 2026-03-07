// WatchConnectivityManager.swift
// Sdílená logika pro komunikaci iOS ↔ watchOS přes WatchConnectivity
// Přidat do obou targetů: iOS i watchOS

import WatchConnectivity
import Foundation

@MainActor
final class WatchConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {

    static let shared = WatchConnectivityManager()

    /// Hodinky jsou v dosahu a připojené
    @Published var isReachable: Bool = false
    @Published var isPaired: Bool    = false

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - iOS → Watch

    /// Pošle aktuální stav série na hodinky
    func sendWorkoutState(
        exerciseName: String,
        setNumber: Int,
        totalSets: Int,
        repsMin: Int,
        repsMax: Int,
        weightKg: Double?,
        restSeconds: Int,
        setType: String = "N"
    ) {
        var msg: [String: Any] = [
            "type":         "workoutState",
            "exerciseName": exerciseName,
            "setNumber":    setNumber,
            "totalSets":    totalSets,
            "repsMin":      repsMin,
            "repsMax":      repsMax,
            "restSeconds":  restSeconds,
            "setType":      setType
        ]
        if let kg = weightKg { msg["weightKg"] = kg }
        send(msg)
    }

    /// Upozorní hodinky, že trénink začal
    func sendWorkoutStarted(title: String) {
        send(["type": "workoutStarted", "title": title])
    }

    /// Upozorní hodinky, že trénink skončil
    func sendWorkoutEnded() {
        send(["type": "workoutEnded"])
    }

    // MARK: - Watch → iOS

    /// Hodinky potvrdily sérii s počtem opakování a váhou
    func sendSetCompletion(reps: Int, weightKg: Double) {
        send(["type": "setCompleted", "reps": reps, "weightKg": weightKg])
    }

    /// Hodinky přeskočily pauzu
    func sendRestSkipped() {
        send(["type": "restSkipped"])
    }

    /// ✅ Phase 4: Generický send pro libovolnou typed zprávu (HR RPE, VBT data…)
    func sendMessage(_ message: [String: Any]) {
        send(message)
    }

    // MARK: - Interní odesílání

    private func send(_ message: [String: Any]) {
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("[WatchConnectivity] Chyba odesílání (přechod do fronty): \(error.localizedDescription)")
                // Fallback na frontu (transferUserInfo) při selhání
                WCSession.default.transferUserInfo(message)
            }
        } else {
            // Hodinky/iOS nejsou v dosahu — spolehlivě zařadíme do fronty
            WCSession.default.transferUserInfo(message)
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
#if os(iOS)
            self.isPaired    = WCSession.default.isPaired
            self.isReachable = WCSession.default.isReachable
#else
            self.isReachable = WCSession.default.isReachable
#endif
        }
    }

#if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.isReachable = WCSession.default.isReachable
        }
    }
#endif

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let msg = message
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .watchMessageReceived,
                object: nil,
                userInfo: msg
            )
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        // Fallback při offline doručení (pokud je ještě někde použit)
        let context = applicationContext
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .watchMessageReceived,
                object: nil,
                userInfo: context
            )
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        // Garantované doručení z fronty (transferUserInfo)
        let info = userInfo
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .watchMessageReceived,
                object: nil,
                userInfo: info
            )
        }
    }
}

extension Notification.Name {
    static let watchMessageReceived = Notification.Name("watchMessageReceived")
}
