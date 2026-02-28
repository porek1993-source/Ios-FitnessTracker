// WatchConnectivityManager.swift
// Přidat do obou targetů: iOS i watchOS

import WatchConnectivity
import Foundation

// ✅ FIX #12: @MainActor zajišťuje, že všechny @Published aktualizace a NotificationCenter.post
// probíhají na hlavním vlákně. WCSessionDelegate metody jsou volány z libovolného vlákna —
// bez @MainActor by aktualizace ObservableObject state způsobovaly runtime warningy / data race.
@MainActor
final class WatchConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {

    static let shared = WatchConnectivityManager()

    // ✅ @MainActor init: WCSession.default.delegate přiřazení je thread-safe
    // nonisolated(unsafe) umožňuje přístup k singletonu bez await z nonisolated kontextu.
    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // iOS → Watch: stav cvičení
    func sendWorkoutState(
        exerciseName: String,
        nextSetInfo: String,
        suggestedWeightKg: Double?,
        restSeconds: Int
    ) {
        guard WCSession.default.isReachable else { return }
        var msg: [String: Any] = [
            "type":         "workoutState",
            "exerciseName": exerciseName,
            "nextSetInfo":  nextSetInfo,
            "restSeconds":  restSeconds
        ]
        if let kg = suggestedWeightKg { msg["suggestedWeightKg"] = kg }
        WCSession.default.sendMessage(msg, replyHandler: nil)
    }

    // Watch → iOS
    func sendSetCompletion() {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["type": "setCompleted"], replyHandler: nil)
    }

    func sendRestSkipped() {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["type": "restSkipped"], replyHandler: nil)
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {}

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // ✅ FIX #12: Třída je @MainActor-isolated — delegátní metody jsou hopnuty
        // na main actor automaticky. Vnořený Task { @MainActor } je zbytečný.
        NotificationCenter.default.post(
            name: .watchMessageReceived,
            object: nil,
            userInfo: message
        )
    }
}

extension Notification.Name {
    static let watchMessageReceived = Notification.Name("watchMessageReceived")
}
