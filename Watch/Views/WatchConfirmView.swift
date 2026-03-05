// WatchConfirmView.swift
// Potvrzení opakování — Digital Crown pro úpravu + zelená fajfka

import SwiftUI
import WatchKit

struct WatchConfirmView: View {
    @EnvironmentObject var session: WatchSessionCoordinator

    // Fokus pro Digital Crown (upravuje reps vs. váhu)
    @State private var focusedField: ConfirmField = .reps
    @FocusState private var isFocused: Bool

    enum ConfirmField { case reps, weight }

    var body: some View {
        VStack(spacing: 8) {

            // ── Hlavička ──────────────────────────────────────────────────
            Text("Potvrdit sérii")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 4)

            // ── Auto-confirm odpočet ───────────────────────────────────────
            if let countdown = session.autoConfirmCountdown {
                Text("Auto ✓ za \(countdown)s")
                    .font(.system(size: 10))
                    .foregroundStyle(.green.opacity(0.8))
            }

            // ── Upravitelná pole ──────────────────────────────────────────
            HStack(spacing: 12) {
                // Opakování
                ConfirmFieldView(
                    label: "REPS",
                    value: "\(session.confirmedReps)",
                    isActive: focusedField == .reps,
                    color: .green
                )
                .onTapGesture {
                    session.cancelAutoConfirm()
                    focusedField = .reps
                }
                .digitalCrownRotation(
                    $session.confirmedReps,
                    from: 1, through: 30, by: 1,
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )

                // Váha
                ConfirmFieldView(
                    label: "KG",
                    value: weightDisplay,
                    isActive: focusedField == .weight,
                    color: .cyan
                )
                .onTapGesture {
                    session.cancelAutoConfirm()
                    focusedField = .weight
                }
                .digitalCrownRotation(
                    $session.confirmedWeight,
                    from: 0, through: 250, by: 0.5,
                    sensitivity: .low,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
            }
            .padding(.horizontal, 6)

            Spacer()

            // ── Tlačítka ──────────────────────────────────────────────────
            HStack(spacing: 8) {
                // Zrušit / upravit znovu
                Button {
                    session.cancelAutoConfirm()
                    session.phase = .active
                    session.motion.reset()
                    session.motion.startTracking()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 40)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)

                // Potvrdit ✓
                Button {
                    session.confirmSet()
                    WKInterfaceDevice.current().play(.success)
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Capsule().fill(Color.green))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
    }

    private var weightDisplay: String {
        let kg = session.confirmedWeight
        if kg == 0 { return "BW" }
        return kg.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(kg))"
            : String(format: "%.1f", kg)
    }
}

// MARK: - Podpůrná komponenta

struct ConfirmFieldView: View {
    let label: String
    let value: String
    let isActive: Bool
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isActive ? color : .white.opacity(0.35))
                .kerning(1.2)

            Text(value)
                .font(.system(size: 26, weight: .black, design: .monospaced))
                .foregroundStyle(isActive ? color : .white.opacity(0.7))
                .contentTransition(.numericText())
                .animation(.spring(response: 0.2), value: value)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive ? color.opacity(0.12) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? color.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
        )
    }
}
