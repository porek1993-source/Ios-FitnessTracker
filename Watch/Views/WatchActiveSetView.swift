// WatchActiveSetView.swift
// Obrazovka při aktivní sérii — živý rep-counter + váha + tepovka

import SwiftUI
import WatchKit

struct WatchActiveSetView: View {
    @EnvironmentObject var session: WatchSessionCoordinator

    var body: some View {
        VStack(spacing: 0) {

            // ✅ Phase 4: VBT Zóna — horní nabínzka zvonu rychlosti
            HStack(spacing: 6) {
                Text(session.motion.vbtZone.icon)
                    .font(.system(size: 12))
                Text(session.motion.vbtZone.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(vbtColor)
                Spacer()
                // Vrcholová rychlost za sérii
                if session.motion.peakVelocity > 0.002 {
                    Text(String(format: "%.3f m/s ▲", session.motion.peakVelocity))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 2)

            // ── Hlavička: Cvik + série ─────────────────────────────────────
            VStack(spacing: 2) {
                Text(session.currentSet?.exerciseName ?? "—")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                if let set = session.currentSet {
                    HStack(spacing: 6) {
                        // Typ série (W/N/D/F) s barvou
                        Text(set.setType)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(setTypeColor(set.setType))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(setTypeColor(set.setType).opacity(0.2)))

                        Text("Série \(set.setNumber)/\(set.totalSets)")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .padding(.top, 4)
            .padding(.horizontal, 8)

            Spacer()

            // ── Hlavní sekce: Detekovaná opakování ───────────────────────
            ZStack {
                // Vizuální puls podle intenzity pohybu
                Circle()
                    .fill(Color.green.opacity(session.motion.currentIntensity * 0.3))
                    .scaleEffect(0.7 + session.motion.currentIntensity * 0.5)
                    .animation(.easeInOut(duration: 0.15), value: session.motion.currentIntensity)

                VStack(spacing: 2) {
                    // Velký počítadlo opakování
                    Text("\(session.motion.detectedReps)")
                        .font(.system(size: 48, weight: .black, design: .monospaced))
                        .foregroundStyle(
                            session.motion.isTracking
                                ? Color.white
                                : Color.white.opacity(0.5)
                        )
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.2), value: session.motion.detectedReps)

                    // Cíl
                    if let set = session.currentSet {
                        Text("cíl: \(set.targetRepsMin)–\(set.targetRepsMax)")
                            .font(.system(size: 11))
                            .foregroundStyle(
                                repsColor(
                                    detected: session.motion.detectedReps,
                                    min: set.targetRepsMin,
                                    max: set.targetRepsMax
                                )
                            )
                    }
                }
            }
            .frame(height: 80)

            Spacer()

            // ── Spodní řada: váha + tep ───────────────────────────────────
            HStack {
                // Váha
                if let kg = session.currentSet?.weightKg, kg > 0 {
                    VStack(spacing: 1) {
                        Text(String(format: "%.1f", kg))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        Text("kg")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                } else {
                    Text("BW")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                // Tepová frekvence
                VStack(spacing: 1) {
                    HStack(spacing: 3) {
                        Image(systemName: session.health.heartRateZone.icon)
                            .font(.system(size: 11))
                        Text("\(session.health.heartRate)")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(heartRateColor)
                    Text("bpm")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 14)

            // ── Tlačítko: Ukončit sérii ────────────────────────────────────
            Button {
                session.endSet()
            } label: {
                HStack {
                    Image(systemName: "stop.circle.fill")
                    Text("Hotovo")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Capsule().fill(Color.green))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Helpers

    private func repsColor(detected: Int, min: Int, max: Int) -> Color {
        if detected < min { return .white.opacity(0.45) }
        if detected <= max { return .green }
        return .orange  // Překročil cíl
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

    // ✅ Phase 4: VBT zóna barva
    private var vbtColor: Color {
        switch session.motion.vbtZone {
        case .explosive: return .green
        case .strength:  return .yellow
        case .fatigue:   return .orange
        case .failure:   return .red
        case .idle:      return .white.opacity(0.3)
        }
    }

    private func setTypeColor(_ type: String) -> Color {
        switch type {
        case "W": return .cyan
        case "D": return .orange
        case "F": return .red
        default:  return .white
        }
    }
}
