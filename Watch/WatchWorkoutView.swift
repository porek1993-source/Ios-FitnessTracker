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

// MARK: - Active Set

struct WatchActiveSetView: View {
    @ObservedObject var vm: WatchWorkoutViewModel

    var body: some View {
        VStack(spacing: 10) {
            Text(vm.currentExerciseName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(vm.nextSetInfo)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))

            if let kg = vm.suggestedWeightKg {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", kg))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("kg")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Button {
                vm.completeSet()
                WKInterfaceDevice.current().play(.success)
            } label: {
                Label("Série hotova", systemImage: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Capsule().fill(Color.green))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Rest Timer

struct WatchRestView: View {
    @ObservedObject var vm: WatchWorkoutViewModel

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.12), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: vm.restProgress)
                    .stroke(
                        LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: vm.restProgress)
                VStack(spacing: 2) {
                    Text(vm.restTimeFormatted)
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                    Text("pauza").font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                }
            }
            .frame(width: 120, height: 120)

            Button {
                vm.skipRest()
                WKInterfaceDevice.current().play(.directionDown)
            } label: {
                Text("Přeskočit")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(Capsule().fill(Color.white.opacity(0.15)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .onAppear { WKInterfaceDevice.current().play(.notification) }
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
