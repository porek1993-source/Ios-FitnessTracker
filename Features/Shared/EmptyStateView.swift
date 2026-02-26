// EmptyStateView.swift
// Agilní Fitness Trenér — Univerzální prémiový prázdný stav
//
// ✅ Plně znovupoužitelná komponenta EmptyStateView(icon:title:message:)
// ✅ Volitelná akční tlačítka a animovaný ikonový glow
// ✅ Ukázky použití pro: Spánek, HRV, Grafy, Progress
// ✅ Plně česky

import SwiftUI

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: EmptyStateView  — HLAVNÍ KOMPONENTA
// MARK: ═══════════════════════════════════════════════════════════════════════

struct EmptyStateView: View {

    // MARK: - Required
    let icon:    String   // SF Symbol name
    let title:   String
    let message: String

    // MARK: - Optional customization
    var iconColor: Color        = .blue
    var actionLabel: String?    = nil
    var action: (() -> Void)?   = nil

    // MARK: - Internal state
    @State private var appeared  = false
    @State private var glowPulse = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            // ── Animated icon ─────────────────────────────────────────────────
            ZStack {
                // Outer glow halo
                Circle()
                    .fill(iconColor.opacity(0.08))
                    .frame(width: 88, height: 88)
                    .blur(radius: glowPulse ? 14 : 8)
                    .scaleEffect(glowPulse ? 1.18 : 0.88)
                    .animation(
                        .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                        value: glowPulse
                    )

                // Icon background
                Circle()
                    .fill(iconColor.opacity(0.10))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .stroke(iconColor.opacity(0.18), lineWidth: 1)
                    )

                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(iconColor.opacity(0.75))
            }
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)

            Spacer(minLength: 20)

            // ── Text content ──────────────────────────────────────────────────
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.42))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
            }
            .offset(y: appeared ? 0 : 8)
            .opacity(appeared ? 1 : 0)

            Spacer(minLength: 20)

            // ── Optional CTA button ───────────────────────────────────────────
            if let label = actionLabel, let handler = action {
                Button(action: handler) {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(iconColor.opacity(0.12))
                                .overlay(Capsule().stroke(iconColor.opacity(0.25), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
                .offset(y: appeared ? 0 : 6)
                .opacity(appeared ? 1 : 0)
            }

            Spacer(minLength: 24)
        }
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72).delay(0.05)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                glowPulse = true
            }
        }
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Předdefinované prázdné stavy (tovární metody)
// MARK: ═══════════════════════════════════════════════════════════════════════

extension EmptyStateView {

    // ── SPÁNEK ────────────────────────────────────────────────────────────────
    /// Použij v RecoveryInsightsView / SleepChartView, pokud chybí data ze Apple Watch.
    static func sleep(onEnable: (() -> Void)? = nil) -> EmptyStateView {
        EmptyStateView(
            icon:        "moon.stars.fill",
            title:       "Spánková data nejsou k dispozici",
            message:     "Zatím nemáme dost dat. Spi s Apple Watch, aby ti Jakub mohl přesněji dávkovat zátěž.",
            iconColor:   Color(red: 0.40, green: 0.30, blue: 0.90),
            actionLabel: onEnable != nil ? "Propojit Apple Health" : nil,
            action:      onEnable
        )
    }

    // ── HRV ───────────────────────────────────────────────────────────────────
    static func hrv() -> EmptyStateView {
        EmptyStateView(
            icon:      "waveform.path.ecg",
            title:     "HRV data chybí",
            message:   "Variabilita srdečního tepu se načítá z Apple Watch. Nos je přes noc a data se začnou zobrazovat.",
            iconColor: Color(red: 0.20, green: 0.75, blue: 0.55)
        )
    }

    // ── OBJEM (volume chart) ───────────────────────────────────────────────────
    static func volumeChart() -> EmptyStateView {
        EmptyStateView(
            icon:      "chart.bar.fill",
            title:     "Zatím žádný tréninkový objem",
            message:   "Dokončit první trénink a Jakub začne sledovat tvůj týdenní objem a progres.",
            iconColor: Color(red: 0.25, green: 0.55, blue: 1.0)
        )
    }

    // ── 1RM ODHAD ────────────────────────────────────────────────────────────
    static func oneRepMax() -> EmptyStateView {
        EmptyStateView(
            icon:      "trophy.fill",
            title:     "Osobní rekordy se teprve plní",
            message:   "Po prvním tréninku s danými cviky Jakub automaticky odhadne tvoje 1RM a nastaví optimální váhy.",
            iconColor: Color(red: 1.0, green: 0.75, blue: 0.20)
        )
    }

    // ── KONZISTENCE ───────────────────────────────────────────────────────────
    static func consistency() -> EmptyStateView {
        EmptyStateView(
            icon:      "flame.fill",
            title:     "Série teprve začíná",
            message:   "Dokončit alespoň jeden trénink a Jakub začne sledovat tvoji týdenní konzistenci.",
            iconColor: Color(red: 1.0, green: 0.45, blue: 0.20)
        )
    }

    // ── HISTORIE TRÉNINKŮ ─────────────────────────────────────────────────────
    static func workoutHistory() -> EmptyStateView {
        EmptyStateView(
            icon:      "clock.arrow.circlepath",
            title:     "Žádná tréninková historie",
            message:   "Tvoje hotové tréninky se zobrazí tady. Zahaj první session a začni psát svůj příběh.",
            iconColor: Color.white.opacity(0.5)
        )
    }
}

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Ukázky zapojení do existujících views
// MARK: ═══════════════════════════════════════════════════════════════════════

// ─── PŘÍKLAD 1: RecoveryInsightsView — spánek ────────────────────────────────
//
// // Původní kód:
// if sleepHours == nil {
//     Text("Žádná data")
//         .foregroundStyle(.gray)
// }
//
// // ✅ Nový kód:
// if sleepHours == nil {
//     EmptyStateView.sleep(onEnable: {
//         Task { try? await healthKitService.requestAuthorization() }
//     })
// }

// ─── PŘÍKLAD 2: VolumeChartView ──────────────────────────────────────────────
//
// // Původní kód:
// if volumeData.isEmpty {
//     Text("Žádná data")
// }
//
// // ✅ Nový kód:
// if volumeData.isEmpty {
//     EmptyStateView.volumeChart()
//         .frame(height: 180)
// }

// ─── PŘÍKLAD 3: OneRepMaxChartView ───────────────────────────────────────────
//
// // Původní kód:
// if records.isEmpty {
//     Text("Žádné záznamy")
// }
//
// // ✅ Nový kód:
// if records.isEmpty {
//     EmptyStateView.oneRepMax()
//         .frame(height: 200)
// }

// MARK: ═══════════════════════════════════════════════════════════════════════
// MARK: Preview
// MARK: ═══════════════════════════════════════════════════════════════════════

#Preview("Prázdné stavy — galerie") {
    ZStack {
        Color.black.ignoresSafeArea()
        ScrollView {
            VStack(spacing: 0) {
                previewCard(EmptyStateView.sleep())
                previewCard(EmptyStateView.hrv())
                previewCard(EmptyStateView.volumeChart())
                previewCard(EmptyStateView.oneRepMax())
                previewCard(EmptyStateView.workoutHistory())

                // Vlastní prázdný stav
                previewCard(
                    EmptyStateView(
                        icon:    "figure.run",
                        title:   "Žádné kardio záznamy",
                        message: "Přidej první kardio session a Jakub ti ukáže, jak ovlivňuje tvou regeneraci.",
                        iconColor: .green
                    )
                )
            }
            .padding(.vertical, 20)
        }
    }
    .preferredColorScheme(.dark)
}

private func previewCard<V: View>(_ view: V) -> some View {
    view
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.04))
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
}
