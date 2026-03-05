// WatchSessionCoordinator.swift
// Hlavní koordinátor stavu Watch aplikace
// Propojuje MotionManager, HealthKitWatchService a WatchConnectivity

import SwiftUI
import WatchKit
import Combine

// MARK: - Datové typy

struct WatchSetData {
    var exerciseName: String
    var setNumber: Int
    var totalSets: Int
    var targetRepsMin: Int
    var targetRepsMax: Int
    var weightKg: Double?
    var restSeconds: Int
    var setType: String // "W" | "N" | "D" | "F"
}

enum WatchPhase: Equatable {
    case idle           // Čeká na start
    case active         // Probíhá série
    case confirming     // Potvrzení opakování
    case resting        // Pauza
    case done           // Trénink dokončen
}

// MARK: - Coordinator

@MainActor
final class WatchSessionCoordinator: ObservableObject {

    static let shared = WatchSessionCoordinator()

    // MARK: - Published state
    @Published var phase: WatchPhase       = .idle
    @Published var currentSet: WatchSetData?
    @Published var confirmedReps: Int      = 0
    @Published var confirmedWeight: Double = 0.0
    @Published var restSecondsRemaining: Int = 0
    @Published var totalRestSeconds: Int   = 90
    @Published var autoConfirmCountdown: Int? = nil // nil = vypnuto
    @Published var workoutTitle: String    = "Trénink"
    @Published var elapsedWorkoutSeconds: Int = 0

    // MARK: - Sub-services
    let motion  = MotionManager()
    let health  = HealthKitWatchService()

    // MARK: - Private
    private var restTimer: AnyCancellable?
    private var elapsedTimer: AnyCancellable?
    private var autoConfirmTimer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    /// Pauza na základě tepu (nil = fixní čas)
    var heartRateTargetForResume: Int? = nil

    // MARK: - init

    private init() {
        setupNotifications()
        setupHeartRateAutoResume()
        startElapsedTimer()
    }

    // MARK: - Nastavení

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .watchMessageReceived)
            .compactMap { $0.userInfo as? [String: Any] }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in self?.handleMessage(msg) }
            .store(in: &cancellables)
    }

    private func setupHeartRateAutoResume() {
        // Pokud sledujeme cílový tep pro konec pauzy
        health.$heartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bpm in
                guard let self,
                      self.phase == .resting,
                      let target = self.heartRateTargetForResume,
                      bpm > 0 && bpm <= target else { return }
                self.finishRest()
            }
            .store(in: &cancellables)
    }

    private func startElapsedTimer() {
        elapsedTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                guard let self, self.phase != .idle && self.phase != .done else { return }
                self.elapsedWorkoutSeconds += 1
            }
    }

    // MARK: - Zpracování iOS zpráv

    func handleMessage(_ msg: [String: Any]) {
        guard let type = msg["type"] as? String else { return }
        switch type {
        case "workoutState":
            applyWorkoutState(msg)
        case "startSet":
            startActivePhase()
        case "workoutStarted":
            workoutTitle = msg["title"] as? String ?? "Trénink"
            phase = .active
            Task { await health.startWorkoutSession() }
        case "workoutEnded":
            finishWorkout()
        default:
            break
        }
    }

    private func applyWorkoutState(_ msg: [String: Any]) {
        let setData = WatchSetData(
            exerciseName: msg["exerciseName"] as? String ?? "—",
            setNumber:    msg["setNumber"]    as? Int    ?? 1,
            totalSets:    msg["totalSets"]    as? Int    ?? 4,
            targetRepsMin: msg["repsMin"]     as? Int    ?? 8,
            targetRepsMax: msg["repsMax"]     as? Int    ?? 12,
            weightKg:     msg["weightKg"]     as? Double,
            restSeconds:  msg["restSeconds"]  as? Int    ?? 90,
            setType:      msg["setType"]      as? String ?? "N"
        )
        currentSet        = setData
        confirmedWeight   = setData.weightKg ?? confirmedWeight
        confirmedReps     = (setData.targetRepsMin + setData.targetRepsMax) / 2
        totalRestSeconds  = setData.restSeconds

        withAnimation(.spring(response: 0.3)) { phase = .active }
        startMotionTracking()
        WKInterfaceDevice.current().play(.click)
    }

    // MARK: - Série

    func startActivePhase() {
        withAnimation { phase = .active }
        startMotionTracking()
    }

    private func startMotionTracking() {
        motion.reset()
        motion.startTracking()
        // Každou sekundu synchronizujeme detected reps pro UI
        // (motion publikuje přes @Published automaticky)
    }

    /// Uživatel (nebo automatika) skončil sérii — přejít na potvrzení
    func endSet() {
        motion.stopTracking()
        confirmedReps = max(motion.detectedReps, 1)
        withAnimation(.spring(response: 0.3)) { phase = .confirming }
        WKInterfaceDevice.current().play(.notification)
        startAutoConfirm()
    }

    // MARK: - Potvrzení série

    private func startAutoConfirm(delay: Int = 5) {
        autoConfirmCountdown = delay
        autoConfirmTimer?.cancel()
        autoConfirmTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if let c = self.autoConfirmCountdown, c > 0 {
                    self.autoConfirmCountdown = c - 1
                } else {
                    self.confirmSet()
                }
            }
    }

    func cancelAutoConfirm() {
        autoConfirmTimer?.cancel()
        autoConfirmCountdown = nil
    }

    func confirmSet() {
        autoConfirmTimer?.cancel()
        autoConfirmCountdown = nil
        // Pošleme potvrzení na iPhone
        WatchConnectivityManager.shared.sendSetCompletion(
            reps: confirmedReps,
            weightKg: confirmedWeight
        )
        startRest(seconds: totalRestSeconds)
        WKInterfaceDevice.current().play(.success)
    }

    // MARK: - Pauza

    private func startRest(seconds: Int) {
        totalRestSeconds     = seconds
        restSecondsRemaining = seconds
        withAnimation { phase = .resting }

        restTimer?.cancel()
        restTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.restSecondsRemaining > 1 {
                    self.restSecondsRemaining -= 1
                    // Vibrace 10s před koncem
                    if self.restSecondsRemaining == 10 {
                        WKInterfaceDevice.current().play(.directionUp)
                    }
                } else {
                    self.finishRest()
                }
            }
    }

    func skipRest() {
        restTimer?.cancel()
        finishRest()
        WKInterfaceDevice.current().play(.directionDown)
    }

    private func finishRest() {
        restTimer?.cancel()
        WatchConnectivityManager.shared.sendRestSkipped()
        withAnimation(.spring(response: 0.35)) { phase = .active }
        WKInterfaceDevice.current().play(.stop)
    }

    // MARK: - Konec tréninku

    func finishWorkout() {
        restTimer?.cancel()
        motion.stopTracking()
        phase = .done
        Task { await health.endWorkoutSession() }
        WKInterfaceDevice.current().play(.success)
    }

    // MARK: - Pomocné výpočty

    var restProgress: Double {
        guard totalRestSeconds > 0 else { return 0 }
        return Double(restSecondsRemaining) / Double(totalRestSeconds)
    }

    var restTimeFormatted: String {
        let s = restSecondsRemaining
        return s >= 60 ? "\(s / 60):\(String(format: "%02d", s % 60))" : "\(s)s"
    }

    var elapsedFormatted: String {
        let m = elapsedWorkoutSeconds / 60
        let s = elapsedWorkoutSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
