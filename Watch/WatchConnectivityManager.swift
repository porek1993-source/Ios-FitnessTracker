// WatchConnectivityManager.swift
// Přidat do obou targetů: iOS i watchOS

import WatchConnectivity
import Foundation

final class WatchConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {

    static let shared = WatchConnectivityManager()

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
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .watchMessageReceived,
                object: nil,
                userInfo: message
            )
        }
    }
}

extension Notification.Name {
    static let watchMessageReceived = Notification.Name("watchMessageReceived")
}
