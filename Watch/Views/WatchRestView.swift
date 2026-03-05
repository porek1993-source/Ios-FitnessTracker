// WatchRestView.swift
// Obrazovka pauzy — kruhový odpočet + tepovka + info o další sérii

import SwiftUI
import WatchKit

struct WatchRestView: View {
    @EnvironmentObject var session: WatchSessionCoordinator

    var body: some View {
        VStack(spacing: 6) {

            // ── Kruhový odpočet ───────────────────────────────────────────
            ZStack {
                // Šedý podkladový kruh
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 7)

                // Barevný progress kruh
                Circle()
                    .trim(from: 0, to: session.restProgress)
                    .stroke(
                        AngularGradient(
                            colors: progressColors,
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: session.restProgress)

                // Obsah středu kruhu
                VStack(spacing: 2) {
                    Text(session.restTimeFormatted)
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))

                    Text("pauza")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .frame(width: 110, height: 110)
            .padding(.top, 2)

            // ── Tepovka a stav zotavení ────────────────────────────────────
            if session.health.heartRate > 0 {
                HStack(spacing: 5) {
                    Image(systemName: session.health.heartRateZone.icon)
                        .font(.system(size: 11))

                    Text("\(session.health.heartRate) bpm")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))

                    // Stav zotavení
                    Text("·")
                        .foregroundStyle(.white.opacity(0.3))

                    Text(session.health.heartRateZone.rawValue)
                        .font(.system(size: 11))
                }
                .foregroundStyle(heartRateColor)
            }

            // ── Přeskočit pauzu ────────────────────────────────────────────
            Button {
                session.skipRest()
            } label: {
                Text("Přeskočit")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
        .onAppear {
            WKInterfaceDevice.current().play(.notification)
        }
    }

    // MARK: - Pomocné barvy

    private var progressColors: [Color] {
        // Gradient od zelené (klid) k červené (přetížení) dle tepu
        switch session.health.heartRateZone {
        case .rest, .warmup: return [.mint, .green]
        case .fatBurn:       return [.green, .cyan]
        case .cardio:        return [.cyan, .yellow]
        case .peak:          return [.yellow, .orange]
        case .red:           return [.orange, .red]
        }
    }

    private var heartRateColor: Color {
        switch session.health.heartRateZone {
        case .rest, .warmup: return .green
        case .fatBurn:       return .mint
        case .cardio:        return .yellow
        case .peak:          return .orange
        case .red:           return .red
        }
    }
}
