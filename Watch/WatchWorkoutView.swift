// WatchWorkoutView.swift
// watchOS target

import SwiftUI
import WatchKit

struct WatchWorkoutView: View {
    @StateObject private var vm = WatchWorkoutViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if vm.isResting {
                WatchRestView(vm: vm)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85).combined(with: .opacity),
                        removal:   .opacity
                    ))
            } else {
                WatchActiveSetView(vm: vm)
            }
        }
        .animation(.spring(response: 0.35), value: vm.isResting)
        .onReceive(vm.$isResting) { isResting in
            if isResting { WKInterfaceDevice.current().play(.notification) }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .watchMessageReceived)
        ) { note in
            if let dict = note.userInfo as? [String: Any] {
                vm.handleMessage(dict)
            }
        }
    }
}


// MARK: - Watch ViewModel

@MainActor
final class WatchWorkoutViewModel: ObservableObject {
    @Published var currentExerciseName = "Načítám..."
    @Published var nextSetInfo = ""
    @Published var suggestedWeightKg: Double? = nil
    @Published var isResting = false
    @Published var restSecondsRemaining = 0
    @Published var totalRestSeconds = 90

    private var restTimer: Timer?

    var restProgress: Double {
        guard totalRestSeconds > 0 else { return 0 }
        return Double(restSecondsRemaining) / Double(totalRestSeconds)
    }

    var restTimeFormatted: String {
        let s = restSecondsRemaining
        return s >= 60 ? "\(s / 60):\(String(format: "%02d", s % 60))" : "\(s)s"
    }

    func handleMessage(_ message: [String: Any]) {
        if let name = message["exerciseName"] as? String {
            currentExerciseName = name
        }
        if let info = message["nextSetInfo"] as? String {
            nextSetInfo = info
        }
        if let kg = message["suggestedWeightKg"] as? Double {
            suggestedWeightKg = kg
        }
        if let rest = message["restSeconds"] as? Int {
            totalRestSeconds = rest
        }
    }

    func completeSet() {
        WatchConnectivityManager.shared.sendSetCompletion()
        startRest(seconds: totalRestSeconds)
    }

    private func startRest(seconds: Int) {
        restTimer?.invalidate()
        totalRestSeconds     = seconds
        restSecondsRemaining = seconds
        withAnimation { isResting = true }

        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.restSecondsRemaining > 1 {
                    self.restSecondsRemaining -= 1
                } else {
                    self.skipRest()
                    WKInterfaceDevice.current().play(.stop)
                }
            }
        }
    }

    func skipRest() {
        restTimer?.invalidate()
        withAnimation { isResting = false }
        WatchConnectivityManager.shared.sendRestSkipped()
    }
}
