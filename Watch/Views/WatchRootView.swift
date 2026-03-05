// WatchRootView.swift
// Kořenová obrazovka — přepíná mezi fázemi tréninku

import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject var session: WatchSessionCoordinator

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch session.phase {
            case .idle:
                WatchIdleView()
                    .transition(.opacity)

            case .active:
                WatchActiveSetView()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.92).combined(with: .opacity),
                        removal:   .opacity
                    ))

            case .confirming:
                WatchConfirmView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal:   .opacity
                    ))

            case .resting:
                WatchRestView()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85).combined(with: .opacity),
                        removal:   .opacity
                    ))

            case .done:
                WatchDoneView()
                    .transition(.scale(scale: 1.05).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: session.phase)
    }
}

// MARK: - Idle: Čeká na spuštění tréninku z iPhone

struct WatchIdleView: View {
    @EnvironmentObject var session: WatchSessionCoordinator

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sportscourt.fill")
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .symbolEffect(.pulse)

            Text("Agile Trainer")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

            Text("Spusť trénink\nna iPhonu")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            // Tepová frekvence i v idle režimu
            if session.health.heartRate > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill").foregroundStyle(.red)
                    Text("\(session.health.heartRate) bpm")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding()
    }
}

// MARK: - Done: Trénink dokončen

struct WatchDoneView: View {
    @EnvironmentObject var session: WatchSessionCoordinator

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
                )

            Text("Hotovo! 💪")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            VStack(spacing: 4) {
                Label(session.elapsedFormatted, systemImage: "clock")
                Label("\(Int(session.health.activeCalories)) kcal", systemImage: "flame.fill")
            }
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.6))
        }
        .padding()
    }
}
